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

	foreach ($tableRow in $Tables.Rows) {
		$schemaName = [string]$tableRow.TABLE_SCHEMA
		$tableName = [string]$tableRow.TABLE_NAME

		# Apply filters in PowerShell (no SQL injection risk)
		if ($SchemaFilter -and $schemaName -notin $SchemaFilter) { continue }
		if ($TableFilter -and $tableName -notin $TableFilter) { continue }

		# Build column list for this table
		$tableColumns = [System.Collections.Generic.List[object]]::new()
		foreach ($colRow in $Columns.Rows) {
			if ([string]$colRow.TABLE_SCHEMA -ne $schemaName -or [string]$colRow.TABLE_NAME -ne $tableName) { continue }

			$colName = [string]$colRow.COLUMN_NAME

			# Check PK / Unique
			$isPK = $false
			$isUnique = $false
			foreach ($ucRow in $UniqueConstraints.Rows) {
				if ([string]$ucRow.SchemaName -eq $schemaName -and [string]$ucRow.TableName -eq $tableName -and [string]$ucRow.ColumnName -eq $colName) {
					if ($ucRow.IsPrimaryKey -eq $true -or $ucRow.IsPrimaryKey -eq 1) { $isPK = $true }
					if ($ucRow.IsUnique -eq $true -or $ucRow.IsUnique -eq 1) { $isUnique = $true }
				}
			}

			# Check FK reference
			$fkRef = $null
			foreach ($fkRow in $ForeignKeys.Rows) {
				if ([string]$fkRow.ParentSchema -eq $schemaName -and [string]$fkRow.ParentTable -eq $tableName -and [string]$fkRow.ParentColumn -eq $colName) {
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

			# Check constraints
			$checks = @()
			if ($CheckConstraints) {
				foreach ($ccRow in $CheckConstraints.Rows) {
					if ([string]$ccRow.SchemaName -eq $schemaName -and [string]$ccRow.TableName -eq $tableName -and [string]$ccRow.ColumnName -eq $colName) {
						$checks += [string]$ccRow.ConstraintDefinition
					}
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

		# Build FK list for this table
		$tableFKs = [System.Collections.Generic.List[object]]::new()
		foreach ($fkRow in $ForeignKeys.Rows) {
			if ([string]$fkRow.ParentSchema -eq $schemaName -and [string]$fkRow.ParentTable -eq $tableName) {
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
