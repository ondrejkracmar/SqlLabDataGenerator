Describe "Get-SldgSession" {
	BeforeAll {
		Remove-Module SqlLabDataGenerator -ErrorAction Ignore
		Import-Module "$PSScriptRoot\..\..\..\SqlLabDataGenerator\SqlLabDataGenerator.psd1" -Force
		$module = Get-Module SqlLabDataGenerator
	}

	Context "Parameter Validation" {
		It "Has no mandatory parameters" {
			$cmd = Get-Command Get-SldgSession
			$mandatoryParams = $cmd.Parameters.Values | Where-Object {
				$_.Attributes.Where({ $_ -is [System.Management.Automation.ParameterAttribute] }).Mandatory -eq $true
			}
			$mandatoryParams | Should -BeNullOrEmpty
		}

		It "Has Full switch parameter" {
			$cmd = Get-Command Get-SldgSession
			$cmd.Parameters['Full'].SwitchParameter | Should -BeTrue
		}

		It "Declares OutputType SessionInfo" {
			$cmd = Get-Command Get-SldgSession
			$outputTypes = $cmd.OutputType.Type.FullName
			$outputTypes | Should -Contain 'SqlLabDataGenerator.SessionInfo'
		}

		It "Declares OutputType SldgSession for Full parameter set" {
			$cmd = Get-Command Get-SldgSession
			$outputTypes = $cmd.OutputType.Type.FullName
			$outputTypes | Should -Contain 'SqlLabDataGenerator.SldgSession'
		}
	}

	Context "Default Summary Mode" {
		BeforeAll {
			$result = Get-SldgSession
		}

		It "Returns a SessionInfo object" {
			$result | Should -BeOfType 'SqlLabDataGenerator.SessionInfo'
		}

		It "Has SessionId property as Guid" {
			$result.SessionId | Should -BeOfType [Guid]
		}

		It "Has CreatedAt property as DateTime" {
			$result.CreatedAt | Should -BeOfType [DateTime]
		}

		It "Has AIProvider summary" {
			$result.AIProvider | Should -Not -BeNullOrEmpty
		}

		It "Has RegisteredProviders including built-in providers" {
			$result.RegisteredProviders | Should -Contain 'SqlServer'
		}

		It "Has CacheSizes summary" {
			$result.CacheSizes | Should -Not -BeNullOrEmpty
			$result.CacheSizes.AIValueCache | Should -BeOfType [int]
		}
	}

	Context "Full Mode" {
		BeforeAll {
			$result = Get-SldgSession -Full
		}

		It "Returns a SldgSession object" {
			$result | Should -BeOfType 'SqlLabDataGenerator.SldgSession'
		}

		It "Has Providers collection" {
			$result.Providers | Should -Not -BeNullOrEmpty
		}

		It "Has AIValueCache collection" {
			$result.AIValueCache | Should -Not -BeNull
		}
	}
}
