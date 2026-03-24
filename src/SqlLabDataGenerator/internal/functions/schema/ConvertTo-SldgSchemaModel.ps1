function ConvertTo-SldgSchemaModel {
	<#
	.SYNOPSIS
		Converts raw database metadata into a normalized internal schema model.
	#>
	[CmdletBinding()]
	param (
		[Parameter(Mandatory)]
		$Tables,

		[Parameter(Mandatory)]
		$Columns,

		[Parameter(Mandatory)]
		$ForeignKeys,

		[Parameter(Mandatory)]
		$UniqueConstraints,

		$CheckConstraints,

		$ViewHints,

		[string[]]$SchemaFilter,

		[string[]]$TableFilter,

		[string]$Database
	)

	$tableList = [System.Collections.Generic.List[object]]::new()

	# Pre-index metadata by table key for O(1) lookups instead of O(n) per-table scans
	# Use @() to safely enumerate: works for both DataTable and DataRow array inputs
	$columnIndex = @{}
	foreach ($colRow in @($Columns)) {
		$key = "$([string]$colRow.TABLE_SCHEMA).$([string]$colRow.TABLE_NAME)"
		if (-not $columnIndex.ContainsKey($key)) { $columnIndex[$key] = [System.Collections.Generic.List[object]]::new() }
		$columnIndex[$key].Add($colRow)
	}
	$ucIndex = @{}
	foreach ($ucRow in @($UniqueConstraints)) {
		$key = "$([string]$ucRow.SchemaName).$([string]$ucRow.TableName).$([string]$ucRow.ColumnName)"
		if (-not $ucIndex.ContainsKey($key)) { $ucIndex[$key] = [System.Collections.Generic.List[object]]::new() }
		$ucIndex[$key].Add($ucRow)
	}
	$fkByParent = @{}
	foreach ($fkRow in @($ForeignKeys)) {
		$key = "$([string]$fkRow.ParentSchema).$([string]$fkRow.ParentTable)"
		if (-not $fkByParent.ContainsKey($key)) { $fkByParent[$key] = [System.Collections.Generic.List[object]]::new() }
		$fkByParent[$key].Add($fkRow)
	}
	$ccIndex = @{}
	if ($CheckConstraints) {
		foreach ($ccRow in @($CheckConstraints)) {
			$key = "$([string]$ccRow.SchemaName).$([string]$ccRow.TableName).$([string]$ccRow.ColumnName)"
			if (-not $ccIndex.ContainsKey($key)) { $ccIndex[$key] = [System.Collections.Generic.List[object]]::new() }
			$ccIndex[$key].Add($ccRow)
		}
	}
	$viewHintIndex = @{}
	# Pre-analyze view definitions to detect JSON/XML usage per table.column
	# Maps "schema.table.column" -> @{ ViewDefinitions = [...]; DetectedFormat = 'Json'|'Xml'|$null }
	$viewColumnHints = @{}
	if ($ViewHints) {
		foreach ($vhRow in @($ViewHints)) {
			$tableKey = "$([string]$vhRow.TableSchema).$([string]$vhRow.TableName)"
			$viewDef = [string]$vhRow.ViewDefinition
			if (-not $viewDef) { continue }

			# Collect all view definitions per table
			if (-not $viewHintIndex.ContainsKey($tableKey)) { $viewHintIndex[$tableKey] = [System.Collections.Generic.List[string]]::new() }
			$viewHintIndex[$tableKey].Add($viewDef)

			# Detect JSON parsing functions: JSON_VALUE(x.col, ...), OPENJSON(x.col), JSON_QUERY(x.col, ...), ISJSON(x.col)
			$jsonMatches = [regex]::Matches($viewDef, '(?:JSON_VALUE|JSON_QUERY|OPENJSON|ISJSON)\s*\(\s*(?:\w+\.)?\[?(\w+)\]?', 'IgnoreCase')
			foreach ($m in $jsonMatches) {
				$detectedCol = $m.Groups[1].Value
				$hintKey = "$tableKey.$detectedCol"
				if (-not $viewColumnHints.ContainsKey($hintKey)) {
					$viewColumnHints[$hintKey] = @{ ViewDefinitions = [System.Collections.Generic.List[string]]::new(); DetectedFormat = 'Json' }
				}
				if ($viewColumnHints[$hintKey].DetectedFormat -ne 'Json') { $viewColumnHints[$hintKey].DetectedFormat = 'Json' }
				if (-not $viewColumnHints[$hintKey].ViewDefinitions.Contains($viewDef)) {
					$viewColumnHints[$hintKey].ViewDefinitions.Add($viewDef)
				}
			}

			# Detect XML parsing: col.value(...), col.query(...), col.nodes(...), col.exist(...)
			$xmlMatches = [regex]::Matches($viewDef, '(?:\w+\.)?\[?(\w+)\]?\s*\.\s*(?:value|query|nodes|exist|modify)\s*\(', 'IgnoreCase')
			foreach ($m in $xmlMatches) {
				$detectedCol = $m.Groups[1].Value
				$hintKey = "$tableKey.$detectedCol"
				if (-not $viewColumnHints.ContainsKey($hintKey)) {
					$viewColumnHints[$hintKey] = @{ ViewDefinitions = [System.Collections.Generic.List[string]]::new(); DetectedFormat = 'Xml' }
				}
				if ($viewColumnHints[$hintKey].DetectedFormat -ne 'Xml') { $viewColumnHints[$hintKey].DetectedFormat = 'Xml' }
				if (-not $viewColumnHints[$hintKey].ViewDefinitions.Contains($viewDef)) {
					$viewColumnHints[$hintKey].ViewDefinitions.Add($viewDef)
				}
			}

			# Detect CAST/CONVERT to xml: CAST(col AS xml), CONVERT(xml, col)
			$castXmlMatches = [regex]::Matches($viewDef, 'CAST\s*\(\s*(?:\w+\.)?\[?(\w+)\]?\s+AS\s+xml\s*\)', 'IgnoreCase')
			foreach ($m in $castXmlMatches) {
				$detectedCol = $m.Groups[1].Value
				$hintKey = "$tableKey.$detectedCol"
				if (-not $viewColumnHints.ContainsKey($hintKey)) {
					$viewColumnHints[$hintKey] = @{ ViewDefinitions = [System.Collections.Generic.List[string]]::new(); DetectedFormat = 'Xml' }
				}
				if (-not $viewColumnHints[$hintKey].ViewDefinitions.Contains($viewDef)) {
					$viewColumnHints[$hintKey].ViewDefinitions.Add($viewDef)
				}
			}
		}
	}

	foreach ($tableRow in @($Tables)) {
		$schemaName = [string]$tableRow.TABLE_SCHEMA
		$tableName = [string]$tableRow.TABLE_NAME

		# Apply filters in PowerShell (no SQL injection risk)
		if ($SchemaFilter -and $schemaName -notin $SchemaFilter) { continue }
		if ($TableFilter -and $tableName -notin $TableFilter) { continue }

		# Build column list for this table
		$tableColumns = [System.Collections.Generic.List[object]]::new()
		$tableKey = "$schemaName.$tableName"
		$tableColRows = if ($columnIndex.ContainsKey($tableKey)) { $columnIndex[$tableKey] } else { @() }
		foreach ($colRow in $tableColRows) {

			$colName = [string]$colRow.COLUMN_NAME

			# Check PK / Unique via pre-built index
			$isPK = $false
			$isUnique = $false
			$ucKey = "$schemaName.$tableName.$colName"
			if ($ucIndex.ContainsKey($ucKey)) {
				foreach ($ucRow in $ucIndex[$ucKey]) {
					if ($ucRow.IsPrimaryKey -eq $true -or $ucRow.IsPrimaryKey -eq 1) { $isPK = $true }
					if ($ucRow.IsUnique -eq $true -or $ucRow.IsUnique -eq 1) { $isUnique = $true }
				}
			}

			# Check FK reference via pre-built index
			$fkRef = $null
			$tableFkRows = if ($fkByParent.ContainsKey($tableKey)) { $fkByParent[$tableKey] } else { @() }
			foreach ($fkRow in $tableFkRows) {
				if ([string]$fkRow.ParentColumn -eq $colName) {
					$fkRef = [SqlLabDataGenerator.ForeignKeyRef]@{
						ForeignKeyName   = [string]$fkRow.ForeignKeyName
						ReferencedSchema = [string]$fkRow.ReferencedSchema
						ReferencedTable  = [string]$fkRow.ReferencedTable
						ReferencedColumn = [string]$fkRow.ReferencedColumn
					}
					break
				}
			}

			# Check constraints via pre-built index
			$checks = @()
			$ccKey = "$schemaName.$tableName.$colName"
			if ($ccIndex.ContainsKey($ccKey)) {
				foreach ($ccRow in $ccIndex[$ccKey]) {
					$checks += [string]$ccRow.ConstraintDefinition
				}
			}

			# Detect structured data columns via view analysis and data type
			$schemaHint = $null
			$viewDetectedFormat = $null
			$colDataType = ([string]$colRow.DATA_TYPE).ToLower()
			$hintKey = "$tableKey.$colName"

			# 1. Check if any view actively parses this column as JSON/XML
			if ($viewColumnHints.ContainsKey($hintKey)) {
				$hint = $viewColumnHints[$hintKey]
				$viewDetectedFormat = $hint.DetectedFormat
				$schemaHint = ($hint.ViewDefinitions | Select-Object -First 3) -join "`n---`n"
			}
			# 2. For xml-typed or nvarchar(max) columns, also attach any view that mentions the column
			elseif ($colDataType -eq 'xml' -or ($colDataType -in @('nvarchar', 'varchar', 'ntext', 'text') -and ($colRow.CHARACTER_MAXIMUM_LENGTH -is [DBNull] -or $colRow.CHARACTER_MAXIMUM_LENGTH -eq -1))) {
				if ($viewHintIndex.ContainsKey($tableKey)) {
					$escapedCol = [regex]::Escape($colName)
					$relevantViews = $viewHintIndex[$tableKey] | Where-Object { $_ -match $escapedCol }
					if ($relevantViews) {
						$schemaHint = ($relevantViews | Select-Object -First 3) -join "`n---`n"
					}
				}
			}

			$column = [SqlLabDataGenerator.ColumnInfo]@{
				ColumnName         = $colName
				DataType           = [string]$colRow.DATA_TYPE
				MaxLength          = if ($colRow.CHARACTER_MAXIMUM_LENGTH -is [DBNull]) { $null } else { $colRow.CHARACTER_MAXIMUM_LENGTH }
				NumericPrecision   = if ($colRow.NUMERIC_PRECISION -is [DBNull]) { $null } else { $colRow.NUMERIC_PRECISION }
				NumericScale       = if ($colRow.NUMERIC_SCALE -is [DBNull]) { $null } else { $colRow.NUMERIC_SCALE }
				IsNullable         = $colRow.IS_NULLABLE -eq 'YES'
				DefaultValue       = if ($colRow.COLUMN_DEFAULT -is [DBNull]) { $null } else { [string]$colRow.COLUMN_DEFAULT }
				OrdinalPosition    = [int]$colRow.ORDINAL_POSITION
				IsIdentity         = [bool]($colRow.IsIdentity -eq 1)
				IsComputed         = [bool]($colRow.IsComputed -eq 1)
				IsPrimaryKey       = $isPK
				IsUnique           = $isUnique
				ForeignKey         = $fkRef
				CheckConstraints   = $checks
				SchemaHint         = $schemaHint
				ViewDetectedFormat = $viewDetectedFormat
				SemanticType       = $null
				Classification     = $null
				GenerationRule     = $null
			}
			$tableColumns.Add($column)
		}

		# Build FK list for this table from pre-built index
		$tableFKs = [System.Collections.Generic.List[object]]::new()
		$fkRowsForTable = if ($fkByParent.ContainsKey($tableKey)) { $fkByParent[$tableKey] } else { @() }
		foreach ($fkRow in $fkRowsForTable) {
			$tableFKs.Add([SqlLabDataGenerator.ForeignKeyInfo]@{
						ForeignKeyName   = [string]$fkRow.ForeignKeyName
						ParentSchema     = [string]$fkRow.ParentSchema
						ParentTable      = [string]$fkRow.ParentTable
						ParentColumn     = [string]$fkRow.ParentColumn
						ReferencedSchema = [string]$fkRow.ReferencedSchema
						ReferencedTable  = [string]$fkRow.ReferencedTable
						ReferencedColumn = [string]$fkRow.ReferencedColumn
					})
		}

		$table = [SqlLabDataGenerator.TableInfo]@{
			SchemaName  = $schemaName
			TableName   = $tableName
			FullName    = "$schemaName.$tableName"
			Columns     = $tableColumns.ToArray()
			ForeignKeys = $tableFKs.ToArray()
			ColumnCount = $tableColumns.Count
		}
		$tableList.Add($table)
	}

	[SqlLabDataGenerator.SchemaModel]@{
		Database     = $Database
		Tables       = $tableList.ToArray()
		TableCount   = $tableList.Count
		DiscoveredAt = Get-Date
	}
}
