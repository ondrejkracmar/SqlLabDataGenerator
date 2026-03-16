Describe "Resolve-SldgForeignKeyOrder" {
	BeforeAll {
		Remove-Module SqlLabDataGenerator -ErrorAction Ignore
		Import-Module "$PSScriptRoot\..\..\..\..\SqlLabDataGenerator\SqlLabDataGenerator.psd1" -Force
		$module = Get-Module SqlLabDataGenerator
	}

	Context "Simple Linear Dependencies" {
		It "Orders parent before child" {
			$tables = @(
				[PSCustomObject]@{ FullName = 'dbo.Child'; ForeignKeys = @([PSCustomObject]@{ ReferencedSchema = 'dbo'; ReferencedTable = 'Parent' }) }
				[PSCustomObject]@{ FullName = 'dbo.Parent'; ForeignKeys = @() }
			)
			$result = & $module { param($t) Resolve-SldgForeignKeyOrder -Tables $t } $tables
			$result[0].FullName | Should -Be 'dbo.Parent'
			$result[1].FullName | Should -Be 'dbo.Child'
		}

		It "Orders three-level hierarchy correctly" {
			$tables = @(
				[PSCustomObject]@{ FullName = 'dbo.GrandChild'; ForeignKeys = @([PSCustomObject]@{ ReferencedSchema = 'dbo'; ReferencedTable = 'Child' }) }
				[PSCustomObject]@{ FullName = 'dbo.Parent'; ForeignKeys = @() }
				[PSCustomObject]@{ FullName = 'dbo.Child'; ForeignKeys = @([PSCustomObject]@{ ReferencedSchema = 'dbo'; ReferencedTable = 'Parent' }) }
			)
			$result = & $module { param($t) Resolve-SldgForeignKeyOrder -Tables $t } $tables
			$parentIdx = [Array]::IndexOf($result.FullName, 'dbo.Parent')
			$childIdx = [Array]::IndexOf($result.FullName, 'dbo.Child')
			$grandIdx = [Array]::IndexOf($result.FullName, 'dbo.GrandChild')
			$parentIdx | Should -BeLessThan $childIdx
			$childIdx | Should -BeLessThan $grandIdx
		}
	}

	Context "No Dependencies" {
		It "Returns all tables for independent tables" {
			$tables = @(
				[PSCustomObject]@{ FullName = 'dbo.A'; ForeignKeys = @() }
				[PSCustomObject]@{ FullName = 'dbo.B'; ForeignKeys = @() }
				[PSCustomObject]@{ FullName = 'dbo.C'; ForeignKeys = @() }
			)
			$result = & $module { param($t) Resolve-SldgForeignKeyOrder -Tables $t } $tables
			$result.Count | Should -Be 3
		}
	}

	Context "Self-Referencing FK" {
		It "Ignores self-referencing foreign keys" {
			$tables = @(
				[PSCustomObject]@{ FullName = 'dbo.Category'; ForeignKeys = @([PSCustomObject]@{ ReferencedSchema = 'dbo'; ReferencedTable = 'Category' }) }
				[PSCustomObject]@{ FullName = 'dbo.Product'; ForeignKeys = @([PSCustomObject]@{ ReferencedSchema = 'dbo'; ReferencedTable = 'Category' }) }
			)
			$result = & $module { param($t) Resolve-SldgForeignKeyOrder -Tables $t } $tables
			$catIdx = [Array]::IndexOf($result.FullName, 'dbo.Category')
			$prodIdx = [Array]::IndexOf($result.FullName, 'dbo.Product')
			$catIdx | Should -BeLessThan $prodIdx
		}
	}

	Context "Multiple Dependencies" {
		It "Handles table with two FK dependencies" {
			$tables = @(
				[PSCustomObject]@{
					FullName    = 'dbo.OrderItem'
					ForeignKeys = @(
						[PSCustomObject]@{ ReferencedSchema = 'dbo'; ReferencedTable = 'Order' }
						[PSCustomObject]@{ ReferencedSchema = 'dbo'; ReferencedTable = 'Product' }
					)
				}
				[PSCustomObject]@{ FullName = 'dbo.Order'; ForeignKeys = @() }
				[PSCustomObject]@{ FullName = 'dbo.Product'; ForeignKeys = @() }
			)
			$result = & $module { param($t) Resolve-SldgForeignKeyOrder -Tables $t } $tables
			$orderIdx = [Array]::IndexOf($result.FullName, 'dbo.Order')
			$productIdx = [Array]::IndexOf($result.FullName, 'dbo.Product')
			$oiIdx = [Array]::IndexOf($result.FullName, 'dbo.OrderItem')
			$oiIdx | Should -BeGreaterThan $orderIdx
			$oiIdx | Should -BeGreaterThan $productIdx
		}
	}

	Context "External FK Reference" {
		It "Ignores FK to table not in the set" {
			$tables = @(
				[PSCustomObject]@{ FullName = 'dbo.Order'; ForeignKeys = @([PSCustomObject]@{ ReferencedSchema = 'dbo'; ReferencedTable = 'ExternalTable' }) }
			)
			$result = & $module { param($t) Resolve-SldgForeignKeyOrder -Tables $t } $tables
			$result.Count | Should -Be 1
			$result[0].FullName | Should -Be 'dbo.Order'
		}
	}
}
