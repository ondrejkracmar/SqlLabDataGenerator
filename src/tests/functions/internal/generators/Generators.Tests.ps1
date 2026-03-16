Describe "Data Generators" {
	BeforeAll {
		Remove-Module SqlLabDataGenerator -ErrorAction Ignore
		Import-Module "$PSScriptRoot\..\..\..\..\SqlLabDataGenerator\SqlLabDataGenerator.psd1" -Force
		$module = Get-Module SqlLabDataGenerator
	}

	Context "New-SldgPersonName" {
		It "Generates a first name" {
			$result = & $module { New-SldgPersonName -Type 'First' -Locale 'en-US' }
			$result | Should -Not -BeNullOrEmpty
			$result | Should -BeOfType [string]
		}

		It "Generates a last name" {
			$result = & $module { New-SldgPersonName -Type 'Last' -Locale 'en-US' }
			$result | Should -Not -BeNullOrEmpty
		}

		It "Generates first name from Czech locale" {
			$result = & $module { New-SldgPersonName -Type 'First' -Locale 'cs-CZ' }
			$result | Should -Not -BeNullOrEmpty
		}

		It "Generates a full name with space" {
			$result = & $module { New-SldgPersonName -Type 'Full' -Locale 'en-US' }
			$result | Should -Match '\s'
		}
	}

	Context "New-SldgEmail" {
		It "Generates a valid-looking email" {
			$result = & $module { New-SldgEmail -Locale 'en-US' }
			$result | Should -Match '@'
			$result | Should -Match '\.'
		}
	}

	Context "New-SldgNumber" {
		It "Generates an integer" {
			$result = & $module { New-SldgNumber -Type 'Integer' }
			$result | Should -BeOfType [int]
		}

		It "Generates a decimal" {
			$result = & $module { New-SldgNumber -Type 'Decimal' }
			($result -is [double] -or $result -is [decimal]) | Should -BeTrue
		}

		It "Generates a boolean (0 or 1)" {
			$result = & $module { New-SldgNumber -Type 'Boolean' }
			$result | Should -BeIn @(0, 1, $true, $false)
		}

		It "Generates an age in valid range" {
			$result = & $module { New-SldgNumber -Type 'Age' }
			$result | Should -BeGreaterOrEqual 0
			$result | Should -BeLessOrEqual 120
		}

		It "Generates money value" {
			$result = & $module { New-SldgNumber -Type 'Money' }
			$result | Should -BeGreaterThan 0
		}
	}

	Context "New-SldgDate" {
		It "Generates a date string" {
			$result = & $module { New-SldgDate -Type 'Date' }
			$result | Should -Match '^\d{4}-\d{2}-\d{2}'
		}

		It "Generates a birth date in the past" {
			$result = & $module { New-SldgDate -Type 'BirthDate' }
			[datetime]$d = $result
			$d | Should -BeLessThan (Get-Date)
		}

		It "Generates a timestamp with time component" {
			$result = & $module { New-SldgDate -Type 'Timestamp' -IncludeTime }
			$result | Should -Match 'T|:'
		}
	}

	Context "New-SldgAddress" {
		It "Generates a city" {
			$result = & $module { New-SldgAddress -Type 'City' -Locale 'en-US' }
			$result | Should -Not -BeNullOrEmpty
		}

		It "Generates a street" {
			$result = & $module { New-SldgAddress -Type 'Street' -Locale 'en-US' }
			$result | Should -Not -BeNullOrEmpty
		}

		It "Generates a zip code" {
			$result = & $module { New-SldgAddress -Type 'ZipCode' -Locale 'en-US' }
			$result | Should -Not -BeNullOrEmpty
		}
	}

	Context "New-SldgIdentifier" {
		It "Generates a GUID" {
			$result = & $module { New-SldgIdentifier -Type 'Guid' }
			{ [Guid]::Parse($result) } | Should -Not -Throw
		}

		It "Generates a username" {
			$result = & $module { New-SldgIdentifier -Type 'Username' -Locale 'en-US' }
			$result | Should -Not -BeNullOrEmpty
		}
	}

	Context "New-SldgCompany" {
		It "Generates a company name" {
			$result = & $module { New-SldgCompany -Type 'Company' -Locale 'en-US' }
			$result | Should -Not -BeNullOrEmpty
		}

		It "Generates a department" {
			$result = & $module { New-SldgCompany -Type 'Department' -Locale 'en-US' }
			$result | Should -Not -BeNullOrEmpty
		}
	}

	Context "New-SldgText" {
		It "Generates a status" {
			$result = & $module { New-SldgText -Type 'Status' -Locale 'en-US' }
			$result | Should -Not -BeNullOrEmpty
		}

		It "Generates a URL" {
			$result = & $module { New-SldgText -Type 'Url' -Locale 'en-US' }
			$result | Should -Match 'http'
		}

		It "Generates an IP address" {
			$result = & $module { New-SldgText -Type 'IpAddress' -Locale 'en-US' }
			$result | Should -Match '^\d+\.\d+\.\d+\.\d+$'
		}
	}

	Context "New-SldgPhone" {
		It "Generates a phone number" {
			$result = & $module { New-SldgPhone -Format 'Standard' -Locale 'en-US' }
			$result | Should -Not -BeNullOrEmpty
		}
	}
}
