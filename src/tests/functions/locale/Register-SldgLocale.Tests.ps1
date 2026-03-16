Describe "Register-SldgLocale" {
	BeforeAll {
		Remove-Module SqlLabDataGenerator -ErrorAction Ignore
		Import-Module "$PSScriptRoot\..\..\..\SqlLabDataGenerator\SqlLabDataGenerator.psd1" -Force
		$module = Get-Module SqlLabDataGenerator
	}

	Context "Parameter Validation" {
		It "Has mandatory Name parameter" {
			$cmd = Get-Command Register-SldgLocale
			$cmd.Parameters['Name'].Attributes.Where({ $_ -is [System.Management.Automation.ParameterAttribute] }).Mandatory | Should -BeTrue
		}

		It "Has three parameter sets" {
			$cmd = Get-Command Register-SldgLocale
			$cmd.ParameterSets.Count | Should -BeGreaterOrEqual 3
		}

		It "Manual parameter set requires Data hashtable" {
			$cmd = Get-Command Register-SldgLocale
			$dataParam = $cmd.Parameters['Data']
			$manualAttr = $dataParam.Attributes.Where({ $_ -is [System.Management.Automation.ParameterAttribute] -and $_.ParameterSetName -eq 'Manual' })
			$manualAttr.Mandatory | Should -BeTrue
		}

		It "AI parameter set requires UseAI switch" {
			$cmd = Get-Command Register-SldgLocale
			$useAiParam = $cmd.Parameters['UseAI']
			$aiAttr = $useAiParam.Attributes.Where({ $_ -is [System.Management.Automation.ParameterAttribute] -and $_.ParameterSetName -eq 'AI' })
			$aiAttr.Mandatory | Should -BeTrue
		}

		It "Mix parameter set requires MixFrom hashtable" {
			$cmd = Get-Command Register-SldgLocale
			$mixParam = $cmd.Parameters['MixFrom']
			$mixAttr = $mixParam.Attributes.Where({ $_ -is [System.Management.Automation.ParameterAttribute] -and $_.ParameterSetName -eq 'Mix' })
			$mixAttr.Mandatory | Should -BeTrue
		}

		It "Has PoolSize integer parameter" {
			$cmd = Get-Command Register-SldgLocale
			$cmd.Parameters['PoolSize'].ParameterType.Name | Should -Be 'Int32'
		}

		It "PoolSize defaults to 30" {
			$cmd = Get-Command Register-SldgLocale
			$cmd.Parameters['PoolSize'].DefaultValue | Should -Be 30
		}

		It "Has CustomInstructions string parameter" {
			$cmd = Get-Command Register-SldgLocale
			$cmd.Parameters['CustomInstructions'].ParameterType.Name | Should -Be 'String'
		}

		It "Has Force switch parameter" {
			$cmd = Get-Command Register-SldgLocale
			$cmd.Parameters['Force'].SwitchParameter | Should -BeTrue
		}
	}

	Context "Manual Registration" {
		BeforeAll {
			$script:testLocaleData = @{
				MaleNames       = @('Jan', 'Petr')
				FemaleNames     = @('Jana', 'Marie')
				LastNames       = @('Novak', 'Svoboda')
				StreetNames     = @('Hlavni', 'Namesti')
				StreetTypes     = @('ulice', 'namesti')
				Locations       = @('Praha', 'Brno')
				Countries       = @('Ceska republika')
				EmailDomains    = @('example.cz', 'test.cz')
				PhoneFormat     = '+420 ### ### ###'
				CompanyPrefixes = @('Ceska')
				CompanyCores    = @('Technika')
				CompanySuffixes = @('s.r.o.', 'a.s.')
				Departments     = @('IT', 'HR')
				JobTitles       = @('Manager', 'Developer')
				Industries      = @('Technology', 'Finance')
			}
		}

		It "Registers locale with manual data" {
			Register-SldgLocale -Name 'pester-test' -Data $script:testLocaleData
			$locale = & $module { $script:SldgState.Locales['pester-test'] }
			$locale | Should -Not -BeNullOrEmpty
		}

		It "Stores all provided data keys" {
			$locale = & $module { $script:SldgState.Locales['pester-test'] }
			$locale.MaleNames | Should -Contain 'Jan'
			$locale.FemaleNames | Should -Contain 'Jana'
			$locale.LastNames | Should -Contain 'Novak'
		}

		It "Stores phone format" {
			$locale = & $module { $script:SldgState.Locales['pester-test'] }
			$locale.PhoneFormat | Should -Be '+420 ### ### ###'
		}

		AfterAll {
			& $module { $script:SldgState.Locales.Remove('pester-test') }
		}
	}

	Context "Built-in Locales" {
		It "Has en-US locale registered" {
			$locale = & $module { $script:SldgState.Locales['en-US'] }
			$locale | Should -Not -BeNullOrEmpty
		}

		It "Has cs-CZ locale registered" {
			$locale = & $module { $script:SldgState.Locales['cs-CZ'] }
			$locale | Should -Not -BeNullOrEmpty
		}

		It "en-US locale has MaleNames" {
			$locale = & $module { $script:SldgState.Locales['en-US'] }
			$locale.MaleNames.Count | Should -BeGreaterThan 0
		}

		It "cs-CZ locale has MaleNames" {
			$locale = & $module { $script:SldgState.Locales['cs-CZ'] }
			$locale.MaleNames.Count | Should -BeGreaterThan 0
		}
	}
}
