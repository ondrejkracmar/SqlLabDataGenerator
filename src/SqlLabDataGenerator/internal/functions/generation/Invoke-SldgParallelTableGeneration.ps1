function Invoke-SldgParallelTableGeneration {
	<#
	.SYNOPSIS
		Generates data for tables using parallel execution across dependency levels.
	.DESCRIPTION
		Groups tables by FK dependency level and generates independent tables in
		parallel (PS 7+ ForEach-Object -Parallel). Tables with FK dependencies on
		same-level tables or when a transaction is active fall back to sequential.
		Extracted from Invoke-SldgDataGeneration for maintainability.
	#>
	[CmdletBinding(SupportsShouldProcess)]
	param (
		[Parameter(Mandatory)]
		$Plan,

		[Parameter(Mandatory)]
		[hashtable]$FkValues,

		$ConnectionInfo,

		$Provider,

		$Transaction,

		[int]$BatchSize,

		[int]$ThrottleLimit,

		[int]$StreamingThreshold,

		[int]$StreamingChunkSize,

		[switch]$NoInsert,

		[switch]$PassThru
	)

	$levels = Group-SldgTablesByLevel -Tables $Plan.Tables
	Write-PSFMessage -Level Host -Message ($script:strings.'Generation.ParallelStarting' -f $levels.Count, $ThrottleLimit)

	$fkQueryLimit = Get-PSFConfigValue -FullName 'SqlLabDataGenerator.Generation.ForeignKeyQueryLimit'
	$dbCommandTimeout = Get-PSFConfigValue -FullName 'SqlLabDataGenerator.Database.CommandTimeout'

	$psd1Path = Join-Path (Get-Module SqlLabDataGenerator).ModuleBase 'SqlLabDataGenerator.psd1'

	$tableResults = [System.Collections.Generic.List[object]]::new()
	$totalInserted = 0
	$generationFailed = $false
	$failedTables = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
	$tableIndex = 0
	$tableTotal = $Plan.Tables.Count

	foreach ($level in $levels) {
		if ($generationFailed) { break }

		$tablePlansInLevel = $level.Tables

		# Filter out tables whose FK parent tables have already failed
		if ($failedTables.Count -gt 0) {
			$skippedInLevel = @()
			$validInLevel = @()
			foreach ($tp in $tablePlansInLevel) {
				if ($tp.ForeignKeys -and $tp.ForeignKeys.Count -gt 0) {
					$failedParents = @($tp.ForeignKeys | ForEach-Object { "$($_.ReferencedSchema).$($_.ReferencedTable)" } | Where-Object { $failedTables.Contains($_) } | Select-Object -Unique)
					if ($failedParents.Count -gt 0) {
						[void]$failedTables.Add($tp.FullName)
						Write-PSFMessage -Level Warning -Message ($script:strings.'Generation.SkippedDueToParent' -f $tp.FullName, ($failedParents -join ', '))
						$tableResults.Add([SqlLabDataGenerator.TableResult]@{
							TableName  = $tp.FullName
							RowCount   = 0
							Success    = $false
							Error      = "Skipped: parent table(s) failed: $($failedParents -join ', ')"
						})
						$tableIndex++
						$skippedInLevel += $tp
						continue
					}
				}
				$validInLevel += $tp
			}
			$tablePlansInLevel = $validInLevel
			if ($tablePlansInLevel.Count -eq 0) { continue }
		}

		if ($tablePlansInLevel.Count -gt 1 -and -not $Transaction) {
			# Multiple independent tables — generate RowSets in parallel, write sequentially
			$parallelBag = [System.Collections.Concurrent.ConcurrentBag[object]]::new()
			$snapshotFkValues = @{} + $FkValues
			$localGenMap = $Plan.GeneratorMap
			$localGenRules = $Plan.GenerationRules

			$tablePlansInLevel | ForEach-Object -Parallel {
				# Import only once per runspace — pooled runspaces get reused across iterations
				$mod = Get-Module SqlLabDataGenerator
				if (-not $mod) { $mod = Import-Module $using:psd1Path -PassThru }
				$tp = $_
				$bag = $using:parallelBag

				$trules = $null
				$gr = $using:localGenRules
				if ($gr.ContainsKey($tp.FullName)) { $trules = $gr[$tp.FullName] }

				$tInfo = & $mod { param($t) ConvertTo-SldgTableInfo -TablePlan $t } $tp

				try {
					$rs = & $mod {
						param($ti, $rc, $gm, $fk, $tr)
						New-SldgRowSet -TableInfo $ti -RowCount $rc `
							-GeneratorMap $gm -ForeignKeyValues $fk -TableRules $tr
					} $tInfo $tp.RowCount ($using:localGenMap) ($using:snapshotFkValues) $trules

					$bag.Add(@{
						FullName        = $tp.FullName
						RowSet          = $rs
						GeneratedValues = $rs.GeneratedValues
						Error           = $null
					})
				}
				catch {
					$bag.Add(@{
						FullName        = $tp.FullName
						RowSet          = $null
						GeneratedValues = @{}
						Error           = $_.Exception.Message
					})
				}
			} -ThrottleLimit $ThrottleLimit

			# Sequential: write results and merge FK values
			foreach ($result in $parallelBag) {
				$tablePlan = $tablePlansInLevel | Where-Object { $_.FullName -eq $result.FullName }
				$tableIndex++

				if ($result.Error) {
					[void]$failedTables.Add($tablePlan.FullName)
					Write-PSFMessage -Level Warning -Message ($script:strings.'Generation.Failed' -f $tablePlan.SchemaName, $tablePlan.TableName, $result.Error)
					$tableResults.Add([SqlLabDataGenerator.TableResult]@{
						TableName  = $tablePlan.FullName
						RowCount   = 0
						Success    = $false
						Error      = $result.Error
					})
					continue
				}

				foreach ($key in $result.GeneratedValues.Keys) {
					$FkValues[$key] = $result.GeneratedValues[$key]
				}

				$insertedCount = 0
				if (-not $NoInsert -and $ConnectionInfo) {
					try {
						$writeParams = @{
							ConnectionInfo = $ConnectionInfo
							SchemaName     = $tablePlan.SchemaName
							TableName      = $tablePlan.TableName
							Data           = $result.RowSet.DataTable
							BatchSize      = $BatchSize
						}
						if ($Transaction) { $writeParams['Transaction'] = $Transaction }
						$insertedCount = & $Provider.FunctionMap.WriteData @writeParams
					}
					catch {
						[void]$failedTables.Add($tablePlan.FullName)
						Write-PSFMessage -Level Warning -Message ($script:strings.'Generation.Failed' -f $tablePlan.SchemaName, $tablePlan.TableName, $_)
						$tableResults.Add([SqlLabDataGenerator.TableResult]@{
							TableName  = $tablePlan.FullName
							RowCount   = 0
							Success    = $false
							Error      = $_.Exception.Message
						})
						continue
					}
				}
				else {
					$insertedCount = $result.RowSet.RowCount
				}

				$totalInserted += $insertedCount
				Write-PSFMessage -Level Host -Message ($script:strings.'Generation.TableComplete' -f $tablePlan.FullName, $insertedCount)

				$tableResult = [SqlLabDataGenerator.TableResult]@{
					TableName  = $tablePlan.FullName
					RowCount   = $insertedCount
					Success    = $true
					Error      = $null
				}
				if ($PassThru -and $result.RowSet) {
					$tableResult.DataTable = $result.RowSet.DataTable
				}
				$tableResults.Add($tableResult)
			}
		}
		else {
			# Single table at this level, or transaction active — sequential
			foreach ($tablePlan in $tablePlansInLevel) {
				if ($generationFailed) { break }
				$tableIndex++
				$pct = [int](($tableIndex - 1) / [Math]::Max($tableTotal, 1) * 100)
				Write-Progress -Activity 'Generating data' -Status "Table $tableIndex of ${tableTotal}: $($tablePlan.FullName)" -PercentComplete $pct

				if (-not $PSCmdlet.ShouldProcess("$($tablePlan.FullName) ($($tablePlan.RowCount) rows)", "Generate data")) { continue }

				Write-PSFMessage -Level Host -Message ($script:strings.'Generation.Table' -f $tablePlan.RowCount, $tablePlan.SchemaName, $tablePlan.TableName)

				# FK DB fallback: ensure $FkValues has parent PK values for every FK reference
				if ($tablePlan.ForeignKeys -and $tablePlan.ForeignKeys.Count -gt 0 -and $ConnectionInfo -and $Provider) {
					foreach ($fk in $tablePlan.ForeignKeys) {
						$refKey = "$($fk.ReferencedSchema).$($fk.ReferencedTable).$($fk.ReferencedColumn)"
						if (-not $FkValues.ContainsKey($refKey) -or $FkValues[$refKey].Count -eq 0) {
							try {
								$safeRef = Get-SldgSafeSqlName -SchemaName $fk.ReferencedSchema -TableName $fk.ReferencedTable
								$safeCol = Get-SldgSafeSqlName -ColumnName $fk.ReferencedColumn
								$cmd = $ConnectionInfo.DbConnection.CreateCommand()
								try {
									if ($Transaction) { $cmd.Transaction = $Transaction }
									$cmd.CommandText = "SELECT DISTINCT TOP ($fkQueryLimit) $safeCol FROM $safeRef"
									$cmd.CommandTimeout = $dbCommandTimeout
									$reader = $cmd.ExecuteReader()
									try {
										$vals = [System.Collections.Generic.List[object]]::new()
										while ($reader.Read()) {
											$v = $reader.GetValue(0)
											if ($v -isnot [DBNull]) { $vals.Add($v) }
										}
									}
									finally {
										$reader.Close()
										$reader.Dispose()
									}
								}
								finally {
									$cmd.Dispose()
								}
								if ($vals.Count -gt 0) {
									$FkValues[$refKey] = $vals.ToArray()
									Write-PSFMessage -Level Verbose -Message ($script:strings.'Generation.FKFallbackLoaded' -f $refKey, $vals.Count)
								}
							}
							catch {
								Write-PSFMessage -Level Warning -Message ($script:strings.'Generation.FKFallbackFailed' -f $refKey, $_)
							}
						}
					}
				}

				$tableRules = if ($Plan.GenerationRules.ContainsKey($tablePlan.FullName)) { $Plan.GenerationRules[$tablePlan.FullName] } else { $null }
				$tableInfo = ConvertTo-SldgTableInfo -TablePlan $tablePlan

				# For non-identity integer PK columns, query MAX(PK) so we can auto-generate sequential values
				if ($ConnectionInfo) {
					foreach ($col in $tableInfo.Columns) {
						if ($col.IsPrimaryKey -and -not $col.IsIdentity -and -not $col.IsComputed -and -not $col.ForeignKey -and $col.DataType -match '^(int|bigint|smallint|tinyint)$') {
							try {
								$safeTbl = Get-SldgSafeSqlName -SchemaName $tablePlan.SchemaName -TableName $tablePlan.TableName
								$safeCol = Get-SldgSafeSqlName -ColumnName $col.ColumnName
								$cmd = $ConnectionInfo.DbConnection.CreateCommand()
								try {
									if ($Transaction) { $cmd.Transaction = $Transaction }
									$cmd.CommandText = "SELECT ISNULL(MAX($safeCol), 0) FROM $safeTbl"
									$cmd.CommandTimeout = $dbCommandTimeout
									$maxVal = $cmd.ExecuteScalar()
									$col | Add-Member -NotePropertyName 'PKStartValue' -NotePropertyValue ([long]$maxVal) -Force
								}
								finally {
									$cmd.Dispose()
								}
							}
							catch {
								Write-PSFMessage -Level Verbose -Message ($script:strings.'Generation.ParallelMaxPKQueryFailed' -f $col.ColumnName, $_)
							}
						}
					}
				}

				$rowSet = $null
				$streamResult = $null
				try {
					# Fetch existing unique values and table notes for the sequential fallback path
					$existingUnique = $null
					if ($ConnectionInfo -and $Provider) {
						$uqParams = @{
							TableInfo        = $tableInfo
							TablePlan        = $tablePlan
							ConnectionInfo   = $ConnectionInfo
							UniqueQueryLimit = 1000
							CommandTimeout   = $dbCommandTimeout
						}
						if ($Transaction) { $uqParams['Transaction'] = $Transaction }
						$existingUnique = Get-SldgExistingUniqueValue @uqParams
					}
					$seqTableNotes = $null
					if ($Plan.AIAdvice -and $Plan.AIAdvice.TableGenerationNotes -and $Plan.AIAdvice.TableGenerationNotes.ContainsKey($tablePlan.FullName)) {
						$seqTableNotes = $Plan.AIAdvice.TableGenerationNotes[$tablePlan.FullName]
					}

					if ($StreamingThreshold -gt 0 -and $tablePlan.RowCount -gt $StreamingThreshold) {
						Write-PSFMessage -Level Host -Message ($script:strings.'Generation.StreamingStarting' -f $tablePlan.FullName, $tablePlan.RowCount, $StreamingChunkSize)
						$streamParams = @{
							TableInfo        = $tableInfo
							TotalRowCount    = $tablePlan.RowCount
							ChunkSize        = $StreamingChunkSize
							GeneratorMap     = $Plan.GeneratorMap
							ForeignKeyValues = $FkValues
							TableRules       = $tableRules
							BatchSize        = $BatchSize
							NoInsert         = $NoInsert
							PassThru         = $PassThru
						}
						if ($ConnectionInfo) { $streamParams['ConnectionInfo'] = $ConnectionInfo }
						if ($Transaction) { $streamParams['Transaction'] = $Transaction }
						if ($Provider) { $streamParams['WriteFunction'] = $Provider.FunctionMap.WriteData }
						if ($existingUnique) { $streamParams['ExistingUniqueValues'] = $existingUnique }
						if ($seqTableNotes) { $streamParams['TableNotes'] = $seqTableNotes }
						$streamResult = Invoke-SldgStreamingGeneration @streamParams
						foreach ($key in $streamResult.GeneratedValues.Keys) { $FkValues[$key] = $streamResult.GeneratedValues[$key] }
						$insertedCount = $streamResult.InsertedCount
					}
					else {
						$rowSetParams = @{
							TableInfo            = $tableInfo
							RowCount             = $tablePlan.RowCount
							GeneratorMap         = $Plan.GeneratorMap
							ForeignKeyValues     = $FkValues
							TableRules           = $tableRules
						}
						if ($existingUnique) { $rowSetParams['ExistingUniqueValues'] = $existingUnique }
						if ($seqTableNotes) { $rowSetParams['TableNotes'] = $seqTableNotes }
						$rowSet = New-SldgRowSet @rowSetParams
						foreach ($key in $rowSet.GeneratedValues.Keys) { $FkValues[$key] = $rowSet.GeneratedValues[$key] }
						$insertedCount = 0
						if (-not $NoInsert -and $ConnectionInfo) {
							$writeParams = @{
								ConnectionInfo = $ConnectionInfo
								SchemaName     = $tablePlan.SchemaName
								TableName      = $tablePlan.TableName
								Data           = $rowSet.DataTable
								BatchSize      = $BatchSize
							}
							if ($Transaction) { $writeParams['Transaction'] = $Transaction }
							$insertedCount = & $Provider.FunctionMap.WriteData @writeParams
						}
						else { $insertedCount = $rowSet.RowCount }
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
					$tableResults.Add($tableResult)
				}
				catch {
					[void]$failedTables.Add($tablePlan.FullName)
					Write-PSFMessage -Level Warning -Message ($script:strings.'Generation.Failed' -f $tablePlan.SchemaName, $tablePlan.TableName, $_)
					$tableResults.Add([SqlLabDataGenerator.TableResult]@{
						TableName  = $tablePlan.FullName
						RowCount   = 0
						Success    = $false
						Error      = $_.Exception.Message
					})
					if ($Transaction) {
						$generationFailed = $true
						Write-PSFMessage -Level Warning -Message ($script:strings.'Generation.RollingBack' -f $tablePlan.FullName)
						try { $Transaction.Rollback() }
						catch { Write-PSFMessage -Level Error -Message ($script:strings.'Generation.RollbackCritical' -f $_) }
						$totalInserted = 0
						foreach ($tr in $tableResults) { if ($tr.Success) { $tr.RolledBack = $true } }
						break
					}
				}
			}
		}
	}

	[PSCustomObject]@{
		TableResults    = $tableResults.ToArray()
		TotalInserted   = $totalInserted
		GenerationFailed = $generationFailed
	}
}
