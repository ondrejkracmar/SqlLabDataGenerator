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

	$psd1Path = Join-Path (Get-Module SqlLabDataGenerator).ModuleBase 'SqlLabDataGenerator.psd1'

	$tableResults = [System.Collections.Generic.List[object]]::new()
	$totalInserted = 0
	$generationFailed = $false
	$tableIndex = 0
	$tableTotal = $Plan.Tables.Count

	foreach ($level in $levels) {
		if ($generationFailed) { break }

		$tablePlansInLevel = $level.Tables

		if ($tablePlansInLevel.Count -gt 1 -and -not $Transaction) {
			# Multiple independent tables — generate RowSets in parallel, write sequentially
			$parallelBag = [System.Collections.Concurrent.ConcurrentBag[object]]::new()
			$snapshotFkValues = @{} + $FkValues
			$localGenMap = $Plan.GeneratorMap
			$localGenRules = $Plan.GenerationRules

			$tablePlansInLevel | ForEach-Object -Parallel {
				Import-Module $using:psd1Path
				$tp = $_
				$bag = $using:parallelBag

				$trules = $null
				$gr = $using:localGenRules
				if ($gr.ContainsKey($tp.FullName)) { $trules = $gr[$tp.FullName] }

				$tInfo = [PSCustomObject]@{
					SchemaName  = $tp.SchemaName
					TableName   = $tp.TableName
					FullName    = $tp.FullName
					Columns     = foreach ($cp in $tp.Columns) {
						# Cross-reference table-level ForeignKeys to ensure column-level ForeignKey is set
						$colFK = $cp.ForeignKey
						if (-not $colFK -and $tp.ForeignKeys) {
							$matchedFK = $tp.ForeignKeys | Where-Object { $_.ParentColumn -eq $cp.ColumnName } | Select-Object -First 1
							if ($matchedFK) {
								$colFK = [PSCustomObject]@{
									ReferencedSchema = $matchedFK.ReferencedSchema
									ReferencedTable  = $matchedFK.ReferencedTable
									ReferencedColumn = $matchedFK.ReferencedColumn
								}
							}
						}
						[PSCustomObject]@{
							ColumnName     = $cp.ColumnName
							DataType       = $cp.DataType
							SemanticType   = $cp.SemanticType
							IsIdentity     = $cp.Skip -and $cp.DataType -notin @('timestamp', 'rowversion', 'geography', 'geometry', 'hierarchyid')
							IsComputed     = $false
							IsPrimaryKey   = [bool]$cp.IsPrimaryKey
							IsUnique       = [bool]$cp.IsUnique
							IsNullable     = if ($null -ne $cp.IsNullable) { [bool]$cp.IsNullable } else { $true }
							MaxLength      = $cp.MaxLength
							ForeignKey     = $colFK
							SchemaHint     = $cp.SchemaHint
							Classification = [PSCustomObject]@{ SemanticType = $cp.SemanticType; IsPII = $cp.IsPII }
							GenerationRule = $cp.CustomRule
						}
					}
					ForeignKeys = $tp.ForeignKeys
				}

				try {
					$rs = New-SldgRowSet -TableInfo $tInfo -RowCount $tp.RowCount `
						-GeneratorMap ($using:localGenMap) -ForeignKeyValues ($using:snapshotFkValues) -TableRules $trules

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
								if ($Transaction) { $cmd.Transaction = $Transaction }
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
							ColumnName     = $cp.ColumnName
							DataType       = $cp.DataType
							SemanticType   = $cp.SemanticType
							IsIdentity     = $cp.Skip -and $cp.DataType -notin @('timestamp', 'rowversion', 'geography', 'geometry', 'hierarchyid')
							IsComputed     = $false
							IsPrimaryKey   = [bool]$cp.IsPrimaryKey
							IsUnique       = [bool]$cp.IsUnique
							IsNullable     = if ($null -ne $cp.IsNullable) { [bool]$cp.IsNullable } else { $true }
							MaxLength      = $cp.MaxLength
							ForeignKey     = $colFK
							SchemaHint     = $cp.SchemaHint
							Classification = [PSCustomObject]@{ SemanticType = $cp.SemanticType; IsPII = $cp.IsPII }
							GenerationRule = $cp.CustomRule
						}
					}
					ForeignKeys = $tablePlan.ForeignKeys
				}

				$rowSet = $null
				$streamResult = $null
				try {
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
						$streamResult = Invoke-SldgStreamingGeneration @streamParams
						foreach ($key in $streamResult.GeneratedValues.Keys) { $FkValues[$key] = $streamResult.GeneratedValues[$key] }
						$insertedCount = $streamResult.InsertedCount
					}
					else {
						$rowSet = New-SldgRowSet -TableInfo $tableInfo -RowCount $tablePlan.RowCount `
							-GeneratorMap $Plan.GeneratorMap -ForeignKeyValues $FkValues -TableRules $tableRules
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
					elseif ($PassThru -and $streamResult -and $streamResult.DataTables) {
						$tableResult.DataTables = $streamResult.DataTables
					}
					$tableResults.Add($tableResult)
				}
				catch {
					Write-PSFMessage -Level Warning -Message ($script:strings.'Generation.Failed' -f $tablePlan.SchemaName, $tablePlan.TableName, $_)
					$tableResults.Add([SqlLabDataGenerator.TableResult]@{
						TableName  = $tablePlan.FullName
						RowCount   = 0
						Success    = $false
						Error      = $_.Exception.Message
					})
					if ($Transaction) {
						$generationFailed = $true
						Write-PSFMessage -Level Warning -String 'Generation.RollingBack' -StringValues $tablePlan.FullName
						try { $Transaction.Rollback() }
						catch { Write-PSFMessage -Level Error -String 'Generation.RollbackCritical' -StringValues $_ }
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
