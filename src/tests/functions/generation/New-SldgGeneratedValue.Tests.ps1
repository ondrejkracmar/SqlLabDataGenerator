Describe "New-SldgGeneratedValue" {
	BeforeAll {
		Remove-Module SqlLabDataGenerator -ErrorAction Ignore
		Import-Module "$PSScriptRoot\..\..\..\SqlLabDataGenerator\SqlLabDataGenerator.psd1" -Force

		function New-TestColumn {
			param (
				[string]$Name = 'Col',
				[bool]$IsIdentity = $false,
				[bool]$IsComputed = $false,
				[bool]$IsNullable = $false,
				[bool]$IsPrimaryKey = $false,
				[bool]$IsUnique = $false,
				[object]$ForeignKey = $null,
				[object]$Classification = $null,
				[string]$SemanticType = $null,
				[string]$DataType = 'nvarchar',
				[int]$MaxLength = 50
			)
			[PSCustomObject]@{
				ColumnName     = $Name
				IsIdentity     = $IsIdentity
				IsComputed     = $IsComputed
				IsNullable     = $IsNullable
				IsPrimaryKey   = $IsPrimaryKey
				IsUnique       = $IsUnique
				ForeignKey     = $ForeignKey
				Classification = $Classification
				SemanticType   = $SemanticType
				DataType       = $DataType
				MaxLength      = $MaxLength
			}
		}
	}

	Context "Identity / computed columns" {
		It "Returns null for identity columns" {
			$col = New-TestColumn -IsIdentity $true
			InModuleScope SqlLabDataGenerator { param ($c) New-SldgGeneratedValue -Column $c } -ArgumentList $col | Should -BeNullOrEmpty
		}

		It "Returns null for computed columns" {
			$col = New-TestColumn -IsComputed $true
			InModuleScope SqlLabDataGenerator { param ($c) New-SldgGeneratedValue -Column $c } -ArgumentList $col | Should -BeNullOrEmpty
		}
	}

	Context "Foreign key resolution" {
		It "Picks a parent value when FK has populated candidates" {
			$fk = [PSCustomObject]@{ ReferencedSchema = 'dbo'; ReferencedTable = 'Parent'; ReferencedColumn = 'Id' }
			$col = New-TestColumn -ForeignKey $fk
			$fkVals = @{ 'dbo.Parent.Id' = @(1, 2, 3) }
			$result = InModuleScope SqlLabDataGenerator {
				param ($c, $f) New-SldgGeneratedValue -Column $c -ForeignKeyValues $f
			} -ArgumentList $col, $fkVals
			$result | Should -BeIn @(1, 2, 3)
		}

		It "Returns null and warns when FK parent values are missing" {
			$fk = [PSCustomObject]@{ ReferencedSchema = 'dbo'; ReferencedTable = 'Parent'; ReferencedColumn = 'Id' }
			$col = New-TestColumn -ForeignKey $fk
			$result = InModuleScope SqlLabDataGenerator {
				param ($c) New-SldgGeneratedValue -Column $c -ForeignKeyValues @{}
			} -ArgumentList $col
			$result | Should -BeNullOrEmpty
		}
	}

	Context "Custom rule overrides" {
		It "Returns StaticValue verbatim" {
			$col = New-TestColumn
			$rule = @{ StaticValue = 'FIXED' }
			$result = InModuleScope SqlLabDataGenerator {
				param ($c, $r) New-SldgGeneratedValue -Column $c -CustomRule $r
			} -ArgumentList $col, $rule
			$result | Should -Be 'FIXED'
		}

		It "Returns one of the ValueList entries" {
			$col = New-TestColumn
			$rule = @{ ValueList = @('A', 'B', 'C') }
			$result = InModuleScope SqlLabDataGenerator {
				param ($c, $r) New-SldgGeneratedValue -Column $c -CustomRule $r
			} -ArgumentList $col, $rule
			$result | Should -BeIn @('A', 'B', 'C')
		}

		It "Invokes ScriptBlock and returns its output" {
			$col = New-TestColumn
			$rule = @{ ScriptBlock = { 'FROM-SB' } }
			$result = InModuleScope SqlLabDataGenerator {
				param ($c, $r) New-SldgGeneratedValue -Column $c -CustomRule $r
			} -ArgumentList $col, $rule
			$result | Should -Be 'FROM-SB'
		}
	}

	Context "Nullable column handling" {
		It "Always emits a value when NullProbability = 0" {
			$col = New-TestColumn -IsNullable $true
			$rule = @{ StaticValue = 'X' }
			$results = 1..20 | ForEach-Object {
				InModuleScope SqlLabDataGenerator {
					param ($c, $r) New-SldgGeneratedValue -Column $c -CustomRule $r -NullProbability 0
				} -ArgumentList $col, $rule
			}
			($results | Where-Object { $_ -is [DBNull] }) | Should -BeNullOrEmpty
		}

		It "Always emits DBNull when NullProbability = 100 for plain nullable column" {
			$col = New-TestColumn -IsNullable $true -SemanticType 'firstName'
			$results = 1..20 | ForEach-Object {
				InModuleScope SqlLabDataGenerator {
					param ($c) New-SldgGeneratedValue -Column $c -NullProbability 100
				} -ArgumentList $col
			}
			($results | Where-Object { $_ -isnot [DBNull] }) | Should -BeNullOrEmpty
		}

		It "Never returns DBNull for unique nullable columns even at 100% probability" {
			$col = New-TestColumn -IsNullable $true -IsUnique $true
			$rule = @{ StaticValue = 'X' }
			$result = InModuleScope SqlLabDataGenerator {
				param ($c, $r) New-SldgGeneratedValue -Column $c -CustomRule $r -NullProbability 100
			} -ArgumentList $col, $rule
			$result | Should -Not -BeOfType ([DBNull])
		}
	}
}
