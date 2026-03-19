Describe "ConvertTo-SldgSchemaModel" {
	BeforeAll {
		Remove-Module SqlLabDataGenerator -ErrorAction Ignore
		Import-Module "$PSScriptRoot\..\..\..\..\SqlLabDataGenerator\SqlLabDataGenerator.psd1" -Force
		$module = Get-Module SqlLabDataGenerator

		# Helper to create DataTable from rows
		function New-TestDataTable {
			param([string[]]$ColumnNames, [object[][]]$Rows)
			$dt = [System.Data.DataTable]::new()
			foreach ($name in $ColumnNames) { $null = $dt.Columns.Add($name) }
			foreach ($row in $Rows) { $null = $dt.Rows.Add($row) }
			, $dt
		}
	}

	Context "Basic Schema Conversion" {
		BeforeAll {
			$tables = New-TestDataTable -ColumnNames @('TABLE_SCHEMA', 'TABLE_NAME') -Rows @(
				, @('dbo', 'Customer')
				, @('dbo', 'Order')
			)

			$columns = [System.Data.DataTable]::new()
			$null = $columns.Columns.Add('TABLE_SCHEMA', [string])
			$null = $columns.Columns.Add('TABLE_NAME', [string])
			$null = $columns.Columns.Add('COLUMN_NAME', [string])
			$null = $columns.Columns.Add('DATA_TYPE', [string])
			$null = $columns.Columns.Add('CHARACTER_MAXIMUM_LENGTH', [object])
			$null = $columns.Columns.Add('NUMERIC_PRECISION', [object])
			$null = $columns.Columns.Add('NUMERIC_SCALE', [object])
			$null = $columns.Columns.Add('IS_NULLABLE', [string])
			$null = $columns.Columns.Add('COLUMN_DEFAULT', [object])
			$null = $columns.Columns.Add('ORDINAL_POSITION', [int])
			$null = $columns.Columns.Add('IsIdentity', [int])
			$null = $columns.Columns.Add('IsComputed', [int])

			$null = $columns.Rows.Add('dbo', 'Customer', 'Id', 'int', [DBNull]::Value, [DBNull]::Value, [DBNull]::Value, 'NO', [DBNull]::Value, 1, 1, 0)
			$null = $columns.Rows.Add('dbo', 'Customer', 'FirstName', 'nvarchar', 50, [DBNull]::Value, [DBNull]::Value, 'NO', [DBNull]::Value, 2, 0, 0)
			$null = $columns.Rows.Add('dbo', 'Customer', 'Email', 'nvarchar', 100, [DBNull]::Value, [DBNull]::Value, 'YES', [DBNull]::Value, 3, 0, 0)
			$null = $columns.Rows.Add('dbo', 'Order', 'Id', 'int', [DBNull]::Value, [DBNull]::Value, [DBNull]::Value, 'NO', [DBNull]::Value, 1, 1, 0)
			$null = $columns.Rows.Add('dbo', 'Order', 'CustomerId', 'int', [DBNull]::Value, [DBNull]::Value, [DBNull]::Value, 'NO', [DBNull]::Value, 2, 0, 0)
			$null = $columns.Rows.Add('dbo', 'Order', 'Total', 'decimal', [DBNull]::Value, 18, 2, 'NO', [DBNull]::Value, 3, 0, 0)

			$fks = [System.Data.DataTable]::new()
			$null = $fks.Columns.Add('ForeignKeyName', [string])
			$null = $fks.Columns.Add('ParentSchema', [string])
			$null = $fks.Columns.Add('ParentTable', [string])
			$null = $fks.Columns.Add('ParentColumn', [string])
			$null = $fks.Columns.Add('ReferencedSchema', [string])
			$null = $fks.Columns.Add('ReferencedTable', [string])
			$null = $fks.Columns.Add('ReferencedColumn', [string])
			$null = $fks.Rows.Add('FK_Order_Customer', 'dbo', 'Order', 'CustomerId', 'dbo', 'Customer', 'Id')

			$uniques = [System.Data.DataTable]::new()
			$null = $uniques.Columns.Add('SchemaName', [string])
			$null = $uniques.Columns.Add('TableName', [string])
			$null = $uniques.Columns.Add('ColumnName', [string])
			$null = $uniques.Columns.Add('IsPrimaryKey', [bool])
			$null = $uniques.Columns.Add('IsUnique', [bool])
			$null = $uniques.Rows.Add('dbo', 'Customer', 'Id', $true, $true)
			$null = $uniques.Rows.Add('dbo', 'Order', 'Id', $true, $true)

			$checks = [System.Data.DataTable]::new()
			$null = $checks.Columns.Add('SchemaName', [string])
			$null = $checks.Columns.Add('TableName', [string])
			$null = $checks.Columns.Add('ColumnName', [string])
			$null = $checks.Columns.Add('ConstraintDefinition', [string])

			$script:schema = & $module {
				param($t, $c, $f, $u, $ch)
				ConvertTo-SldgSchemaModel -Tables $t -Columns $c -ForeignKeys $f -UniqueConstraints $u -CheckConstraints $ch -Database 'TestDB'
			} $tables $columns $fks $uniques $checks
		}

		It "Returns SchemaModel typed object" {
			$schema.PSObject.TypeNames | Should -Contain 'SqlLabDataGenerator.SchemaModel'
		}

		It "Has correct database name" {
			$schema.Database | Should -Be 'TestDB'
		}

		It "Discovers 2 tables" {
			$schema.TableCount | Should -Be 2
		}

		It "Customer table has 3 columns" {
			$custTable = $schema.Tables | Where-Object { $_.TableName -eq 'Customer' }
			$custTable.ColumnCount | Should -Be 3
		}

		It "Customer.Id is PK and Identity" {
			$custTable = $schema.Tables | Where-Object { $_.TableName -eq 'Customer' }
			$idCol = $custTable.Columns | Where-Object { $_.ColumnName -eq 'Id' }
			$idCol.IsPrimaryKey | Should -BeTrue
			$idCol.IsIdentity | Should -BeTrue
		}

		It "Customer.Email is nullable" {
			$custTable = $schema.Tables | Where-Object { $_.TableName -eq 'Customer' }
			$emailCol = $custTable.Columns | Where-Object { $_.ColumnName -eq 'Email' }
			$emailCol.IsNullable | Should -BeTrue
		}

		It "Order.CustomerId has FK to Customer.Id" {
			$orderTable = $schema.Tables | Where-Object { $_.TableName -eq 'Order' }
			$custIdCol = $orderTable.Columns | Where-Object { $_.ColumnName -eq 'CustomerId' }
			$custIdCol.ForeignKey | Should -Not -BeNullOrEmpty
			$custIdCol.ForeignKey.ReferencedTable | Should -Be 'Customer'
			$custIdCol.ForeignKey.ReferencedColumn | Should -Be 'Id'
		}

		It "Order table has FK info" {
			$orderTable = $schema.Tables | Where-Object { $_.TableName -eq 'Order' }
			$orderTable.ForeignKeys.Count | Should -Be 1
			$orderTable.ForeignKeys[0].ReferencedTable | Should -Be 'Customer'
		}
	}

	Context "Schema Filtering" {
		It "Filters by schema name" {
			$tables = New-TestDataTable -ColumnNames @('TABLE_SCHEMA', 'TABLE_NAME') -Rows @(
				, @('dbo', 'Table1')
				, @('sales', 'Table2')
			)
			$columns = [System.Data.DataTable]::new()
			$null = $columns.Columns.Add('TABLE_SCHEMA', [string])
			$null = $columns.Columns.Add('TABLE_NAME', [string])
			$null = $columns.Columns.Add('COLUMN_NAME', [string])
			$null = $columns.Columns.Add('DATA_TYPE', [string])
			$null = $columns.Columns.Add('CHARACTER_MAXIMUM_LENGTH', [object])
			$null = $columns.Columns.Add('NUMERIC_PRECISION', [object])
			$null = $columns.Columns.Add('NUMERIC_SCALE', [object])
			$null = $columns.Columns.Add('IS_NULLABLE', [string])
			$null = $columns.Columns.Add('COLUMN_DEFAULT', [object])
			$null = $columns.Columns.Add('ORDINAL_POSITION', [int])
			$null = $columns.Columns.Add('IsIdentity', [int])
			$null = $columns.Columns.Add('IsComputed', [int])
			$null = $columns.Rows.Add('dbo', 'Table1', 'Id', 'int', [DBNull]::Value, [DBNull]::Value, [DBNull]::Value, 'NO', [DBNull]::Value, 1, 0, 0)
			$null = $columns.Rows.Add('sales', 'Table2', 'Id', 'int', [DBNull]::Value, [DBNull]::Value, [DBNull]::Value, 'NO', [DBNull]::Value, 1, 0, 0)

			$emptyFks = [System.Data.DataTable]::new()
			foreach ($cn in @('ForeignKeyName', 'ParentSchema', 'ParentTable', 'ParentColumn', 'ReferencedSchema', 'ReferencedTable', 'ReferencedColumn')) { $null = $emptyFks.Columns.Add($cn, [string]) }
			$emptyUc = [System.Data.DataTable]::new()
			foreach ($cn in @('SchemaName', 'TableName', 'ColumnName')) { $null = $emptyUc.Columns.Add($cn, [string]) }
			$null = $emptyUc.Columns.Add('IsPrimaryKey', [bool])
			$null = $emptyUc.Columns.Add('IsUnique', [bool])

			$result = & $module {
				param($t, $c, $f, $u)
				ConvertTo-SldgSchemaModel -Tables $t -Columns $c -ForeignKeys $f -UniqueConstraints $u -Database 'TestDB' -SchemaFilter @('dbo')
			} $tables $columns $emptyFks $emptyUc

			$result.TableCount | Should -Be 1
			$result.Tables[0].SchemaName | Should -Be 'dbo'
		}
	}
}
