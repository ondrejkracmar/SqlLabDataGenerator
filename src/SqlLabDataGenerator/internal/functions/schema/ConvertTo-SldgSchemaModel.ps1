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

		[string[]]$SchemaFilter,

		[string[]]$TableFilter,

		[string]$Database
	)

	$tableList = [System.Collections.Generic.List[object]]::new()

	# Pre-index metadata by table key for O(1) lookups instead of O(n) per-table scans
	$columnIndex = @{}
	foreach ($colRow in $Columns.Rows) {
		$key = "$([string]$colRow.TABLE_SCHEMA).$([string]$colRow.TABLE_NAME)"
		if (-not $columnIndex.ContainsKey($key)) { $columnIndex[$key] = [System.Collections.Generic.List[object]]::new() }
		$columnIndex[$key].Add($colRow)
	}
	$ucIndex = @{}
	foreach ($ucRow in $UniqueConstraints.Rows) {
		$key = "$([string]$ucRow.SchemaName).$([string]$ucRow.TableName).$([string]$ucRow.ColumnName)"
		if (-not $ucIndex.ContainsKey($key)) { $ucIndex[$key] = [System.Collections.Generic.List[object]]::new() }
		$ucIndex[$key].Add($ucRow)
	}
	$fkByParent = @{}
	foreach ($fkRow in $ForeignKeys.Rows) {
		$key = "$([string]$fkRow.ParentSchema).$([string]$fkRow.ParentTable)"
		if (-not $fkByParent.ContainsKey($key)) { $fkByParent[$key] = [System.Collections.Generic.List[object]]::new() }
		$fkByParent[$key].Add($fkRow)
	}
	$ccIndex = @{}
	if ($CheckConstraints) {
		foreach ($ccRow in $CheckConstraints.Rows) {
			$key = "$([string]$ccRow.SchemaName).$([string]$ccRow.TableName).$([string]$ccRow.ColumnName)"
			if (-not $ccIndex.ContainsKey($key)) { $ccIndex[$key] = [System.Collections.Generic.List[object]]::new() }
			$ccIndex[$key].Add($ccRow)
		}
	}

	foreach ($tableRow in $Tables.Rows) {
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
					$fkRef = [PSCustomObject]@{
						PSTypeName       = 'SqlLabDataGenerator.ForeignKeyRef'
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

			$column = [PSCustomObject]@{
				PSTypeName       = 'SqlLabDataGenerator.ColumnInfo'
				ColumnName       = $colName
				DataType         = [string]$colRow.DATA_TYPE
				MaxLength        = if ($colRow.CHARACTER_MAXIMUM_LENGTH -is [DBNull]) { $null } else { $colRow.CHARACTER_MAXIMUM_LENGTH }
				NumericPrecision = if ($colRow.NUMERIC_PRECISION -is [DBNull]) { $null } else { $colRow.NUMERIC_PRECISION }
				NumericScale     = if ($colRow.NUMERIC_SCALE -is [DBNull]) { $null } else { $colRow.NUMERIC_SCALE }
				IsNullable       = $colRow.IS_NULLABLE -eq 'YES'
				DefaultValue     = if ($colRow.COLUMN_DEFAULT -is [DBNull]) { $null } else { [string]$colRow.COLUMN_DEFAULT }
				OrdinalPosition  = [int]$colRow.ORDINAL_POSITION
				IsIdentity       = [bool]($colRow.IsIdentity -eq 1)
				IsComputed       = [bool]($colRow.IsComputed -eq 1)
				IsPrimaryKey     = $isPK
				IsUnique         = $isUnique
				ForeignKey       = $fkRef
				CheckConstraints = $checks
				SemanticType     = $null
				Classification   = $null
				GenerationRule   = $null
			}
			$tableColumns.Add($column)
		}

		# Build FK list for this table from pre-built index
		$tableFKs = [System.Collections.Generic.List[object]]::new()
		$fkRowsForTable = if ($fkByParent.ContainsKey($tableKey)) { $fkByParent[$tableKey] } else { @() }
		foreach ($fkRow in $fkRowsForTable) {
			$tableFKs.Add([PSCustomObject]@{
						PSTypeName       = 'SqlLabDataGenerator.ForeignKeyInfo'
						ForeignKeyName   = [string]$fkRow.ForeignKeyName
						ParentSchema     = [string]$fkRow.ParentSchema
						ParentTable      = [string]$fkRow.ParentTable
						ParentColumn     = [string]$fkRow.ParentColumn
						ReferencedSchema = [string]$fkRow.ReferencedSchema
						ReferencedTable  = [string]$fkRow.ReferencedTable
						ReferencedColumn = [string]$fkRow.ReferencedColumn
					})
		}

		$table = [PSCustomObject]@{
			PSTypeName  = 'SqlLabDataGenerator.TableInfo'
			SchemaName  = $schemaName
			TableName   = $tableName
			FullName    = "$schemaName.$tableName"
			Columns     = $tableColumns.ToArray()
			ForeignKeys = $tableFKs.ToArray()
			ColumnCount = $tableColumns.Count
		}
		$tableList.Add($table)
	}

	[PSCustomObject]@{
		PSTypeName   = 'SqlLabDataGenerator.SchemaModel'
		Database     = $Database
		Tables       = $tableList.ToArray()
		TableCount   = $tableList.Count
		DiscoveredAt = Get-Date
	}
}
