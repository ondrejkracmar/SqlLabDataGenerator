Describe "Get-SldgSafeSqlName" {
	BeforeAll {
		Remove-Module SqlLabDataGenerator -ErrorAction Ignore
		Import-Module "$PSScriptRoot\..\..\..\..\SqlLabDataGenerator\SqlLabDataGenerator.psd1" -Force
		$module = Get-Module SqlLabDataGenerator
	}

	Context "Column Name Only" {
		It "Escapes a simple column name" {
			$result = & $module { Get-SldgSafeSqlName -ColumnName 'MyColumn' }
			$result | Should -Be '[MyColumn]'
		}

		It "Escapes closing brackets in column name" {
			$result = & $module { Get-SldgSafeSqlName -ColumnName 'Col]Name' }
			$result | Should -Be '[Col]]Name]'
		}

		It "Handles column name with spaces" {
			$result = & $module { Get-SldgSafeSqlName -ColumnName 'First Name' }
			$result | Should -Be '[First Name]'
		}
	}

	Context "Schema and Table" {
		It "Returns [schema].[table] for SQL Server" {
			$result = & $module { Get-SldgSafeSqlName -SchemaName 'dbo' -TableName 'Users' }
			$result | Should -Be '[dbo].[Users]'
		}

		It "Escapes brackets in schema and table names" {
			$result = & $module { Get-SldgSafeSqlName -SchemaName 'my]schema' -TableName 'my]table' }
			$result | Should -Be '[my]]schema].[my]]table]'
		}

		It "Returns [table] only when no schema provided" {
			$result = & $module { Get-SldgSafeSqlName -TableName 'Products' }
			$result | Should -Be '[Products]'
		}
	}

	Context "SQLite Mode" {
		It "Returns [table] without schema in SQLite mode" {
			$result = & $module { Get-SldgSafeSqlName -SchemaName 'main' -TableName 'Users' -SQLite }
			$result | Should -Be '[Users]'
		}

		It "Escapes brackets in SQLite table name" {
			$result = & $module { Get-SldgSafeSqlName -TableName 'My]Table' -SQLite }
			$result | Should -Be '[My]]Table]'
		}
	}

	Context "Edge Cases" {
		It "Handles empty column name" {
			$result = & $module { Get-SldgSafeSqlName -ColumnName '' }
			$result | Should -Be '[]'
		}

		It "Column-only mode ignores TableName when ColumnName is provided without TableName" {
			$result = & $module { Get-SldgSafeSqlName -ColumnName 'Col1' }
			$result | Should -Be '[Col1]'
		}
	}
}
