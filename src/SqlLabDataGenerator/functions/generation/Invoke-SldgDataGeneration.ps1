function Invoke-SldgDataGeneration {
	<#
	.SYNOPSIS
		Executes data generation according to a generation plan.

	.DESCRIPTION
		Generates synthetic data for all tables in the plan, respecting FK dependencies,
		unique constraints, and custom rules. Data is generated in topological order
		so that parent tables are populated before child tables.

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
	#>
	[CmdletBinding(SupportsShouldProcess)]
	param (
		[Parameter(Mandatory)]
		$Plan,

		$ConnectionInfo,

		[switch]$NoInsert,

		[switch]$PassThru,

		[switch]$UseTransaction
	)

	if (-not $ConnectionInfo) { $ConnectionInfo = $script:SldgState.ActiveConnection }
	if (-not $ConnectionInfo -and -not $NoInsert) {
		Stop-PSFFunction -Message "No active database connection. Use Connect-SldgDatabase first, or use -NoInsert." -EnableException $true
	}

	# Connection staleness check
	if ($ConnectionInfo -and $ConnectionInfo.Connection -and $ConnectionInfo.Connection.State -ne 'Open') {
		Stop-PSFFunction -Message "Database connection is no longer open. Reconnect with Connect-SldgDatabase." -EnableException $true
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
	$executingUser = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name

	Write-PSFMessage -Level Verbose -Message "Generation audit: user=$executingUser, database=$($Plan.Database), tables=$($Plan.TableCount), mode=$($Plan.Mode)"

	# Start a transaction if requested
	if ($UseTransaction -and -not $NoInsert -and $ConnectionInfo) {
		$transaction = $ConnectionInfo.Connection.BeginTransaction()
		Write-PSFMessage -Level Verbose -Message "Transaction started for data generation (provider: $($ConnectionInfo.Provider))"
	}

	# Guard: Scenario mode is not yet implemented
	if ($Plan.Mode -eq 'Scenario') {
		Stop-PSFFunction -Message "Scenario mode is not yet implemented. Use 'Synthetic' or 'Masking'." -EnableException $true
	}

	$generationFailed = $false
	$isMaskingMode = $Plan.Mode -eq 'Masking'

	$tableIndex = 0
	$tableTotal = $Plan.Tables.Count

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

			Write-PSFMessage -Level Host -Message ($script:strings.'Generation.MaskingStarting' -f $tablePlan.RowCount, $tablePlan.SchemaName, $tablePlan.TableName)

			try {
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
					Write-PSFMessage -Level Warning -Message "No rows read from $($tablePlan.FullName) — skipping masking to prevent data loss"
					$tableResults.Add([PSCustomObject]@{
							PSTypeName = 'SqlLabDataGenerator.TableResult'
							TableName  = $tablePlan.FullName
							RowCount   = 0
							Success    = $true
							Error      = 'Skipped — no rows to mask'
					})
					continue
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
						$delCmd = $ConnectionInfo.Connection.CreateCommand()
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

				$tableResult = [PSCustomObject]@{
					PSTypeName = 'SqlLabDataGenerator.TableResult'
					TableName  = $tablePlan.FullName
					RowCount   = $insertedCount
					Success    = $true
					Error      = $null
				}
				if ($PassThru) {
					$tableResult | Add-Member -NotePropertyName DataTable -NotePropertyValue $existingData
				}
				$tableResults.Add($tableResult)
			}
			catch {
				Write-PSFMessage -Level Warning -Message ($script:strings.'Generation.Failed' -f $tablePlan.SchemaName, $tablePlan.TableName, $_)
				$tableResults.Add([PSCustomObject]@{
						PSTypeName = 'SqlLabDataGenerator.TableResult'
						TableName  = $tablePlan.FullName
						RowCount   = 0
						Success    = $false
						Error      = $_.Exception.Message
					})
				if ($transaction) {
					$generationFailed = $true
					Write-PSFMessage -Level Warning -Message "Rolling back transaction due to masking failure in $($tablePlan.FullName)"
					try { $transaction.Rollback() }
					catch {
						Write-PSFMessage -Level Error -Message "CRITICAL: Transaction rollback failed for masking operation — database may be in inconsistent state: $_"
					}
					$transaction = $null
					$totalInserted = 0
					break
				}
			}
			continue
		}

		Write-PSFMessage -Level Host -Message ($script:strings.'Generation.Table' -f $tablePlan.RowCount, $tablePlan.SchemaName, $tablePlan.TableName)

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
				[PSCustomObject]@{
					ColumnName  = $cp.ColumnName
					DataType    = $cp.DataType
					SemanticType = $cp.SemanticType
					IsIdentity  = $cp.Skip -and $cp.DataType -ne 'timestamp'
					IsComputed  = $false
					IsPrimaryKey = [bool]$cp.IsPrimaryKey
					IsUnique    = [bool]$cp.IsUnique
					IsNullable  = if ($null -ne $cp.IsNullable) { [bool]$cp.IsNullable } else { $true }
					MaxLength   = $cp.MaxLength
					ForeignKey  = $cp.ForeignKey
					Classification = [PSCustomObject]@{ SemanticType = $cp.SemanticType; IsPII = $cp.IsPII }
					GenerationRule = $cp.CustomRule
				}
			}
			ForeignKeys = $tablePlan.ForeignKeys
		}

		try {
			$rowSet = New-SldgRowSet -TableInfo $tableInfo -RowCount $tablePlan.RowCount `
				-GeneratorMap $Plan.GeneratorMap -ForeignKeyValues $fkValues -TableRules $tableRules

			# Merge generated FK values for child tables
			foreach ($key in $rowSet.GeneratedValues.Keys) {
				$fkValues[$key] = $rowSet.GeneratedValues[$key]
			}

			$insertedCount = 0
			if (-not $NoInsert -and $ConnectionInfo) {
				# Disable FK constraints for circular dependency tables
				$disabledFK = $false
				if ($tablePlan.HasCircularDependency -and $ConnectionInfo.Connection) {
					try {
						$fkCmd = $ConnectionInfo.Connection.CreateCommand()
						if ($transaction) { $fkCmd.Transaction = $transaction }
						$safeName = Get-SldgSafeSqlName -SchemaName $tablePlan.SchemaName -TableName $tablePlan.TableName -SQLite:($ConnectionInfo.Provider -eq 'SQLite')
						if ($ConnectionInfo.Provider -eq 'SQLite') {
							$fkCmd.CommandText = "PRAGMA foreign_keys = OFF"
						}
						else {
							$fkCmd.CommandText = "ALTER TABLE $safeName NOCHECK CONSTRAINT ALL"
						}
						[void]$fkCmd.ExecuteNonQuery()
						$fkCmd.Dispose()
						$disabledFK = $true
						Write-PSFMessage -Level Verbose -Message "Disabled FK constraints for circular dependency table $($tablePlan.FullName)"
					}
					catch {
						Write-PSFMessage -Level Warning -Message "Could not disable FK constraints for $($tablePlan.FullName): $_"
					}
				}

				$writeParams = @{
					ConnectionInfo = $ConnectionInfo
					SchemaName     = $tablePlan.SchemaName
					TableName      = $tablePlan.TableName
					Data           = $rowSet.DataTable
					BatchSize      = $batchSize
				}
				if ($transaction) { $writeParams['Transaction'] = $transaction }
				$insertedCount = & $provider.FunctionMap.WriteData @writeParams

				# Re-enable FK constraints after inserting circular dependency table
				if ($disabledFK -and $ConnectionInfo.Connection) {
					try {
						$fkCmd = $ConnectionInfo.Connection.CreateCommand()
						if ($transaction) { $fkCmd.Transaction = $transaction }
						$safeName = Get-SldgSafeSqlName -SchemaName $tablePlan.SchemaName -TableName $tablePlan.TableName -SQLite:($ConnectionInfo.Provider -eq 'SQLite')
						if ($ConnectionInfo.Provider -eq 'SQLite') {
							$fkCmd.CommandText = "PRAGMA foreign_keys = ON"
						}
						else {
							$fkCmd.CommandText = "ALTER TABLE $safeName WITH CHECK CHECK CONSTRAINT ALL"
						}
						[void]$fkCmd.ExecuteNonQuery()
						$fkCmd.Dispose()
						Write-PSFMessage -Level Verbose -Message "Re-enabled FK constraints for $($tablePlan.FullName)"
					}
					catch {
						Write-PSFMessage -Level Warning -Message "Could not re-enable FK constraints for $($tablePlan.FullName): $_"
					}
				}
			}
			else {
				$insertedCount = $rowSet.RowCount
			}

			$totalInserted += $insertedCount
			Write-PSFMessage -Level Host -Message ($script:strings.'Generation.TableComplete' -f $tablePlan.FullName, $insertedCount)

			$tableResult = [PSCustomObject]@{
				PSTypeName = 'SqlLabDataGenerator.TableResult'
				TableName  = $tablePlan.FullName
				RowCount   = $insertedCount
				Success    = $true
				Error      = $null
			}
			if ($PassThru) {
				$tableResult | Add-Member -NotePropertyName DataTable -NotePropertyValue $rowSet.DataTable
			}
			$tableResults.Add($tableResult)
		}
		catch {
			Write-PSFMessage -Level Warning -Message ($script:strings.'Generation.Failed' -f $tablePlan.SchemaName, $tablePlan.TableName, $_)
			$tableResults.Add([PSCustomObject]@{
					PSTypeName = 'SqlLabDataGenerator.TableResult'
					TableName  = $tablePlan.FullName
					RowCount   = 0
					Success    = $false
					Error      = $_.Exception.Message
				})

			if ($transaction) {
				$generationFailed = $true
				Write-PSFMessage -Level Warning -Message "Rolling back transaction due to failure in $($tablePlan.FullName)"
				try { $transaction.Rollback() }
				catch {
					Write-PSFMessage -Level Error -Message "CRITICAL: Transaction rollback failed — database may be in inconsistent state: $_"
				}
				$transaction = $null
				# Zero out previously successful counts since they were rolled back
				$totalInserted = 0
				foreach ($tr in $tableResults) {
					if ($tr.Success) {
						$tr | Add-Member -NotePropertyName 'RolledBack' -NotePropertyValue $true -Force
					}
				}
				break
			}
		}
	}

	# Commit transaction if all succeeded
	if ($transaction -and -not $generationFailed) {
		try {
			$transaction.Commit()
			Write-PSFMessage -Level Verbose -Message "Transaction committed successfully"
		}
		catch {
			Write-PSFMessage -Level Warning -Message "Transaction commit failed, rolling back: $_"
			try { $transaction.Rollback() }
			catch {
				Write-PSFMessage -Level Error -Message "CRITICAL: Transaction rollback after commit failure also failed — database may be in inconsistent state: $_"
			}
			$totalInserted = 0
			$generationFailed = $true
		}
	}

	Write-Progress -Activity 'Generating data' -Completed

	$generationDuration = (Get-Date) - $generationStartTime
	Write-PSFMessage -Level Host -Message ($script:strings.'Generation.Complete' -f $Plan.TableCount, $totalInserted)
	Write-PSFMessage -Level Verbose -Message "Generation audit complete: user=$executingUser, rows=$totalInserted, duration=$($generationDuration.TotalSeconds.ToString('F1'))s, failed=$generationFailed"

	# Persistent audit log — append a JSON record for compliance/traceability
	$auditLogPath = Get-PSFConfigValue -FullName 'SqlLabDataGenerator.Audit.LogPath'
	if ($auditLogPath) {
		try {
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
			Write-PSFMessage -Level Verbose -Message "Audit log entry written to: $auditLogPath"
		}
		catch {
			Write-PSFMessage -Level Warning -Message "Failed to write audit log entry: $_"
		}
	}

	# Store generated data reference
	$script:SldgState.GeneratedData[$Plan.Database] = $tableResults

	[PSCustomObject]@{
		PSTypeName    = 'SqlLabDataGenerator.GenerationResult'
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
