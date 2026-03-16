Describe "Resolve-SldgSemanticType" {
	BeforeAll {
		$global:testroot = $PSScriptRoot
		Remove-Module SqlLabDataGenerator -ErrorAction Ignore
		Import-Module "$PSScriptRoot\..\..\..\..\SqlLabDataGenerator\SqlLabDataGenerator.psd1" -Force
		# Access internal function via module scope
		$module = Get-Module SqlLabDataGenerator
	}

	It "Maps int to Integer" {
		$result = & $module { Resolve-SldgSemanticType -DataType 'int' -IsNullable $false }
		$result.Type | Should -Be 'Integer'
		$result.Generator | Should -Be 'Number'
	}

	It "Maps bigint to Integer" {
		$result = & $module { Resolve-SldgSemanticType -DataType 'bigint' -IsNullable $false }
		$result.Type | Should -Be 'Integer'
	}

	It "Maps decimal to Decimal" {
		$result = & $module { Resolve-SldgSemanticType -DataType 'decimal' -IsNullable $false }
		$result.Type | Should -Be 'Decimal'
		$result.Generator | Should -Be 'Number'
	}

	It "Maps money to Decimal" {
		$result = & $module { Resolve-SldgSemanticType -DataType 'money' -IsNullable $false }
		$result.Type | Should -Be 'Decimal'
	}

	It "Maps bit to Boolean" {
		$result = & $module { Resolve-SldgSemanticType -DataType 'bit' -IsNullable $false }
		$result.Type | Should -Be 'Boolean'
	}

	It "Maps date to Date" {
		$result = & $module { Resolve-SldgSemanticType -DataType 'date' -IsNullable $false }
		$result.Type | Should -Be 'Date'
		$result.Generator | Should -Be 'Date'
	}

	It "Maps datetime to DateTime" {
		$result = & $module { Resolve-SldgSemanticType -DataType 'datetime' -IsNullable $false }
		$result.Type | Should -Be 'DateTime'
	}

	It "Maps datetime2 to DateTime" {
		$result = & $module { Resolve-SldgSemanticType -DataType 'datetime2' -IsNullable $false }
		$result.Type | Should -Be 'DateTime'
	}

	It "Maps uniqueidentifier to Guid" {
		$result = & $module { Resolve-SldgSemanticType -DataType 'uniqueidentifier' -IsNullable $false }
		$result.Type | Should -Be 'Guid'
		$result.Generator | Should -Be 'Identifier'
	}

	It "Maps short nvarchar to ShortString" {
		$result = & $module { Resolve-SldgSemanticType -DataType 'nvarchar' -MaxLength 10 -IsNullable $false }
		$result.Type | Should -Be 'ShortString'
	}

	It "Maps medium nvarchar to MediumString" {
		$result = & $module { Resolve-SldgSemanticType -DataType 'nvarchar' -MaxLength 50 -IsNullable $false }
		$result.Type | Should -Be 'MediumString'
	}

	It "Maps long nvarchar to LongString" {
		$result = & $module { Resolve-SldgSemanticType -DataType 'nvarchar' -MaxLength 200 -IsNullable $false }
		$result.Type | Should -Be 'LongString'
	}

	It "Maps nvarchar(max) to LongString" {
		$result = & $module { Resolve-SldgSemanticType -DataType 'nvarchar' -MaxLength -1 -IsNullable $false }
		$result.Type | Should -Be 'LongString'
	}

	It "Maps short char to Code" {
		$result = & $module { Resolve-SldgSemanticType -DataType 'char' -MaxLength 5 -IsNullable $false }
		$result.Type | Should -Be 'Code'
	}

	It "Maps binary to Binary (skip)" {
		$result = & $module { Resolve-SldgSemanticType -DataType 'varbinary' -IsNullable $false }
		$result.Type | Should -Be 'Binary'
		$result.Generator | Should -Be 'Skip'
	}

	It "Maps timestamp to RowVersion (skip)" {
		$result = & $module { Resolve-SldgSemanticType -DataType 'timestamp' -IsNullable $false }
		$result.Type | Should -Be 'RowVersion'
		$result.Generator | Should -Be 'Skip'
	}

	It "Maps unknown type to Unknown" {
		$result = & $module { Resolve-SldgSemanticType -DataType 'somecustomtype' -IsNullable $false }
		$result.Type | Should -Be 'Unknown'
		$result.Generator | Should -Be 'Text'
	}
}
