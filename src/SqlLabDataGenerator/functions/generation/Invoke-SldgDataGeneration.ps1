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
		[Parameter(Mandatory, ValueFromPipeline)]
		$Plan,

		$ConnectionInfo,

		[switch]$NoInsert,

		[switch]$PassThru,

		[switch]$UseTransaction,

		[switch]$Parallel,

		[int]$ThrottleLimit
	)

	process {
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

	# Query limits and timeouts
	$fkQueryLimit = Get-PSFConfigValue -FullName 'SqlLabDataGenerator.Generation.ForeignKeyQueryLimit'
	$uniqueQueryLimit = Get-PSFConfigValue -FullName 'SqlLabDataGenerator.Generation.UniqueValueQueryLimit'
	$dbCommandTimeout = Get-PSFConfigValue -FullName 'SqlLabDataGenerator.Database.CommandTimeout'

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

	# A2: Pre-scan and disable FK constraints for circular dependency tables before insertion
	$circularTables = @($Plan.Tables | Where-Object { $_.HasCircularDependency })
	$disabledFKInfo = $null
	if ($circularTables.Count -gt 0 -and -not $NoInsert -and $ConnectionInfo -and $ConnectionInfo.DbConnection) {
		$disableParams = @{
			CircularTables = $circularTables
			ConnectionInfo = $ConnectionInfo
		}
		if ($transaction) { $disableParams['Transaction'] = $transaction }
		$disabledFKInfo = Disable-SldgCircularFKConstraints @disableParams
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
		if ($generationFailed -and $transaction) {
			try { $transaction.Rollback() } catch { Write-PSFMessage -Level Warning -String 'Generation.ParallelRollbackFailed' -StringValues $_ }
			$transaction = $null
		}
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
				$maskParams = @{
					TablePlan      = $tablePlan
					ConnectionInfo = $ConnectionInfo
					Provider       = $provider
					Plan           = $Plan
					BatchSize      = $batchSize
					NoInsert       = $NoInsert
					PassThru       = $PassThru
				}
				if ($transaction) { $maskParams['Transaction'] = $transaction }

				$maskResult = Invoke-SldgMaskingTable @maskParams
				$totalInserted += $maskResult.RowCount
				$tableResults.Add($maskResult)
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

		# FK DB fallback: batch-load missing FK parent values grouped by parent table
		if ($tablePlan.ForeignKeys -and $tablePlan.ForeignKeys.Count -gt 0 -and $ConnectionInfo -and $provider) {
			$fkFallbackParams = @{
				TablePlan      = $tablePlan
				FkValues       = $fkValues
				ConnectionInfo = $ConnectionInfo
				FkQueryLimit   = $fkQueryLimit
				CommandTimeout = $dbCommandTimeout
			}
			if ($transaction) { $fkFallbackParams['Transaction'] = $transaction }
			Resolve-SldgForeignKeyFallback @fkFallbackParams
		}

		# Get table info from schema (need full column info)
		$tableRules = if ($Plan.GenerationRules.ContainsKey($tablePlan.FullName)) {
			$Plan.GenerationRules[$tablePlan.FullName]
		}
		else { $null }

		# Build a table info object with semantic types
		$tableInfo = ConvertTo-SldgTableInfo -TablePlan $tablePlan

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
						$cmd.CommandTimeout = $dbCommandTimeout
						$maxVal = $cmd.ExecuteScalar()
						$cmd.Dispose()
						$col | Add-Member -NotePropertyName 'PKStartValue' -NotePropertyValue ([long]$maxVal) -Force
					}
					catch {
						Write-PSFMessage -Level Verbose -String 'Generation.MaxPKQueryFailed' -StringValues $col.ColumnName, $_
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
				# Query existing unique values from the DB in a single batched query
				$existingUnique = $null
				if ($ConnectionInfo -and $provider) {
					$uqParams = @{
						TableInfo      = $tableInfo
						TablePlan      = $tablePlan
						ConnectionInfo = $ConnectionInfo
						UniqueQueryLimit = $uniqueQueryLimit
						CommandTimeout = $dbCommandTimeout
					}
					if ($transaction) { $uqParams['Transaction'] = $transaction }
					$existingUnique = Get-SldgExistingUniqueValues @uqParams
				}

				$rowSetParams = @{
					TableInfo           = $tableInfo
					RowCount            = $tablePlan.RowCount
					GeneratorMap        = $Plan.GeneratorMap
					ForeignKeyValues    = $fkValues
					TableRules          = $tableRules
					ExistingUniqueValues = $existingUnique
				}

				# Two-tier AI: pass per-table generation notes from schema analysis
				if ($Plan.AIAdvice -and $Plan.AIAdvice.TableGenerationNotes -and $Plan.AIAdvice.TableGenerationNotes.ContainsKey($tablePlan.FullName)) {
					$rowSetParams['TableNotes'] = $Plan.AIAdvice.TableGenerationNotes[$tablePlan.FullName]
				}

				$rowSet = New-SldgRowSet @rowSetParams

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

					# Post-insert: collect actual PK values from DB for identity/auto-increment columns
					# that are NOT in the in-memory DataTable. Child tables need these FK references.
					foreach ($col in $tablePlan.Columns) {
						if (-not $col.IsPrimaryKey -and -not $col.IsUnique) { continue }
						$colKey = "$($tablePlan.SchemaName).$($tablePlan.TableName).$($col.ColumnName)"
						# Only query if this column's values are NOT already in fkValues (e.g., identity PKs)
						if ($fkValues.ContainsKey($colKey) -and $fkValues[$colKey].Count -gt 0) { continue }
						try {
							$safeTbl = Get-SldgSafeSqlName -SchemaName $tablePlan.SchemaName -TableName $tablePlan.TableName
							$safeCol = Get-SldgSafeSqlName -ColumnName $col.ColumnName
							$pkCmd = $ConnectionInfo.DbConnection.CreateCommand()
							if ($transaction) { $pkCmd.Transaction = $transaction }
							$pkCmd.CommandText = "SELECT DISTINCT TOP ($fkQueryLimit) $safeCol FROM $safeTbl"
							$pkCmd.CommandTimeout = $dbCommandTimeout
							$pkReader = $pkCmd.ExecuteReader()
							$pkVals = [System.Collections.Generic.List[object]]::new()
							while ($pkReader.Read()) {
								$pkv = $pkReader.GetValue(0)
								if ($pkv -isnot [DBNull]) { $pkVals.Add($pkv) }
							}
							$pkReader.Close()
							$pkReader.Dispose()
							$pkCmd.Dispose()
							if ($pkVals.Count -gt 0) {
								$fkValues[$colKey] = $pkVals.ToArray()
								Write-PSFMessage -Level Verbose -String 'Generation.PostInsertPKCollected' -StringValues $colKey, $pkVals.Count
							}
						}
						catch {
							Write-PSFMessage -Level Verbose -String 'Generation.PostInsertPKFailed' -StringValues $colKey, $_
						}
					}
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
			elseif ($PassThru -and $streamResult -and $streamResult.DataTable) {
				$tableResult.DataTable = $streamResult.DataTable
			}
			elseif ($rowSet -and $rowSet.DataTable) {
				# Release DataTable memory when not returning to caller
				$rowSet.DataTable.Dispose()
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
	$fkReenableFailures = [System.Collections.Generic.List[string]]::new()

	if ($disabledFKInfo -and $disabledFKInfo.DisabledTables.Count -gt 0 -and $ConnectionInfo -and $ConnectionInfo.DbConnection) {
		$reenableParams = @{
			DisabledInfo   = $disabledFKInfo
			ConnectionInfo = $ConnectionInfo
		}
		if ($transaction) { $reenableParams['Transaction'] = $transaction }
		$fkReenableFailures = Enable-SldgCircularFKConstraints @reenableParams
	}
	if ($fkReenableFailures.Count -gt 0) {
		$generationFailed = $true
		if ($transaction) {
			try { $transaction.Rollback() } catch { Write-PSFMessage -Level Error -String 'Generation.FKReenableRollbackFailed' -StringValues $_ }
			$transaction = $null
		}
		Stop-PSFFunction -String 'Generation.FKReenableCritical' -StringValues ($fkReenableFailures -join ', ') -EnableException $true
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
	Write-SldgAuditRecord -Plan $Plan -TotalInserted $totalInserted -StartTime $generationStartTime `
		-User $executingUser -GenerationFailed $generationFailed -TableResults $tableResults

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
}
