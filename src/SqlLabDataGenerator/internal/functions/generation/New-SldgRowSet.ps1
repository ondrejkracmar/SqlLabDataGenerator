function New-SldgRowSet {
	<#
	.SYNOPSIS
		Generates a DataTable of synthetic rows for a single table.
	.DESCRIPTION
		Creates the specified number of rows, respecting FK references, identity columns,
		unique constraints, and generation rules.

		When AI generation is enabled (Generation.AIGeneration = $true), attempts to
		generate entire rows via AI for richer, contextually-consistent data.
		Falls back to static generators when AI is unavailable or fails.

		Supports context-dependent structured data: columns with CrossColumnDependency
		rules are automatically reordered so that the dependency column is generated first.
		A per-row $rowContext hashtable tracks generated values, enabling downstream columns
		(e.g., a JSON column) to read the dependency value and vary their output accordingly.

		Returns a System.Data.DataTable ready for insertion.

	.NOTES
		Seed reproducibility: The global seed (Generation.Seed) is set once in
		Invoke-SldgDataGeneration via Get-Random -SetSeed. Individual generators
		that call Get-Random will use the same internal RNG state, but any non-
		deterministic sources (AI generation, GUIDs, DateTime.Now) cannot be seeded.
		For fully reproducible output, disable AI generation and avoid GUID columns.
	#>
	[CmdletBinding()]
	param (
		[Parameter(Mandatory)]
		$TableInfo,

		[int]$RowCount = 100,

		[hashtable]$GeneratorMap,

		[hashtable]$ForeignKeyValues,

		[hashtable]$TableRules,

		[hashtable]$SharedUniqueTracker,

		[hashtable]$SharedPKAutoIncrements,

		[hashtable]$ExistingUniqueValues,

		[string]$TableNotes
	)

	if (-not $GeneratorMap) { $GeneratorMap = Get-SldgGeneratorMap }

	# Cache config values to avoid repeated lookups in hot loop
	$cachedNullProbability = Get-PSFConfigValue -FullName 'SqlLabDataGenerator.Generation.NullProbability'
	$useAIGen = Get-PSFConfigValue -FullName 'SqlLabDataGenerator.Generation.AIGeneration'
	$aiProvider = Get-PSFConfigValue -FullName 'SqlLabDataGenerator.AI.Provider'
	$maxUniqueRetries = Get-PSFConfigValue -FullName 'SqlLabDataGenerator.Generation.MaxUniqueRetries'
	$locale = Get-PSFConfigValue -FullName 'SqlLabDataGenerator.Generation.Locale'

	$dataTable = New-Object System.Data.DataTable
	try {

	# Build columns for the DataTable (skip identity and computed)
	$activeColumns = @()
	foreach ($col in $TableInfo.Columns) {
		if ($col.IsIdentity -or $col.IsComputed) {
			Write-PSFMessage -Level Verbose -Message ($script:strings.'Generation.SkippingComputed' -f $TableInfo.FullName, $col.ColumnName)
			continue
		}

		# Skip rowversion/timestamp
		if ($col.DataType -in @('timestamp', 'rowversion')) { continue }

		# Skip spatial/UDT types — cannot be generated via SqlBulkCopy
		if ($col.DataType -in @('geography', 'geometry', 'hierarchyid')) {
			Write-PSFMessage -Level Verbose -Message ($script:strings.'Generation.SkippingSpatial' -f $TableInfo.FullName, $col.ColumnName)
			continue
		}

		# Map SQL type to .NET type for DataTable
		$netType = switch -Regex ($col.DataType.ToLower()) {
			'^(int)$' { [int] }
			'^(bigint)$' { [long] }
			'^(smallint)$' { [int16] }
			'^(tinyint)$' { [byte] }
			'^(bit)$' { [bool] }
			'^(decimal|numeric|money|smallmoney)$' { [decimal] }
			'^(float)$' { [double] }
			'^(real)$' { [float] }
			'^(date|datetime|datetime2|smalldatetime|datetimeoffset)$' { [datetime] }
			'^(time)$' { [timespan] }
			'^(uniqueidentifier)$' { [guid] }
			'^(binary|varbinary|image)$' { [byte[]] }
			default { [string] }
		}

		$dtCol = New-Object System.Data.DataColumn($col.ColumnName, $netType)
		$dtCol.AllowDBNull = $col.IsNullable
		[void]$dataTable.Columns.Add($dtCol)
		$activeColumns += $col
	}

	# Compute PK columns for uniqueness enforcement (needed in both standard and streaming mode)
	$pkColumns = @($activeColumns | Where-Object { $_.IsPrimaryKey })
	$hasCompositePK = $pkColumns.Count -gt 1

	# Build auto-increment counters for non-identity integer PK columns with PKStartValue
	# When SharedPKAutoIncrements is provided (streaming mode), reuse it across chunks
	if ($SharedPKAutoIncrements) {
		$pkAutoIncrements = $SharedPKAutoIncrements
	}
	else {
		$pkAutoIncrements = @{}
		foreach ($col in $activeColumns) {
			if ($col.IsPrimaryKey -and -not $col.IsIdentity -and $null -ne $col.PKStartValue -and $col.DataType -match '^(int|bigint|smallint|tinyint)$') {
				$pkAutoIncrements[$col.ColumnName] = [long]$col.PKStartValue
			}
		}
	}

	# Track unique values for unique constraint columns
	# When SharedUniqueTracker is provided (streaming mode), reuse it across chunks
	if ($SharedUniqueTracker) {
		$uniqueTracker = $SharedUniqueTracker
	}
	else {
		$uniqueTracker = @{}
		foreach ($col in $activeColumns) {
			if ($col.IsUnique -or ($col.IsPrimaryKey -and -not $hasCompositePK)) {
				$tracker = [System.Collections.Generic.HashSet[string]]::new()
				# Pre-seed with existing DB values to avoid duplicating data already in the table
				if ($ExistingUniqueValues -and $ExistingUniqueValues.ContainsKey($col.ColumnName)) {
					foreach ($existingVal in $ExistingUniqueValues[$col.ColumnName]) {
						[void]$tracker.Add([string]$existingVal)
					}
				}
				$uniqueTracker[$col.ColumnName] = $tracker
			}
		}
		if ($hasCompositePK) {
			$uniqueTracker['__CompositePK__'] = [System.Collections.Generic.HashSet[string]]::new()
		}
	}

	# Reorder: columns with cross-column dependencies go after their dependency columns
	$dependentCols = @()
	$independentCols = @()
	$depGraph = @{}
	foreach ($col in $activeColumns) {
		$depCol = $null
		if ($TableRules -and $TableRules.ContainsKey($col.ColumnName) -and $TableRules[$col.ColumnName].CrossColumnDependency) {
			$depCol = $TableRules[$col.ColumnName].CrossColumnDependency
		}
		elseif ($col.CustomRule -is [hashtable] -and $col.CustomRule.CrossColumnDependency) {
			$depCol = $col.CustomRule.CrossColumnDependency
		}
		if ($depCol) {
			$depGraph[$col.ColumnName] = $depCol
			$dependentCols += $col
		} else { $independentCols += $col }
	}
	# Detect circular cross-column dependencies using DFS (handles A->B->C->A and longer cycles)
	foreach ($colName in @($depGraph.Keys)) {
		$visited = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
		[void]$visited.Add($colName)
		$cursor = $depGraph[$colName]
		while ($cursor -and $depGraph.ContainsKey($cursor)) {
			if ($cursor -eq $colName) {
				Write-PSFMessage -Level Warning -Message "Circular cross-column dependency detected for column '$colName' in '$($TableInfo.FullName)'. Dependency chain will be broken."
				$depGraph.Remove($colName)
				$dependentCols = @($dependentCols | Where-Object { $_.ColumnName -ne $colName })
				$independentCols += ($activeColumns | Where-Object { $_.ColumnName -eq $colName })
				break
			}
			if (-not $visited.Add($cursor)) { break }
			$cursor = $depGraph[$cursor]
		}
	}
	if ($dependentCols.Count -gt 0) {
		$activeColumns = @($independentCols) + @($dependentCols)
	}

	# Pre-compute semantic types for columns that lack one (avoids per-row Resolve-SldgSemanticType calls)
	foreach ($col in $activeColumns) {
		if (-not $col.SemanticType -and -not ($col.Classification -and $col.Classification.SemanticType)) {
			$resolved = Resolve-SldgSemanticType -DataType $col.DataType -MaxLength $col.MaxLength -IsNullable $col.IsNullable
			if ($resolved -and $resolved.Type) {
				$col | Add-Member -NotePropertyName 'SemanticType' -NotePropertyValue $resolved.Type -Force
			}
		}
	}

	# Determine which columns are FK-bound (AI shouldn't generate these)
	$nonFkColumns = @($activeColumns | Where-Object { (-not $_.ForeignKey -or -not $ForeignKeyValues) -and -not $pkAutoIncrements.ContainsKey($_.ColumnName) })

	# Try AI batch generation for non-FK columns
	$aiBatch = $null

	if ($useAIGen -and $aiProvider -ne 'None' -and $nonFkColumns.Count -gt 0) {
		# Filter to columns without custom rules (those are handled manually)
		$aiCandidates = @($nonFkColumns | Where-Object {
				-not ($TableRules -and $TableRules.ContainsKey($_.ColumnName))
			})

		if ($aiCandidates.Count -gt 0) {
			$maxAIBatch = Get-PSFConfigValue -FullName 'SqlLabDataGenerator.Generation.MaxAIBatchSize'
			$aiParams = @{
				Columns   = $aiCandidates
				TableName = $TableInfo.FullName
				BatchSize = [math]::Min($RowCount, $maxAIBatch)
				Locale    = $locale
			}
			if ($ExistingUniqueValues) { $aiParams['ExistingUniqueValues'] = $ExistingUniqueValues }
			if ($TableNotes) { $aiParams['TableNotes'] = $TableNotes }
			$aiBatch = New-SldgAIGeneratedBatch @aiParams
		}
	}

	# Generate rows
	$generatedValues = @{}
	$aiBatchIndex = 0

	# Sequential date counter for unique date columns (avoids random collision on date-only values)
	$dateSequenceCounters = @{}
	foreach ($col in $activeColumns) {
		if ($uniqueTracker.ContainsKey($col.ColumnName) -and $col.DataType -match '^(date|datetime|datetime2|smalldatetime)$') {
			$dateSequenceCounters[$col.ColumnName] = 0
		}
	}

	# Pre-compute composite PK combination pool size for FK-based PKs
	$compositePKPoolSize = [long]::MaxValue
	if ($hasCompositePK) {
		$allPKsAreFk = $true
		$poolSize = [long]1
		foreach ($pkCol in $pkColumns) {
			if ($pkCol.ForeignKey -and $ForeignKeyValues) {
				$refKey = "$($pkCol.ForeignKey.ReferencedSchema).$($pkCol.ForeignKey.ReferencedTable).$($pkCol.ForeignKey.ReferencedColumn)"
				$vals = $ForeignKeyValues[$refKey]
				if ($vals) { $poolSize *= $vals.Count }
				else { $allPKsAreFk = $false; break }
			} elseif ($pkAutoIncrements.ContainsKey($pkCol.ColumnName)) {
				continue
			} else { $allPKsAreFk = $false; break }
		}
		if ($allPKsAreFk -and $poolSize -lt [long]::MaxValue) {
			$compositePKPoolSize = $poolSize
			if ($RowCount -gt $compositePKPoolSize) {
				Write-PSFMessage -Level Warning -Message "Requested $RowCount rows for '$($TableInfo.FullName)' but only $compositePKPoolSize unique FK combinations exist. Capping to $compositePKPoolSize."
				$RowCount = [int]$compositePKPoolSize
			}
		}
	}

	# Suppress DataTable index/constraint checks during bulk population for better performance
	$dataTable.BeginLoadData()
	try {

	for ($rowIdx = 0; $rowIdx -lt $RowCount; $rowIdx++) {
		$retryCount = 0
		$rowValid = $false

		while (-not $rowValid -and $retryCount -lt $maxUniqueRetries) {
			$row = $dataTable.NewRow()
			$rowValid = $true
			$rowContext = @{}
			foreach ($col in $activeColumns) {
				$customRule = $null
				if ($TableRules -and $TableRules.ContainsKey($col.ColumnName)) {
					$customRule = $TableRules[$col.ColumnName]
				}

				$value = $null

				# Auto-generate sequential PK values for non-identity integer PK columns
				if ($pkAutoIncrements.ContainsKey($col.ColumnName)) {
					$pkAutoIncrements[$col.ColumnName]++
					$value = $pkAutoIncrements[$col.ColumnName]
				}

				# Try AI-generated value first (for non-FK, non-custom-rule columns)
				elseif ($aiBatch -and -not $customRule -and (-not $col.ForeignKey -or -not $ForeignKeyValues) -and $aiBatchIndex -lt $aiBatch.Count) {
					$aiRow = $aiBatch[$aiBatchIndex]
					if ($aiRow.ContainsKey($col.ColumnName) -and $aiRow[$col.ColumnName] -isnot [DBNull]) {
						$value = $aiRow[$col.ColumnName]
					}
				}

				# Smart FK unique selection: for columns that are FK + unique tracked,
				# pick directly from unused parent values to avoid wasteful retries
				if ($null -eq $value -and $col.ForeignKey -and $ForeignKeyValues -and $uniqueTracker.ContainsKey($col.ColumnName)) {
					$refKey = "$($col.ForeignKey.ReferencedSchema).$($col.ForeignKey.ReferencedTable).$($col.ForeignKey.ReferencedColumn)"
					$parentValues = $ForeignKeyValues[$refKey]
					if ($parentValues -and $parentValues.Count -gt 0) {
						$available = @($parentValues | Where-Object { -not $uniqueTracker[$col.ColumnName].Contains([string]$_) })
						if ($available.Count -gt 0) {
							$value = $available | Get-Random
						} else {
							Write-PSFMessage -Level Warning -Message "All FK values exhausted for unique column '$($col.ColumnName)' in '$($TableInfo.FullName)'. Cannot generate more unique rows."
							$retryCount = $maxUniqueRetries
							$rowValid = $false
							break
						}
					}
				}

				# Sequential date generation for unique date columns
				if ($null -eq $value -and $dateSequenceCounters.ContainsKey($col.ColumnName)) {
					$baseDate = [datetime]'2020-01-01'
					do {
						$dateSequenceCounters[$col.ColumnName]++
						$value = $baseDate.AddDays($dateSequenceCounters[$col.ColumnName])
					} while ($uniqueTracker[$col.ColumnName].Contains([string]$value) -and $dateSequenceCounters[$col.ColumnName] -lt 36500)
				}

				# Fall back to standard generator
				if ($null -eq $value) {
					$value = New-SldgGeneratedValue -Column $col -GeneratorMap $GeneratorMap -ForeignKeyValues $ForeignKeyValues -CustomRule $customRule -NullProbability $cachedNullProbability -RowContext $rowContext
				}

				# Convert string "null" from AI to actual DBNull
				if ($value -is [string] -and $value -eq 'null') { $value = [DBNull]::Value }

				if ($null -eq $value) { continue }

				# Clamp/convert values BEFORE uniqueness check so the tracked value matches what gets inserted
				if ($value -isnot [DBNull]) {
					# Clamp numeric values to valid SQL type ranges (AI can generate out-of-range values)
					switch ($col.DataType.ToLower()) {
						'tinyint' { $value = [Math]::Max(0, [Math]::Min(255, [int]$value)) }
						'smallint' { $value = [Math]::Max(-32768, [Math]::Min(32767, [int]$value)) }
						'int' { $value = [Math]::Max(-2147483648, [Math]::Min(2147483647, [long]$value)) }
						'bigint' { $value = [Math]::Max([long]::MinValue, [Math]::Min([long]::MaxValue, [long]$value)) }
						{ $_ -in @('decimal', 'numeric') } { try { $value = [decimal]$value } catch { $value = [decimal]0 } }
						{ $_ -in @('float', 'real') } { try { $value = [double]$value } catch { $value = [double]0 } }
						{ $_ -eq 'money' -or $_ -eq 'smallmoney' } { try { $value = [decimal]$value } catch { $value = [decimal]0 } }
					}
					# Truncate strings exceeding MaxLength
					if ($col.MaxLength -and $col.MaxLength -gt 0 -and $value -is [string] -and $value.Length -gt $col.MaxLength) {
						Write-PSFMessage -Level Warning -Message "Truncating value for column '$($col.ColumnName)' from $($value.Length) to $($col.MaxLength) characters."
						$value = $value.Substring(0, $col.MaxLength)
					}
				}

				# Enforce uniqueness (after clamping so tracked value matches inserted value)
				if ($uniqueTracker.ContainsKey($col.ColumnName)) {
					if ($value -isnot [DBNull]) {
						$valueStr = [string]$value
						if ($uniqueTracker[$col.ColumnName].Contains($valueStr)) {
							$rowValid = $false
							$retryCount++
							break
						}
					}
				}

				# Handle type conversion
				if ($value -is [DBNull]) {
					$row[$col.ColumnName] = [DBNull]::Value
				}
				elseif ($col.DataType -eq 'uniqueidentifier' -and $value -is [string]) {
					$row[$col.ColumnName] = [guid]$value
				}
				else {
					# Unwrap PSObject to raw .NET type for DataTable compatibility
					$row[$col.ColumnName] = $value.psobject.BaseObject
				}

				# Track generated value for cross-column dependency context
				$rowContext[$col.ColumnName] = $value
			}

			if ($rowValid -and $hasCompositePK) {
				# Enforce composite PK uniqueness (use null byte delimiter to avoid collisions with data containing '|')
				$compositeKey = ($pkColumns | ForEach-Object { [string]$row[$_.ColumnName] }) -join "`0"
				if ($uniqueTracker['__CompositePK__'].Contains($compositeKey)) {
					$rowValid = $false
					$retryCount++
					# Bail out early if FK combination pool is exhausted
					if ($uniqueTracker['__CompositePK__'].Count -ge $compositePKPoolSize) {
						$retryCount = $maxUniqueRetries
					}
				}
			}

			if ($rowValid) {
				# Register unique values
				foreach ($col in $activeColumns) {
					if ($uniqueTracker.ContainsKey($col.ColumnName) -and $row[$col.ColumnName] -isnot [DBNull]) {
						[void]$uniqueTracker[$col.ColumnName].Add([string]$row[$col.ColumnName])
					}
				}
				if ($hasCompositePK) {
					# Reuse $compositeKey already computed above
					[void]$uniqueTracker['__CompositePK__'].Add($compositeKey)
				}
				$aiBatchIndex++
			}
		}

		# Skip row if uniqueness retries were exhausted
		if (-not $rowValid) {
			Write-PSFMessage -Level Warning -Message "Row $rowIdx for '$($TableInfo.FullName)' skipped: could not generate unique values after $maxUniqueRetries retries."
			continue
		}

		# Safety net: ensure non-nullable FK columns have values before adding to DataTable
		$rowOK = $true
		foreach ($col in $activeColumns) {
			if (-not $col.ForeignKey -or $col.IsNullable) { continue }
			if (-not $dataTable.Columns.Contains($col.ColumnName)) { continue }
			if ($row[$col.ColumnName] -is [DBNull] -or $null -eq $row[$col.ColumnName]) {
				# Last-resort FK resolution: try ForeignKeyValues one more time
				$refKey = "$($col.ForeignKey.ReferencedSchema).$($col.ForeignKey.ReferencedTable).$($col.ForeignKey.ReferencedColumn)"
				$lastResort = if ($ForeignKeyValues) { $ForeignKeyValues[$refKey] } else { $null }
				if ($lastResort -and $lastResort.Count -gt 0) {
					$row[$col.ColumnName] = ($lastResort | Get-Random)
				}
				else {
					$msg = "Cannot resolve FK value for non-nullable column '$($col.ColumnName)' in '$($TableInfo.FullName)' (ref: $refKey). No parent values available."
					Write-PSFMessage -Level Warning -Message $msg
					Stop-PSFFunction -Message $msg -EnableException $true
				}
			}
		}
		if (-not $rowOK) { continue }

		[void]$dataTable.Rows.Add($row)
	}

	} # end try
	finally {
		$dataTable.EndLoadData()
	}

	# Store generated values for FK reference by child tables
	foreach ($col in $activeColumns) {
		if ($col.IsPrimaryKey -or $col.IsUnique) {
			$key = "$($TableInfo.SchemaName).$($TableInfo.TableName).$($col.ColumnName)"
			$valuesList = [System.Collections.Generic.List[object]]::new($dataTable.Rows.Count)
			foreach ($row in $dataTable.Rows) {
				if ($row[$col.ColumnName] -isnot [DBNull]) {
					$valuesList.Add($row[$col.ColumnName])
				}
			}
			$generatedValues[$key] = $valuesList.ToArray()
		}
	}

	[SqlLabDataGenerator.RowSet]@{
		TableInfo       = $TableInfo
		DataTable       = $dataTable
		RowCount        = $dataTable.Rows.Count
		GeneratedValues = $generatedValues
	}

	} catch {
		$dataTable.Dispose()
		throw
	}
}
