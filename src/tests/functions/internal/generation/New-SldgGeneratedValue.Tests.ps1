Describe "New-SldgGeneratedValue" {
	BeforeAll {
		Remove-Module SqlLabDataGenerator -ErrorAction Ignore
		Import-Module "$PSScriptRoot\..\..\..\..\SqlLabDataGenerator\SqlLabDataGenerator.psd1" -Force
		$module = Get-Module SqlLabDataGenerator
		$generatorMap = & $module { Get-SldgGeneratorMap -Locale 'en-US' }
	}

	Context "Identity Columns" {
		It "Returns null for identity columns" {
			$col = [PSCustomObject]@{
				ColumnName    = 'Id'
				DataType      = 'int'
				IsIdentity    = $true
				IsComputed    = $false
				IsPrimaryKey  = $true
				IsNullable    = $false
				IsUnique      = $true
				ForeignKey    = $null
				SemanticType  = $null
				Classification = $null
				MaxLength     = $null
			}
			$result = & $module { param($c, $m) New-SldgGeneratedValue -Column $c -GeneratorMap $m } $col $generatorMap
			$result | Should -BeNullOrEmpty
		}

		It "Returns null for computed columns" {
			$col = [PSCustomObject]@{
				ColumnName    = 'FullName'
				DataType      = 'nvarchar'
				IsIdentity    = $false
				IsComputed    = $true
				IsPrimaryKey  = $false
				IsNullable    = $true
				IsUnique      = $false
				ForeignKey    = $null
				SemanticType  = $null
				Classification = $null
				MaxLength     = 200
			}
			$result = & $module { param($c, $m) New-SldgGeneratedValue -Column $c -GeneratorMap $m } $col $generatorMap
			$result | Should -BeNullOrEmpty
		}
	}

	Context "Foreign Key Columns" {
		It "Picks value from parent FK values" {
			$col = [PSCustomObject]@{
				ColumnName    = 'CustomerId'
				DataType      = 'int'
				IsIdentity    = $false
				IsComputed    = $false
				IsPrimaryKey  = $false
				IsNullable    = $false
				IsUnique      = $false
				ForeignKey    = [PSCustomObject]@{ ReferencedSchema = 'dbo'; ReferencedTable = 'Customer'; ReferencedColumn = 'Id' }
				SemanticType  = $null
				Classification = $null
				MaxLength     = $null
			}
			$fkValues = @{ 'dbo.Customer.Id' = @(1, 2, 3, 4, 5) }
			$result = & $module { param($c, $m, $fk) New-SldgGeneratedValue -Column $c -GeneratorMap $m -ForeignKeyValues $fk } $col $generatorMap $fkValues
			$result | Should -BeIn @(1, 2, 3, 4, 5)
		}
	}

	Context "Custom Rules" {
		It "Uses ValueList rule" {
			$col = [PSCustomObject]@{
				ColumnName    = 'Status'
				DataType      = 'nvarchar'
				IsIdentity    = $false
				IsComputed    = $false
				IsPrimaryKey  = $false
				IsNullable    = $false
				IsUnique      = $false
				ForeignKey    = $null
				SemanticType  = 'Status'
				Classification = $null
				MaxLength     = 20
			}
			$rule = @{ ValueList = @('Active', 'Inactive', 'Pending') }
			$result = & $module { param($c, $m, $r) New-SldgGeneratedValue -Column $c -GeneratorMap $m -CustomRule $r } $col $generatorMap $rule
			$result | Should -BeIn @('Active', 'Inactive', 'Pending')
		}

		It "Uses StaticValue rule" {
			$col = [PSCustomObject]@{
				ColumnName    = 'Currency'
				DataType      = 'char'
				IsIdentity    = $false
				IsComputed    = $false
				IsPrimaryKey  = $false
				IsNullable    = $false
				IsUnique      = $false
				ForeignKey    = $null
				SemanticType  = 'Currency'
				Classification = $null
				MaxLength     = 3
			}
			$rule = @{ StaticValue = 'USD' }
			$result = & $module { param($c, $m, $r) New-SldgGeneratedValue -Column $c -GeneratorMap $m -CustomRule $r } $col $generatorMap $rule
			$result | Should -Be 'USD'
		}
	}

	Context "Semantic Type Generation" {
		It "Generates a value for Email semantic type" {
			$col = [PSCustomObject]@{
				ColumnName    = 'EmailAddress'
				DataType      = 'nvarchar'
				IsIdentity    = $false
				IsComputed    = $false
				IsPrimaryKey  = $false
				IsNullable    = $false
				IsUnique      = $false
				ForeignKey    = $null
				SemanticType  = 'Email'
				Classification = $null
				MaxLength     = 100
			}
			$result = & $module { param($c, $m) New-SldgGeneratedValue -Column $c -GeneratorMap $m } $col $generatorMap
			$result | Should -Match '@'
		}

		It "Generates a numeric value for Integer semantic type" {
			$col = [PSCustomObject]@{
				ColumnName    = 'Quantity'
				DataType      = 'int'
				IsIdentity    = $false
				IsComputed    = $false
				IsPrimaryKey  = $false
				IsNullable    = $false
				IsUnique      = $false
				ForeignKey    = $null
				SemanticType  = 'Integer'
				Classification = $null
				MaxLength     = $null
			}
			$result = & $module { param($c, $m) New-SldgGeneratedValue -Column $c -GeneratorMap $m } $col $generatorMap
			$result | Should -BeOfType [int] -Or $result | Should -BeOfType [long]
		}
	}

	Context "Data Type Fallback" {
		It "Generates int fallback for unknown int column" {
			$col = [PSCustomObject]@{
				ColumnName    = 'xyzunknown'
				DataType      = 'int'
				IsIdentity    = $false
				IsComputed    = $false
				IsPrimaryKey  = $false
				IsNullable    = $false
				IsUnique      = $false
				ForeignKey    = $null
				SemanticType  = $null
				Classification = $null
				MaxLength     = $null
			}
			$emptyMap = @{}
			$result = & $module { param($c, $m) New-SldgGeneratedValue -Column $c -GeneratorMap $m } $col $emptyMap
			$result | Should -BeOfType [int]
		}

		It "Generates date fallback for unknown date column" {
			$col = [PSCustomObject]@{
				ColumnName    = 'xyzunknown'
				DataType      = 'date'
				IsIdentity    = $false
				IsComputed    = $false
				IsPrimaryKey  = $false
				IsNullable    = $false
				IsUnique      = $false
				ForeignKey    = $null
				SemanticType  = $null
				Classification = $null
				MaxLength     = $null
			}
			$emptyMap = @{}
			$result = & $module { param($c, $m) New-SldgGeneratedValue -Column $c -GeneratorMap $m } $col $emptyMap
			$result | Should -Match '^\d{4}-\d{2}-\d{2}'
		}
	}
}
