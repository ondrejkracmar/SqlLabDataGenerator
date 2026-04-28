Describe "Group-SldgTablesByLevel" {
	BeforeAll {
		Remove-Module SqlLabDataGenerator -ErrorAction Ignore
		Import-Module "$PSScriptRoot\..\..\..\SqlLabDataGenerator\SqlLabDataGenerator.psd1" -Force

		function New-TestTable {
			param ([string]$FullName, [object[]]$ForeignKeys = @())
			[PSCustomObject]@{ FullName = $FullName; ForeignKeys = $ForeignKeys }
		}
		function New-TestFK {
			param ([string]$Schema, [string]$Table)
			[PSCustomObject]@{ ReferencedSchema = $Schema; ReferencedTable = $Table }
		}
	}

	Context "Level computation" {
		It "Assigns level 0 to a single table without dependencies" {
			$tables = @((New-TestTable -FullName 'dbo.Lone'))
			$result = InModuleScope SqlLabDataGenerator { param ($t) Group-SldgTablesByLevel -Tables $t } -ArgumentList (, $tables)
			$result.Count | Should -Be 1
			$result[0].Level | Should -Be 0
			$result[0].Tables[0].FullName | Should -Be 'dbo.Lone'
		}

		It "Places child table in level 1 when it depends on a level-0 table" {
			$parent = New-TestTable -FullName 'dbo.Parent'
			$child = New-TestTable -FullName 'dbo.Child' -ForeignKeys @((New-TestFK -Schema 'dbo' -Table 'Parent'))
			$result = InModuleScope SqlLabDataGenerator { param ($t) Group-SldgTablesByLevel -Tables $t } -ArgumentList (, @($parent, $child))
			$result.Count | Should -Be 2
			$result[0].Tables.FullName | Should -Be 'dbo.Parent'
			$result[1].Tables.FullName | Should -Be 'dbo.Child'
		}

		It "Computes level 2 for a 3-level chain Parent -> Child -> Grandchild" {
			$p = New-TestTable -FullName 'dbo.A'
			$c = New-TestTable -FullName 'dbo.B' -ForeignKeys @((New-TestFK -Schema 'dbo' -Table 'A'))
			$g = New-TestTable -FullName 'dbo.C' -ForeignKeys @((New-TestFK -Schema 'dbo' -Table 'B'))
			$result = InModuleScope SqlLabDataGenerator { param ($t) Group-SldgTablesByLevel -Tables $t } -ArgumentList (, @($p, $c, $g))
			$result.Count | Should -Be 3
			$result[2].Tables.FullName | Should -Be 'dbo.C'
			$result[2].Level | Should -Be 2
		}

		It "Ignores self-referencing FK and stays at level 0" {
			$t = New-TestTable -FullName 'dbo.Tree' -ForeignKeys @((New-TestFK -Schema 'dbo' -Table 'Tree'))
			$result = InModuleScope SqlLabDataGenerator { param ($t) Group-SldgTablesByLevel -Tables $t } -ArgumentList (, @($t))
			$result.Count | Should -Be 1
			$result[0].Level | Should -Be 0
		}

		It "Groups two unrelated tables together at level 0" {
			$a = New-TestTable -FullName 'dbo.A'
			$b = New-TestTable -FullName 'dbo.B'
			$result = InModuleScope SqlLabDataGenerator { param ($t) Group-SldgTablesByLevel -Tables $t } -ArgumentList (, @($a, $b))
			$result.Count | Should -Be 1
			$result[0].Tables.Count | Should -Be 2
		}

		It "Terminates without infinite loop on circular FK A and B" {
			$a = New-TestTable -FullName 'dbo.A' -ForeignKeys @((New-TestFK -Schema 'dbo' -Table 'B'))
			$b = New-TestTable -FullName 'dbo.B' -ForeignKeys @((New-TestFK -Schema 'dbo' -Table 'A'))
			$result = InModuleScope SqlLabDataGenerator { param ($t) Group-SldgTablesByLevel -Tables $t } -ArgumentList (, @($a, $b))
			$result | Should -Not -BeNullOrEmpty
		}
	}
}
