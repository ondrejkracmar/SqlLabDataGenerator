Describe "Get-SldgLocaleData" {
	BeforeAll {
		Remove-Module SqlLabDataGenerator -ErrorAction Ignore
		Import-Module "$PSScriptRoot\..\..\..\..\SqlLabDataGenerator\SqlLabDataGenerator.psd1" -Force
		$module = Get-Module SqlLabDataGenerator
	}

	Context "Built-in Locales" {
		It "Returns en-US locale data" {
			$result = & $module { Get-SldgLocaleData -Locale 'en-US' }
			$result | Should -Not -BeNullOrEmpty
		}

		It "en-US locale has FirstName data" {
			$result = & $module { Get-SldgLocaleData -Locale 'en-US' }
			$result.FirstName | Should -Not -BeNullOrEmpty
			$result.FirstName.Count | Should -BeGreaterThan 0
		}

		It "en-US locale has LastName data" {
			$result = & $module { Get-SldgLocaleData -Locale 'en-US' }
			$result.LastName | Should -Not -BeNullOrEmpty
			$result.LastName.Count | Should -BeGreaterThan 0
		}

		It "en-US locale has City data" {
			$result = & $module { Get-SldgLocaleData -Locale 'en-US' }
			$result.City | Should -Not -BeNullOrEmpty
		}

		It "Uses configured locale when parameter not provided" {
			$result = & $module {
				Set-PSFConfig -FullName 'SqlLabDataGenerator.Generation.Locale' -Value 'en-US'
				Get-SldgLocaleData
			}
			$result | Should -Not -BeNullOrEmpty
		}
	}

	Context "Locale Fallback" {
		It "Falls back to en-US for unknown locale when AI disabled" {
			$result = & $module {
				Set-PSFConfig -FullName 'SqlLabDataGenerator.Generation.AILocale' -Value $false
				Set-PSFConfig -FullName 'SqlLabDataGenerator.AI.Provider' -Value 'None'
				Get-SldgLocaleData -Locale 'xx-XX'
			}
			# Should fall back to en-US
			$result | Should -Not -BeNullOrEmpty
			$result.FirstName | Should -Not -BeNullOrEmpty
		}
	}

	Context "Registered Locales" {
		It "Returns cs-CZ locale if registered" {
			$hasCsCz = & $module { $script:SldgState.Locales.ContainsKey('cs-CZ') }
			if ($hasCsCz) {
				$result = & $module { Get-SldgLocaleData -Locale 'cs-CZ' }
				$result | Should -Not -BeNullOrEmpty
				$result.FirstName | Should -Not -BeNullOrEmpty
			}
			else {
				Set-ItResult -Skipped -Because 'cs-CZ locale is not registered in this environment'
			}
		}
	}
}
