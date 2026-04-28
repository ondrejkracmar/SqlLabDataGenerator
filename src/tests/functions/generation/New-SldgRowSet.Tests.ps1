Describe "New-SldgRowSet" {
	BeforeAll {
		Remove-Module SqlLabDataGenerator -ErrorAction Ignore
		Import-Module "$PSScriptRoot\..\..\..\SqlLabDataGenerator\SqlLabDataGenerator.psd1" -Force

		function New-TestColumn {
			param (
				[string]$Name,
				[string]$DataType = 'nvarchar',
				[bool]$IsIdentity = $false,
				[bool]$IsComputed = $false,
				[bool]$IsNullable = $true,
				[bool]$IsPrimaryKey = $false,
				[bool]$IsUnique = $false,
				[object]$ForeignKey = $null,
				[int]$MaxLength = 50,
				[string]$SemanticType = $null
			)
			[PSCustomObject]@{
				ColumnName     = $Name
				DataType       = $DataType
				IsIdentity     = $IsIdentity
				IsComputed     = $IsComputed
				IsNullable     = $IsNullable
				IsPrimaryKey   = $IsPrimaryKey
				IsUnique       = $IsUnique
				ForeignKey     = $ForeignKey
				MaxLength      = $MaxLength
				SemanticType   = $SemanticType
				Classification = $null
			}
		}

		function New-TestTableInfo {
			param ([string]$FullName = 'dbo.Test', [object[]]$Columns = @())
			[PSCustomObject]@{
				FullName = $FullName
				Schema   = 'dbo'
				Name     = 'Test'
				Columns  = $Columns
			}
		}
	}

	Context "Basic generation" {
		It "Returns an object with a non-null DataTable" {
			$cols = @(
				New-TestColumn -Name 'Id' -DataType 'int' -IsIdentity $true -IsNullable $false
				New-TestColumn -Name 'FirstName' -SemanticType 'firstName' -IsNullable $false
			)
			$ti = New-TestTableInfo -Columns $cols
			$result = InModuleScope SqlLabDataGenerator { param ($t) New-SldgRowSet -TableInfo $t -RowCount 5 } -ArgumentList $ti
			$result | Should -Not -BeNullOrEmpty
			$result.DataTable | Should -Not -BeNullOrEmpty
			$result.DataTable.GetType().FullName | Should -Be 'System.Data.DataTable'
		}

		It "Generates exactly RowCount rows for non-unique workload" {
			$cols = @(New-TestColumn -Name 'Name' -SemanticType 'firstName' -IsNullable $false)
			$ti = New-TestTableInfo -Columns $cols
			$result = InModuleScope SqlLabDataGenerator { param ($t) New-SldgRowSet -TableInfo $t -RowCount 7 } -ArgumentList $ti
			$result.DataTable.Rows.Count | Should -Be 7
		}

		It "Skips identity and computed columns from the DataTable" {
			$cols = @(
				New-TestColumn -Name 'Id' -DataType 'int' -IsIdentity $true -IsNullable $false
				New-TestColumn -Name 'Calc' -DataType 'int' -IsComputed $true -IsNullable $false
				New-TestColumn -Name 'Real' -SemanticType 'firstName' -IsNullable $false
			)
			$ti = New-TestTableInfo -Columns $cols
			$result = InModuleScope SqlLabDataGenerator { param ($t) New-SldgRowSet -TableInfo $t -RowCount 3 } -ArgumentList $ti
			$result.DataTable.Columns.Count | Should -Be 1
			$result.DataTable.Columns[0].ColumnName | Should -Be 'Real'
		}

		It "Skips rowversion / timestamp columns" {
			$cols = @(
				New-TestColumn -Name 'Ver' -DataType 'rowversion' -IsNullable $false
				New-TestColumn -Name 'Real' -SemanticType 'firstName' -IsNullable $false
			)
			$ti = New-TestTableInfo -Columns $cols
			$result = InModuleScope SqlLabDataGenerator { param ($t) New-SldgRowSet -TableInfo $t -RowCount 2 } -ArgumentList $ti
			$result.DataTable.Columns.ColumnName | Should -Not -Contain 'Ver'
		}
	}

	Context "Foreign key handling" {
		It "Uses provided FK candidate values for FK columns" {
			$fk = [PSCustomObject]@{ ReferencedSchema = 'dbo'; ReferencedTable = 'Parent'; ReferencedColumn = 'Id' }
			$cols = @(
				New-TestColumn -Name 'ParentId' -DataType 'int' -ForeignKey $fk -IsNullable $false
				New-TestColumn -Name 'Name' -SemanticType 'firstName' -IsNullable $false
			)
			$ti = New-TestTableInfo -Columns $cols
			$fkValues = @{ 'dbo.Parent.Id' = @(100, 200, 300) }
			$result = InModuleScope SqlLabDataGenerator {
				param ($t, $f) New-SldgRowSet -TableInfo $t -RowCount 10 -ForeignKeyValues $f
			} -ArgumentList $ti, $fkValues

			$result.DataTable.Rows.Count | Should -BeGreaterThan 0
			foreach ($row in $result.DataTable.Rows) {
				$row['ParentId'] | Should -BeIn @(100, 200, 300)
			}
		}
	}
}
