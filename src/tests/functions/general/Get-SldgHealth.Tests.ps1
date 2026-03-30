Describe "Get-SldgHealth" {
	BeforeAll {
		Remove-Module SqlLabDataGenerator -ErrorAction Ignore
		Import-Module "$PSScriptRoot\..\..\..\SqlLabDataGenerator\SqlLabDataGenerator.psd1" -Force
	}

	Context "Parameter Validation" {
		It "Has no mandatory parameters" {
			$cmd = Get-Command Get-SldgHealth
			$mandatoryParams = $cmd.Parameters.Values | Where-Object {
				$_.Attributes.Where({ $_ -is [System.Management.Automation.ParameterAttribute] }).Mandatory -eq $true
			}
			$mandatoryParams | Should -BeNullOrEmpty
		}

		It "Declares OutputType HealthStatus" {
			$cmd = Get-Command Get-SldgHealth
			$outputTypes = $cmd.OutputType.Name
			$outputTypes | Should -Contain 'SqlLabDataGenerator.HealthStatus'
		}
	}

	Context "Return Object Structure" {
		BeforeAll {
			$result = Get-SldgHealth
		}

		It "Returns an object with PSTypeName HealthStatus" {
			$result.PSObject.TypeNames | Should -Contain 'SqlLabDataGenerator.HealthStatus'
		}

		It "Has Status property set to OK" {
			$result.Status | Should -Be 'OK'
		}

		It "Has ModuleVersion property" {
			$result.ModuleVersion | Should -Not -BeNullOrEmpty
		}

		It "Has PowerShellVersion property" {
			$result.PowerShellVersion | Should -Not -BeNullOrEmpty
		}

		It "Has Providers array with built-in providers" {
			$result.Providers | Should -Contain 'SqlServer'
		}

		It "Has AIEnabled boolean property" {
			$result.AIEnabled | Should -BeOfType [bool]
		}

		It "Has AILocaleEnabled boolean property" {
			$result.AILocaleEnabled | Should -BeOfType [bool]
		}

		It "Has Timestamp in ISO 8601 format" {
			$result.Timestamp | Should -Not -BeNullOrEmpty
			{ [DateTimeOffset]::Parse($result.Timestamp) } | Should -Not -Throw
		}

		It "Has RegisteredLocales array" {
			$result.RegisteredLocales | Should -BeOfType [string]
		}

		It "Has Transformers array" {
			$result.Transformers | Should -Contain 'EntraIdUser'
		}
	}

	Context "When No Connection" {
		It "Returns null ActiveConnection when not connected" {
			$result = Get-SldgHealth
			$result.ActiveConnection | Should -BeNullOrEmpty
		}
	}
}
