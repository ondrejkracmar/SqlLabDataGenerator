function Invoke-SldgDataGeneration {
	<#
	.SYNOPSIS
		Executes data generation according to a generation plan.

	.DESCRIPTION
		Generates synthetic data for all tables in the plan, respecting FK dependencies,
		unique constraints, and custom rules. Data is generated in topological order
		so that parent tables are populated before child tables.

		Within each row, columns with -CrossColumnDependency rules (set via Set-SldgGenerationRule)
		are automatically reordered so that dependency columns are generated first. This enables
		context-dependent AI generation — e.g., a JSON column can vary its structure based on
		the value of a report-type column in the same row.

	.PARAMETER Plan
		The generation plan from New-SldgGenerationPlan.

	.PARAMETER ConnectionInfo
		Target database connection. If not specified, uses the active connection.

	.PARAMETER WhatIf
		Shows what would be generated without actually inserting data.

	.PARAMETER NoInsert
		Generates data in memory but does not write to the database.
		Use this with -PassThru to get the generated DataTables.

	.PARAMETER PassThru
		Returns the generated data as part of the result object.

	.PARAMETER UseTransaction
		Wraps all inserts in a single database transaction. If any table fails,
		all previously inserted data is rolled back.

	.PARAMETER Parallel
		Generates independent tables in parallel (PowerShell 7+ only).

	.PARAMETER ThrottleLimit
		Maximum number of tables to generate in parallel when using -Parallel.

	.PARAMETER Confirm
		Prompts for confirmation before inserting data into each table.

	.EXAMPLE
		PS C:\> $result = Invoke-SldgDataGeneration -Plan $plan

		Generates and inserts data for all tables in the plan.

	.EXAMPLE
		PS C:\> $result = Invoke-SldgDataGeneration -Plan $plan -NoInsert -PassThru

		Generates data in memory without inserting.

	.EXAMPLE
		PS C:\> $result = Invoke-SldgDataGeneration -Plan $plan -UseTransaction

		Generates and inserts data within a single transaction. If any table fails,
		all previously inserted data is rolled back.

	.EXAMPLE
		PS C:\> $result = Invoke-SldgDataGeneration -Plan $plan -Parallel -ThrottleLimit 4

		Independent tables are generated in parallel (PS 7+ only), up to 4 at a time.
	#>
	[OutputType([SqlLabDataGenerator.GenerationResult])]
	[CmdletBinding(SupportsShouldProcess)]
	param (
		[Parameter(Mandatory)]
		$Plan,

		$ConnectionInfo,

		[switch]$NoInsert,

		[switch]$PassThru,

		[switch]$UseTransaction,

		[switch]$Parallel,

		[int]$ThrottleLimit
	)

	if (-not $ConnectionInfo) { $ConnectionInfo = $script:SldgState.ActiveConnection }
	if (-not $ConnectionInfo -and -not $NoInsert) {
		Stop-PSFFunction -String 'Connect.NoActiveConnectionOrNoInsert' -EnableException $true
	}

	# Connection staleness check
	if ($ConnectionInfo -and $ConnectionInfo.DbConnection -and $ConnectionInfo.DbConnection.State -ne 'Open') {
		Stop-PSFFunction -Message ($script:strings.'Connect.HealthCheckFailed' -f $ConnectionInfo.Provider, $ConnectionInfo.ServerInstance, $ConnectionInfo.Database) -EnableException $true
	}

	$provider = if ($ConnectionInfo) { Get-SldgProviderInternal -Name $ConnectionInfo.Provider } else { $null }
	$batchSize = Get-PSFConfigValue -FullName 'SqlLabDataGenerator.Generation.BatchSize'

	Write-PSFMessage -Level Host -Message ($script:strings.'Generation.Starting' -f $Plan.TableCount, $Plan.Mode)

	# Seed for reproducibility
	$seed = Get-PSFConfigValue -FullName 'SqlLabDataGenerator.Generation.Seed'
	if ($seed -gt 0) {
		$null = Get-Random -SetSeed $seed
	}

	$fkValues = @{}
	$tableResults = [System.Collections.Generic.List[object]]::new()
	$totalInserted = 0
	$transaction = $null
	$generationStartTime = Get-Date
	$executingUser = if ($IsLinux -or $IsMacOS) {
		[System.Environment]::UserName
	} else {
		[System.Security.Principal.WindowsIdentity]::GetCurrent().Name
	}

	Write-PSFMessage -Level Verbose -String 'Generation.AuditStart' -StringValues $executingUser, $Plan.Database, $Plan.TableCount, $Plan.Mode

	# Start a transaction if requested
	if ($UseTransaction -and -not $NoInsert -and $ConnectionInfo) {
		$transaction = $ConnectionInfo.DbConnection.BeginTransaction()
		Write-PSFMessage -Level Verbose -String 'Generation.TransactionStarted' -StringValues $ConnectionInfo.Provider
	}

	# Streaming config for large tables
	$streamingThreshold = Get-PSFConfigValue -FullName 'SqlLabDataGenerator.Generation.StreamingThreshold'
	$streamingChunkSize = Get-PSFConfigValue -FullName 'SqlLabDataGenerator.Generation.StreamingChunkSize'

	# Parallel config
	if (-not $ThrottleLimit) { $ThrottleLimit = Get-PSFConfigValue -FullName 'SqlLabDataGenerator.Generation.ThrottleLimit' }
	$useParallel = $Parallel -and -not ($Plan.Mode -eq 'Masking') -and $PSVersionTable.PSVersion.Major -ge 7

	$generationFailed = $false
	$isMaskingMode = $Plan.Mode -eq 'Masking'
	$failedTables = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)

	# S4: Auto-enable transaction for masking mode to prevent data loss from DELETE+INSERT
	if ($isMaskingMode -and -not $NoInsert -and $ConnectionInfo -and -not $transaction) {
		$transaction = $ConnectionInfo.DbConnection.BeginTransaction()
		Write-PSFMessage -Level Verbose -String 'Generation.MaskingTransactionStarted'
	}

	$tableIndex = 0
	$tableTotal = $Plan.Tables.Count

	# A2: Pre-scan and disable FK constraints for ALL circular dependency tables before insertion
	$circularTables = @($Plan.Tables | Where-Object { $_.HasCircularDependency })
	$disabledCircularFKs = [System.Collections.Generic.List[object]]::new()
	if ($circularTables.Count -gt 0 -and -not $NoInsert -and $ConnectionInfo -and $ConnectionInfo.DbConnection) {
		if ($ConnectionInfo.Provider -eq 'SQLite') {
			# SQLite PRAGMA is connection-global — disable once
			try {
				$fkCmd = $ConnectionInfo.DbConnection.CreateCommand()
				if ($transaction) { $fkCmd.Transaction = $transaction }
				$fkCmd.CommandText = "PRAGMA foreign_keys = OFF"
				try { [void]$fkCmd.ExecuteNonQuery() } finally { $fkCmd.Dispose() }
				$disabledCircularFKs.AddRange($circularTables)
				Write-PSFMessage -Level Verbose -String 'Generation.FKDisabledPragma' -StringValues $circularTables.Count
			}
			catch {
				Write-PSFMessage -Level Warning -String 'Generation.FKDisablePragmaFailed' -StringValues $_
			}
		}
		else {
			# SQL Server — disable per-table so entire cycle is unconstrained during insertion
			foreach ($ct in $circularTables) {
				try {
					$fkCmd = $ConnectionInfo.DbConnection.CreateCommand()
					if ($transaction) { $fkCmd.Transaction = $transaction }
					$safeName = Get-SldgSafeSqlName -SchemaName $ct.SchemaName -TableName $ct.TableName
					$fkCmd.CommandText = "ALTER TABLE $safeName NOCHECK CONSTRAINT ALL"
					try { [void]$fkCmd.ExecuteNonQuery() } finally { $fkCmd.Dispose() }
					$disabledCircularFKs.Add($ct)
					Write-PSFMessage -Level Verbose -String 'Generation.FKDisabledTable' -StringValues $ct.FullName
				}
				catch {
					Write-PSFMessage -Level Warning -String 'Generation.FKDisableTableFailed' -StringValues $ct.FullName, $_
				}
			}
		}
	}

	# ── Parallel generation path (PS 7+, Synthetic/Scenario only) ──
	if ($useParallel -and $Plan.Tables.Count -gt 0) {
		$parallelResult = Invoke-SldgParallelTableGeneration -Plan $Plan -FkValues $fkValues `
			-ConnectionInfo $ConnectionInfo -Provider $provider -Transaction $transaction `
			-BatchSize $batchSize -ThrottleLimit $ThrottleLimit `
			-StreamingThreshold $streamingThreshold -StreamingChunkSize $streamingChunkSize `
			-NoInsert:$NoInsert -PassThru:$PassThru

		$tableResults.AddRange($parallelResult.TableResults)
		$totalInserted = $parallelResult.TotalInserted
		$generationFailed = $parallelResult.GenerationFailed
		if ($generationFailed -and $transaction) { $transaction = $null }
	}
	# ── Sequential generation path (original) ──
	else {

	foreach ($tablePlan in $Plan.Tables) {
		$tableIndex++
		$pct = [int](($tableIndex - 1) / [Math]::Max($tableTotal, 1) * 100)
		Write-Progress -Activity 'Generating data' -Status "Table $tableIndex of ${tableTotal}: $($tablePlan.FullName)" -PercentComplete $pct

		if (-not $PSCmdlet.ShouldProcess("$($tablePlan.FullName) ($($tablePlan.RowCount) rows)", "Generate data")) {
			continue
		}

		# Masking mode: read existing data, mask PII columns, write back
		if ($isMaskingMode) {
			if (-not $ConnectionInfo -or -not $provider) {
				Stop-PSFFunction -Message $script:strings.'Generation.MaskingNotSupported' -EnableException $true
			}

			Invoke-PSFProtectedCommand -ActionString 'Generation.MaskingTable' -ActionStringValues $tablePlan.RowCount, $tablePlan.SchemaName, $tablePlan.TableName -Target $tablePlan.FullName -ScriptBlock {
				# Read existing data
				$readParams = @{
					ConnectionInfo = $ConnectionInfo
					SchemaName     = $tablePlan.SchemaName
					TableName      = $tablePlan.TableName
				}
				if ($transaction) { $readParams['Transaction'] = $transaction }
				$existingData = & $provider.FunctionMap.ReadData @readParams

				# Safety guard: skip masking if no rows were read (prevents data loss from DELETE)
				if (-not $existingData -or $existingData.Rows.Count -eq 0) {
					Write-PSFMessage -Level Warning -String 'Generation.MaskingNoRows' -StringValues $tablePlan.FullName
					$tableResults.Add([SqlLabDataGenerator.TableResult]@{
							TableName  = $tablePlan.FullName
							RowCount   = 0
							Success    = $true
							Error      = 'Skipped — no rows to mask'
					})
					return
				}

				# Mask PII columns using the generation plan rules
				$tableRules = if ($Plan.GenerationRules.ContainsKey($tablePlan.FullName)) { $Plan.GenerationRules[$tablePlan.FullName] } else { $null }
				$generatorMap = if ($Plan.GeneratorMap) { $Plan.GeneratorMap } else { Get-SldgGeneratorMap }

				foreach ($row in $existingData.Rows) {
					foreach ($col in $tablePlan.Columns) {
						if (-not $col.IsPII -and -not ($tableRules -and $tableRules.ContainsKey($col.ColumnName))) { continue }
						if ($col.Skip -or $col.IsPrimaryKey) { continue }

						$colObj = [PSCustomObject]@{
							ColumnName   = $col.ColumnName
							DataType     = $col.DataType
							SemanticType = $col.SemanticType
							MaxLength    = $col.MaxLength
							IsNullable   = $col.IsNullable
							ForeignKey   = $null
						}
						$customRule = if ($tableRules -and $tableRules.ContainsKey($col.ColumnName)) { $tableRules[$col.ColumnName] } else { $null }
						$maskedValue = New-SldgGeneratedValue -Column $colObj -GeneratorMap $generatorMap -CustomRule $customRule -NullProbability 0
						if ($null -ne $maskedValue) {
							$row[$col.ColumnName] = $maskedValue
						}
					}
				}

				if (-not $NoInsert) {
					# Masking mode: delete existing rows, then re-insert the masked data
					$deleteParams = @{
						ConnectionInfo = $ConnectionInfo
						SchemaName     = $tablePlan.SchemaName
						TableName      = $tablePlan.TableName
					}
					if ($transaction) { $deleteParams['Transaction'] = $transaction }
					if ($provider.FunctionMap.ContainsKey('DeleteData')) {
						& $provider.FunctionMap.DeleteData @deleteParams
					} else {
						# Fallback: execute DELETE directly
						$delCmd = $ConnectionInfo.DbConnection.CreateCommand()
						if ($transaction) { $delCmd.Transaction = $transaction }
						$safeName = Get-SldgSafeSqlName -SchemaName $tablePlan.SchemaName -TableName $tablePlan.TableName -SQLite:($ConnectionInfo.Provider -eq 'SQLite')
						$delCmd.CommandText = "DELETE FROM $safeName"
						[void]$delCmd.ExecuteNonQuery()
						$delCmd.Dispose()
					}

					$writeParams = @{
						ConnectionInfo = $ConnectionInfo
						SchemaName     = $tablePlan.SchemaName
						TableName      = $tablePlan.TableName
						Data           = $existingData
						BatchSize      = $batchSize
					}
					if ($transaction) { $writeParams['Transaction'] = $transaction }
					$insertedCount = & $provider.FunctionMap.WriteData @writeParams
				}
				else {
					$insertedCount = $existingData.Rows.Count
				}

				$totalInserted += $insertedCount
				Write-PSFMessage -Level Host -Message ($script:strings.'Generation.MaskingComplete' -f $tablePlan.SchemaName, $tablePlan.TableName, $insertedCount)

				$tableResult = [SqlLabDataGenerator.TableResult]@{
					TableName  = $tablePlan.FullName
					RowCount   = $insertedCount
					Success    = $true
					Error      = $null
				}
				if ($PassThru) {
					$tableResult.DataTable = $existingData
				}
				$tableResults.Add($tableResult)
			} -PSCmdlet $PSCmdlet -EnableException $false

			if (Test-PSFFunctionInterrupt) {
				$tableResults.Add([SqlLabDataGenerator.TableResult]@{
						TableName  = $tablePlan.FullName
						RowCount   = 0
						Success    = $false
						Error      = $Error[0].Exception.Message
					})
				if ($transaction) {
					$generationFailed = $true
				Write-PSFMessage -Level Warning -String 'Generation.MaskingRollingBack' -StringValues $tablePlan.FullName
				try { $transaction.Rollback() }
				catch {
					Write-PSFMessage -Level Error -String 'Generation.MaskingRollbackCritical' -StringValues $_
					}
					$transaction = $null
					$totalInserted = 0
				Stop-PSFFunction -String 'Generation.MaskingRolledBack' -StringValues $tablePlan.FullName -EnableException $true
				}
			}
			continue
		}

		Write-PSFMessage -Level Host -Message ($script:strings.'Generation.Table' -f $tablePlan.RowCount, $tablePlan.SchemaName, $tablePlan.TableName)

		# FK DB fallback: for each FK reference, ensure $fkValues has parent values.
		# If a parent table failed or wasn't in the plan, read existing PK values from the database.
		if ($tablePlan.ForeignKeys -and $tablePlan.ForeignKeys.Count -gt 0 -and $ConnectionInfo -and $provider) {
			foreach ($fk in $tablePlan.ForeignKeys) {
				$refKey = "$($fk.ReferencedSchema).$($fk.ReferencedTable).$($fk.ReferencedColumn)"
				if (-not $fkValues.ContainsKey($refKey) -or $fkValues[$refKey].Count -eq 0) {
					try {
						$safeRef = Get-SldgSafeSqlName -SchemaName $fk.ReferencedSchema -TableName $fk.ReferencedTable
						$safeCol = Get-SldgSafeSqlName -ColumnName $fk.ReferencedColumn
						$cmd = $ConnectionInfo.DbConnection.CreateCommand()
						if ($transaction) { $cmd.Transaction = $transaction }
						$cmd.CommandText = "SELECT DISTINCT TOP (1000) $safeCol FROM $safeRef"
						$cmd.CommandTimeout = 30
						$reader = $cmd.ExecuteReader()
						$vals = [System.Collections.Generic.List[object]]::new()
						while ($reader.Read()) {
							$v = $reader.GetValue(0)
							if ($v -isnot [DBNull]) { $vals.Add($v) }
						}
						$reader.Close()
						$reader.Dispose()
						$cmd.Dispose()
						if ($vals.Count -gt 0) {
							$fkValues[$refKey] = $vals.ToArray()
							Write-PSFMessage -Level Verbose -Message ($script:strings.'Generation.FKFallbackLoaded' -f $refKey, $vals.Count)
						}
					}
					catch {
						Write-PSFMessage -Level Warning -Message ($script:strings.'Generation.FKFallbackFailed' -f $refKey, $_)
					}
				}
			}
		}

		# Get table info from schema (need full column info)
		$tableRules = if ($Plan.GenerationRules.ContainsKey($tablePlan.FullName)) {
			$Plan.GenerationRules[$tablePlan.FullName]
		}
		else { $null }

		# Build a table info object with semantic types
		$tableInfo = [PSCustomObject]@{
			SchemaName  = $tablePlan.SchemaName
			TableName   = $tablePlan.TableName
			FullName    = $tablePlan.FullName
			Columns     = foreach ($cp in $tablePlan.Columns) {
				# Cross-reference table-level ForeignKeys to ensure column-level ForeignKey is set
				$colFK = $cp.ForeignKey
				if (-not $colFK -and $tablePlan.ForeignKeys) {
					$matchedFK = $tablePlan.ForeignKeys | Where-Object { $_.ParentColumn -eq $cp.ColumnName } | Select-Object -First 1
					if ($matchedFK) {
						$colFK = [PSCustomObject]@{
							ReferencedSchema = $matchedFK.ReferencedSchema
							ReferencedTable  = $matchedFK.ReferencedTable
							ReferencedColumn = $matchedFK.ReferencedColumn
						}
					}
				}
				[PSCustomObject]@{
					ColumnName  = $cp.ColumnName
					DataType    = $cp.DataType
					SemanticType = $cp.SemanticType
					IsIdentity  = [bool]$cp.IsIdentity
					IsComputed  = [bool]$cp.IsComputed
					IsPrimaryKey = [bool]$cp.IsPrimaryKey
					IsUnique    = [bool]$cp.IsUnique
					IsNullable  = if ($null -ne $cp.IsNullable) { [bool]$cp.IsNullable } else { $true }
					MaxLength   = $cp.MaxLength
					ForeignKey  = $colFK
					SchemaHint  = $cp.SchemaHint
					Classification = [PSCustomObject]@{ SemanticType = $cp.SemanticType; IsPII = $cp.IsPII }
					GenerationRule = $cp.CustomRule
				}
			}
			ForeignKeys = $tablePlan.ForeignKeys
		}

		# For non-identity integer PK columns, query MAX(PK) so we can auto-generate sequential values
		if ($ConnectionInfo) {
			foreach ($col in $tableInfo.Columns) {
				if ($col.IsPrimaryKey -and -not $col.IsIdentity -and -not $col.IsComputed -and -not $col.ForeignKey -and $col.DataType -match '^(int|bigint|smallint|tinyint)$') {
					try {
						$safeTbl = Get-SldgSafeSqlName -SchemaName $tablePlan.SchemaName -TableName $tablePlan.TableName
						$safeCol = Get-SldgSafeSqlName -ColumnName $col.ColumnName
						$cmd = $ConnectionInfo.DbConnection.CreateCommand()
						if ($transaction) { $cmd.Transaction = $transaction }
						$cmd.CommandText = "SELECT ISNULL(MAX($safeCol), 0) FROM $safeTbl"
						$cmd.CommandTimeout = 30
						$maxVal = $cmd.ExecuteScalar()
						$cmd.Dispose()
						$col | Add-Member -NotePropertyName 'PKStartValue' -NotePropertyValue ([long]$maxVal) -Force
					}
					catch {
						Write-PSFMessage -Level Verbose -Message "Could not query MAX PK for $($col.ColumnName): $_"
					}
				}
			}
		}

		Invoke-PSFProtectedCommand -ActionString 'Generation.InsertingTable' -ActionStringValues $tablePlan.RowCount, $tablePlan.SchemaName, $tablePlan.TableName -Target $tablePlan.FullName -ScriptBlock {

			# Streaming mode: large tables generate and write in chunks to keep memory bounded
			if ($streamingThreshold -gt 0 -and $tablePlan.RowCount -gt $streamingThreshold) {
				Write-PSFMessage -Level Host -Message ($script:strings.'Generation.StreamingStarting' -f $tablePlan.FullName, $tablePlan.RowCount, $streamingChunkSize)

				$streamParams = @{
					TableInfo        = $tableInfo
					TotalRowCount    = $tablePlan.RowCount
					ChunkSize        = $streamingChunkSize
					GeneratorMap     = $Plan.GeneratorMap
					ForeignKeyValues = $fkValues
					TableRules       = $tableRules
					BatchSize        = $batchSize
					NoInsert         = $NoInsert
					PassThru         = $PassThru
				}
				if ($ConnectionInfo) { $streamParams['ConnectionInfo'] = $ConnectionInfo }
				if ($transaction) { $streamParams['Transaction'] = $transaction }
				if ($provider) { $streamParams['WriteFunction'] = $provider.FunctionMap.WriteData }

				$streamResult = Invoke-SldgStreamingGeneration @streamParams

				foreach ($key in $streamResult.GeneratedValues.Keys) {
					$fkValues[$key] = $streamResult.GeneratedValues[$key]
				}
				$insertedCount = $streamResult.InsertedCount
			}
			else {
				$rowSet = New-SldgRowSet -TableInfo $tableInfo -RowCount $tablePlan.RowCount `
					-GeneratorMap $Plan.GeneratorMap -ForeignKeyValues $fkValues -TableRules $tableRules

				# Merge generated FK values for child tables
				foreach ($key in $rowSet.GeneratedValues.Keys) {
					$fkValues[$key] = $rowSet.GeneratedValues[$key]
				}

				$insertedCount = 0
				if (-not $NoInsert -and $ConnectionInfo) {
					$writeParams = @{
						ConnectionInfo = $ConnectionInfo
						SchemaName     = $tablePlan.SchemaName
						TableName      = $tablePlan.TableName
						Data           = $rowSet.DataTable
						BatchSize      = $batchSize
					}
					if ($transaction) { $writeParams['Transaction'] = $transaction }
					$insertedCount = & $provider.FunctionMap.WriteData @writeParams
				}
				else {
					$insertedCount = $rowSet.RowCount
				}
			}

			$totalInserted += $insertedCount
			Write-PSFMessage -Level Host -Message ($script:strings.'Generation.TableComplete' -f $tablePlan.FullName, $insertedCount)

			$tableResult = [SqlLabDataGenerator.TableResult]@{
				TableName  = $tablePlan.FullName
				RowCount   = $insertedCount
				Success    = $true
				Error      = $null
			}
			if ($PassThru -and $rowSet) {
				$tableResult.DataTable = $rowSet.DataTable
			}
			elseif ($PassThru -and $streamResult -and $streamResult.DataTables) {
				$tableResult.DataTables = $streamResult.DataTables
			}
			$tableResults.Add($tableResult)
		} -PSCmdlet $PSCmdlet -EnableException $false

		if (Test-PSFFunctionInterrupt) {
			[void]$failedTables.Add($tablePlan.FullName)
			$tableResults.Add([SqlLabDataGenerator.TableResult]@{
					TableName  = $tablePlan.FullName
					RowCount   = 0
					Success    = $false
					Error      = $Error[0].Exception.Message
				})

			if ($transaction) {
				$generationFailed = $true
				Write-PSFMessage -Level Warning -String 'Generation.RollingBack' -StringValues $tablePlan.FullName
				try { $transaction.Rollback() }
				catch {
					Write-PSFMessage -Level Error -String 'Generation.RollbackCritical' -StringValues $_
				}
				$transaction = $null
				$totalInserted = 0
				foreach ($tr in $tableResults) {
					if ($tr.Success) {
						$tr.RolledBack = $true
					}
				}
				Stop-PSFFunction -String 'Generation.DataRolledBack' -StringValues $tablePlan.FullName -EnableException $true
			}
		}
	}

	} # end: sequential/parallel branch

	# Re-enable FK constraints for all circular dependency tables after insertion
	if ($disabledCircularFKs.Count -gt 0 -and $ConnectionInfo -and $ConnectionInfo.DbConnection -and -not $generationFailed) {
		if ($ConnectionInfo.Provider -eq 'SQLite') {
			try {
				$fkCmd = $ConnectionInfo.DbConnection.CreateCommand()
				if ($transaction) { $fkCmd.Transaction = $transaction }
				$fkCmd.CommandText = "PRAGMA foreign_keys = ON"
				try { [void]$fkCmd.ExecuteNonQuery() } finally { $fkCmd.Dispose() }
				Write-PSFMessage -Level Verbose -String 'Generation.FKReenabledPragma'
			}
			catch {
				Write-PSFMessage -Level Warning -String 'Generation.FKReenablePragmaFailed' -StringValues $_
			}
		}
		else {
			foreach ($ct in $disabledCircularFKs) {
				try {
					$fkCmd = $ConnectionInfo.DbConnection.CreateCommand()
					if ($transaction) { $fkCmd.Transaction = $transaction }
					$safeName = Get-SldgSafeSqlName -SchemaName $ct.SchemaName -TableName $ct.TableName
					$fkCmd.CommandText = "ALTER TABLE $safeName WITH CHECK CHECK CONSTRAINT ALL"
					try { [void]$fkCmd.ExecuteNonQuery() } finally { $fkCmd.Dispose() }
					Write-PSFMessage -Level Verbose -String 'Generation.FKReenabledTable' -StringValues $ct.FullName
				}
				catch {
					Write-PSFMessage -Level Warning -String 'Generation.FKReenableTableFailed' -StringValues $ct.FullName, $_
				}
			}
		}
	}

	# Commit transaction if all succeeded
	if ($transaction -and -not $generationFailed) {
		try {
			$transaction.Commit()
			Write-PSFMessage -Level Verbose -String 'Generation.TransactionCommitted'
		}
		catch {
			Write-PSFMessage -Level Warning -String 'Generation.CommitFailed' -StringValues $_
			try { $transaction.Rollback() }
			catch {
				Write-PSFMessage -Level Error -String 'Generation.CommitRollbackCritical' -StringValues $_
			}
			$totalInserted = 0
			$generationFailed = $true
		}
	}

	Write-Progress -Activity 'Generating data' -Completed

	$generationDuration = (Get-Date) - $generationStartTime
	Write-PSFMessage -Level Host -Message ($script:strings.'Generation.Complete' -f $Plan.TableCount, $totalInserted)
	Write-PSFMessage -Level Verbose -String 'Generation.AuditComplete' -StringValues $executingUser, $totalInserted, $generationDuration.TotalSeconds.ToString('F1'), $generationFailed

	# Persistent audit log — append a JSON record for compliance/traceability
	$auditLogPath = Get-PSFConfigValue -FullName 'SqlLabDataGenerator.Audit.LogPath'
	if ($auditLogPath) {
		try {
			# Validate: resolve path and prevent traversal attacks
			$auditLogPath = [System.IO.Path]::GetFullPath($ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($auditLogPath))
			$auditDir = Split-Path $auditLogPath -Parent
			if ($auditDir -and -not (Test-Path $auditDir)) {
				$null = New-Item -Path $auditDir -ItemType Directory -Force
			}
			$auditRecord = [PSCustomObject]@{
				Timestamp  = (Get-Date).ToString('o')
				User       = $executingUser
				Database   = $Plan.Database
				Mode       = $Plan.Mode
				TableCount = $Plan.TableCount
				TotalRows  = $totalInserted
				Duration   = $generationDuration.TotalSeconds
				Success    = -not $generationFailed
				Tables     = @($tableResults | ForEach-Object { @{ TableName = $_.TableName; RowCount = $_.RowCount; Success = $_.Success } })
			}
			$auditJson = $auditRecord | ConvertTo-Json -Depth 4 -Compress
			Add-Content -Path $auditLogPath -Value $auditJson -Encoding UTF8
			Write-PSFMessage -Level Verbose -String 'Generation.AuditWritten' -StringValues $auditLogPath
		}
		catch {
			Write-PSFMessage -Level Warning -String 'Generation.AuditWriteFailed' -StringValues $_
		}
	}

	# Store generated data reference
	$script:SldgState.GeneratedData[$Plan.Database] = $tableResults

	[SqlLabDataGenerator.GenerationResult]@{
		Database      = $Plan.Database
		Mode          = $Plan.Mode
		TableCount    = $Plan.TableCount
		TotalRows     = $totalInserted
		Tables        = $tableResults.ToArray()
		SuccessCount  = ($tableResults | Where-Object Success).Count
		FailureCount  = ($tableResults | Where-Object { -not $_.Success }).Count
		StartedAt     = $generationStartTime
		CompletedAt   = Get-Date
		Duration      = $generationDuration
		User          = $executingUser
	}
}
