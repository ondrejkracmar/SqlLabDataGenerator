Describe "Get-SldgGeneratorMap" {
	BeforeAll {
		Remove-Module SqlLabDataGenerator -ErrorAction Ignore
		Import-Module "$PSScriptRoot\..\..\..\..\SqlLabDataGenerator\SqlLabDataGenerator.psd1" -Force
		$module = Get-Module SqlLabDataGenerator
	}

	Context "Generator Mapping Completeness" {
		BeforeAll {
			$map = & $module { Get-SldgGeneratorMap -Locale 'en-US' }
		}

		It "Contains all person semantic types" {
			$map.ContainsKey('FirstName') | Should -BeTrue
			$map.ContainsKey('LastName') | Should -BeTrue
			$map.ContainsKey('FullName') | Should -BeTrue
			$map.ContainsKey('MiddleName') | Should -BeTrue
		}

		It "Contains all contact semantic types" {
			$map.ContainsKey('Email') | Should -BeTrue
			$map.ContainsKey('Phone') | Should -BeTrue
		}

		It "Contains all address semantic types" {
			$map.ContainsKey('Street') | Should -BeTrue
			$map.ContainsKey('City') | Should -BeTrue
			$map.ContainsKey('State') | Should -BeTrue
			$map.ContainsKey('ZipCode') | Should -BeTrue
			$map.ContainsKey('Country') | Should -BeTrue
		}

		It "Contains all date semantic types" {
			$map.ContainsKey('BirthDate') | Should -BeTrue
			$map.ContainsKey('PastDate') | Should -BeTrue
			$map.ContainsKey('FutureDate') | Should -BeTrue
			$map.ContainsKey('Timestamp') | Should -BeTrue
		}

		It "Contains all numeric semantic types" {
			$map.ContainsKey('Integer') | Should -BeTrue
			$map.ContainsKey('Decimal') | Should -BeTrue
			$map.ContainsKey('Boolean') | Should -BeTrue
			$map.ContainsKey('Money') | Should -BeTrue
			$map.ContainsKey('Quantity') | Should -BeTrue
			$map.ContainsKey('Percentage') | Should -BeTrue
		}

		It "Contains identity semantic types" {
			$map.ContainsKey('Guid') | Should -BeTrue
			$map.ContainsKey('SSN') | Should -BeTrue
			$map.ContainsKey('IBAN') | Should -BeTrue
			$map.ContainsKey('CreditCard') | Should -BeTrue
			$map.ContainsKey('Username') | Should -BeTrue
		}

		It "Contains business semantic types" {
			$map.ContainsKey('CompanyName') | Should -BeTrue
			$map.ContainsKey('Department') | Should -BeTrue
			$map.ContainsKey('JobTitle') | Should -BeTrue
		}

		It "Contains string semantic types" {
			$map.ContainsKey('Text') | Should -BeTrue
			$map.ContainsKey('Status') | Should -BeTrue
			$map.ContainsKey('Category') | Should -BeTrue
			$map.ContainsKey('ShortString') | Should -BeTrue
			$map.ContainsKey('MediumString') | Should -BeTrue
			$map.ContainsKey('LongString') | Should -BeTrue
		}
	}

	Context "Generator Map Structure" {
		BeforeAll {
			$map = & $module { Get-SldgGeneratorMap -Locale 'en-US' }
		}

		It "Each entry has a Function key" {
			foreach ($key in $map.Keys) {
				$map[$key].Function | Should -Not -BeNullOrEmpty -Because "Generator '$key' must have Function"
			}
		}

		It "Each entry has a Params hashtable" {
			foreach ($key in $map.Keys) {
				$map[$key].Params | Should -BeOfType [hashtable] -Because "Generator '$key' must have Params"
			}
		}
	}

	Context "Locale Propagation" {
		It "Passes locale to generator params" {
			$map = & $module { Get-SldgGeneratorMap -Locale 'cs-CZ' }
			$map['FirstName'].Params.Locale | Should -Be 'cs-CZ'
			$map['Email'].Params.Locale | Should -Be 'cs-CZ'
			$map['City'].Params.Locale | Should -Be 'cs-CZ'
		}
	}
}
