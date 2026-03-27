Describe "Group-SldgTablesByLevel" {
	BeforeAll {
		Remove-Module SqlLabDataGenerator -ErrorAction Ignore
		Import-Module "$PSScriptRoot\..\..\..\..\SqlLabDataGenerator\SqlLabDataGenerator.psd1" -Force
		$module = Get-Module SqlLabDataGenerator
	}

	Context "Basic Level Assignment" {
		It "Assigns level 0 to tables with no FK dependencies" {
			$tables = @(
				[PSCustomObject]@{ FullName = 'dbo.Category'; ForeignKeys = @() }
				[PSCustomObject]@{ FullName = 'dbo.Status'; ForeignKeys = @() }
			)
			$result = & $module { param($t) Group-SldgTablesByLevel -Tables $t } $tables
			$result.Count | Should -Be 1
			$result[0].Level | Should -Be 0
			$result[0].Tables.Count | Should -Be 2
		}

		It "Assigns level 1 to tables that depend on level 0 tables" {
			$tables = @(
				[PSCustomObject]@{ FullName = 'dbo.Category'; ForeignKeys = @() }
				[PSCustomObject]@{
					FullName    = 'dbo.Product'
					ForeignKeys = @([PSCustomObject]@{ ReferencedSchema = 'dbo'; ReferencedTable = 'Category' })
				}
			)
			$result = & $module { param($t) Group-SldgTablesByLevel -Tables $t } $tables
			$result.Count | Should -Be 2
			$result[0].Level | Should -Be 0
			$result[0].Tables[0].FullName | Should -Be 'dbo.Category'
			$result[1].Level | Should -Be 1
			$result[1].Tables[0].FullName | Should -Be 'dbo.Product'
		}

		It "Creates 3 levels for a chain of dependencies" {
			$tables = @(
				[PSCustomObject]@{ FullName = 'dbo.A'; ForeignKeys = @() }
				[PSCustomObject]@{
					FullName    = 'dbo.B'
					ForeignKeys = @([PSCustomObject]@{ ReferencedSchema = 'dbo'; ReferencedTable = 'A' })
				}
				[PSCustomObject]@{
					FullName    = 'dbo.C'
					ForeignKeys = @([PSCustomObject]@{ ReferencedSchema = 'dbo'; ReferencedTable = 'B' })
				}
			)
			$result = & $module { param($t) Group-SldgTablesByLevel -Tables $t } $tables
			$result.Count | Should -Be 3
			$result[0].Tables[0].FullName | Should -Be 'dbo.A'
			$result[1].Tables[0].FullName | Should -Be 'dbo.B'
			$result[2].Tables[0].FullName | Should -Be 'dbo.C'
		}
	}

	Context "Self-Referencing FK" {
		It "Ignores self-referencing FKs and assigns level 0" {
			$tables = @(
				[PSCustomObject]@{
					FullName    = 'dbo.Employee'
					ForeignKeys = @([PSCustomObject]@{ ReferencedSchema = 'dbo'; ReferencedTable = 'Employee' })
				}
			)
			$result = & $module { param($t) Group-SldgTablesByLevel -Tables $t } $tables
			$result.Count | Should -Be 1
			$result[0].Level | Should -Be 0
		}
	}

	Context "Circular FK Safety (F1 fix)" {
		It "Does not infinite-loop on mutual circular dependencies" {
			$tables = @(
				[PSCustomObject]@{
					FullName    = 'dbo.TableA'
					ForeignKeys = @([PSCustomObject]@{ ReferencedSchema = 'dbo'; ReferencedTable = 'TableB' })
				}
				[PSCustomObject]@{
					FullName    = 'dbo.TableB'
					ForeignKeys = @([PSCustomObject]@{ ReferencedSchema = 'dbo'; ReferencedTable = 'TableA' })
				}
			)
			# Should complete without hanging; maxIterations safety limit kicks in
			$result = & $module { param($t) Group-SldgTablesByLevel -Tables $t } $tables
			$result | Should -Not -BeNullOrEmpty
			$result.Count | Should -BeGreaterOrEqual 1
		}

		It "Completes in bounded time for 3-way cycle" {
			$tables = @(
				[PSCustomObject]@{
					FullName    = 'dbo.X'
					ForeignKeys = @([PSCustomObject]@{ ReferencedSchema = 'dbo'; ReferencedTable = 'Z' })
				}
				[PSCustomObject]@{
					FullName    = 'dbo.Y'
					ForeignKeys = @([PSCustomObject]@{ ReferencedSchema = 'dbo'; ReferencedTable = 'X' })
				}
				[PSCustomObject]@{
					FullName    = 'dbo.Z'
					ForeignKeys = @([PSCustomObject]@{ ReferencedSchema = 'dbo'; ReferencedTable = 'Y' })
				}
			)
			$result = & $module { param($t) Group-SldgTablesByLevel -Tables $t } $tables
			$result | Should -Not -BeNullOrEmpty
		}
	}

	Context "Multiple Independent Tables" {
		It "Groups multiple independent tables at level 0" {
			$tables = @(
				[PSCustomObject]@{ FullName = 'dbo.A'; ForeignKeys = @() }
				[PSCustomObject]@{ FullName = 'dbo.B'; ForeignKeys = @() }
				[PSCustomObject]@{ FullName = 'dbo.C'; ForeignKeys = @() }
			)
			$result = & $module { param($t) Group-SldgTablesByLevel -Tables $t } $tables
			$result.Count | Should -Be 1
			$result[0].Tables.Count | Should -Be 3
		}

		It "Groups tables with same dependency at same level" {
			$tables = @(
				[PSCustomObject]@{ FullName = 'dbo.Parent'; ForeignKeys = @() }
				[PSCustomObject]@{
					FullName    = 'dbo.Child1'
					ForeignKeys = @([PSCustomObject]@{ ReferencedSchema = 'dbo'; ReferencedTable = 'Parent' })
				}
				[PSCustomObject]@{
					FullName    = 'dbo.Child2'
					ForeignKeys = @([PSCustomObject]@{ ReferencedSchema = 'dbo'; ReferencedTable = 'Parent' })
				}
			)
			$result = & $module { param($t) Group-SldgTablesByLevel -Tables $t } $tables
			$result.Count | Should -Be 2
			$result[1].Tables.Count | Should -Be 2
		}
	}

	Context "Convergence Early Exit" {
		It "Converges quickly for simple linear chain" {
			# A → B → C should complete in exactly 3 iterations
			$tables = @(
				[PSCustomObject]@{ FullName = 'dbo.Root'; ForeignKeys = @() }
				[PSCustomObject]@{
					FullName    = 'dbo.Mid'
					ForeignKeys = @([PSCustomObject]@{ ReferencedSchema = 'dbo'; ReferencedTable = 'Root' })
				}
				[PSCustomObject]@{
					FullName    = 'dbo.Leaf'
					ForeignKeys = @([PSCustomObject]@{ ReferencedSchema = 'dbo'; ReferencedTable = 'Mid' })
				}
			)
			$result = & $module { param($t) Group-SldgTablesByLevel -Tables $t } $tables
			$result.Count | Should -Be 3
		}

		It "Source contains convergence early exit logic" {
			$source = & $module { (Get-Command Group-SldgTablesByLevel).ScriptBlock.ToString() }
			$source | Should -Match 'lastLevelSum'
			$source | Should -Match 'currentLevelSum'
		}
	}
}
