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

		[hashtable]$SharedUniqueTracker
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
	$pkAutoIncrements = @{}
	foreach ($col in $activeColumns) {
		if ($col.IsPrimaryKey -and -not $col.IsIdentity -and $null -ne $col.PKStartValue -and $col.DataType -match '^(int|bigint|smallint|tinyint)$') {
			$pkAutoIncrements[$col.ColumnName] = [long]$col.PKStartValue
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
				$uniqueTracker[$col.ColumnName] = [System.Collections.Generic.HashSet[string]]::new()
			}
		}
		if ($hasCompositePK) {
			$uniqueTracker['__CompositePK__'] = [System.Collections.Generic.HashSet[string]]::new()
		}
	}

	# Reorder: columns with cross-column dependencies go after their dependency columns
	$dependentCols = @()
	$independentCols = @()
	foreach ($col in $activeColumns) {
		$depCol = $null
		if ($TableRules -and $TableRules.ContainsKey($col.ColumnName) -and $TableRules[$col.ColumnName].CrossColumnDependency) {
			$depCol = $TableRules[$col.ColumnName].CrossColumnDependency
		}
		elseif ($col.CustomRule -is [hashtable] -and $col.CustomRule.CrossColumnDependency) {
			$depCol = $col.CustomRule.CrossColumnDependency
		}
		if ($depCol) { $dependentCols += $col } else { $independentCols += $col }
	}
	if ($dependentCols.Count -gt 0) {
		$activeColumns = @($independentCols) + @($dependentCols)
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
			$aiBatch = New-SldgAIGeneratedBatch -Columns $aiCandidates -TableName $TableInfo.FullName -BatchSize $RowCount -Locale $locale
		}
	}

	# Generate rows
	$generatedValues = @{}
	$aiBatchIndex = 0

	for ($rowIdx = 0; $rowIdx -lt $RowCount; $rowIdx++) {
		$row = $dataTable.NewRow()
		$retryCount = 0
		$rowValid = $false

		while (-not $rowValid -and $retryCount -lt $maxUniqueRetries) {
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

				# Fall back to standard generator
				if ($null -eq $value) {
					$value = New-SldgGeneratedValue -Column $col -GeneratorMap $GeneratorMap -ForeignKeyValues $ForeignKeyValues -CustomRule $customRule -NullProbability $cachedNullProbability -RowContext $rowContext
				}

				# Convert string "null" from AI to actual DBNull
				if ($value -is [string] -and $value -eq 'null') { $value = [DBNull]::Value }

				if ($null -eq $value) { continue }

				# Enforce uniqueness
				if ($uniqueTracker.ContainsKey($col.ColumnName)) {
					$valueStr = [string]$value
					if ($uniqueTracker[$col.ColumnName].Contains($valueStr)) {
						$rowValid = $false
						$retryCount++
						break
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
					# Clamp numeric values to valid SQL type ranges (AI can generate out-of-range values)
					switch ($col.DataType.ToLower()) {
						'tinyint' { $value = [Math]::Max(0, [Math]::Min(255, [int]$value)) }
						'smallint' { $value = [Math]::Max(-32768, [Math]::Min(32767, [int]$value)) }
						'int' { $value = [Math]::Max(-2147483648, [Math]::Min(2147483647, [long]$value)) }
					}
					# Truncate strings exceeding MaxLength
					if ($col.MaxLength -and $col.MaxLength -gt 0 -and $value -is [string] -and $value.Length -gt $col.MaxLength) {
						$value = $value.Substring(0, $col.MaxLength)
					}
					# Unwrap PSObject to raw .NET type for DataTable compatibility
					$row[$col.ColumnName] = $value.psobject.BaseObject
				}

				# Track generated value for cross-column dependency context
				$rowContext[$col.ColumnName] = $value
			}

			if ($rowValid -and $hasCompositePK) {
				# Enforce composite PK uniqueness
				$compositeKey = ($pkColumns | ForEach-Object { [string]$row[$_.ColumnName] }) -join '|'
				if ($uniqueTracker['__CompositePK__'].Contains($compositeKey)) {
					$rowValid = $false
					$retryCount++
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
					$compositeKey = ($pkColumns | ForEach-Object { [string]$row[$_.ColumnName] }) -join '|'
					[void]$uniqueTracker['__CompositePK__'].Add($compositeKey)
				}
				$aiBatchIndex++
			}
		}

		[void]$dataTable.Rows.Add($row)
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
