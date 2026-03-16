Describe "Test-SldgAIProvider" {
	BeforeAll {
		Remove-Module SqlLabDataGenerator -ErrorAction Ignore
		Import-Module "$PSScriptRoot\..\..\..\SqlLabDataGenerator\SqlLabDataGenerator.psd1" -Force
		$module = Get-Module SqlLabDataGenerator
	}

	Context "Parameter Validation" {
		It "Has no mandatory parameters" {
			$cmd = Get-Command Test-SldgAIProvider
			$mandatoryParams = $cmd.Parameters.Values.Where({
				$_.Attributes.Where({ $_ -is [System.Management.Automation.ParameterAttribute] -and $_.Mandatory })
			})
			$mandatoryParams.Count | Should -Be 0
		}
	}

	Context "Return Object Structure" {
		It "Returns AIProviderTestResult type" {
			$result = Test-SldgAIProvider
			$result.PSTypeNames | Should -Contain 'SqlLabDataGenerator.AIProviderTestResult'
		}

		It "Result has required properties" {
			$result = Test-SldgAIProvider
			$result.PSObject.Properties.Name | Should -Contain 'Provider'
			$result.PSObject.Properties.Name | Should -Contain 'Model'
			$result.PSObject.Properties.Name | Should -Contain 'Status'
			$result.PSObject.Properties.Name | Should -Contain 'ResponseMs'
			$result.PSObject.Properties.Name | Should -Contain 'Error'
		}
	}

	Context "When No Provider Configured" {
		BeforeAll {
			& $module { Set-PSFConfig -FullName 'SqlLabDataGenerator.AI.Provider' -Value 'None' }
		}

		It "Returns NotConfigured status" {
			$result = Test-SldgAIProvider
			$result.Status | Should -Be 'NotConfigured'
		}

		It "Returns None as provider" {
			$result = Test-SldgAIProvider
			$result.Provider | Should -Be 'None'
		}

		It "Has null model" {
			$result = Test-SldgAIProvider
			$result.Model | Should -BeNullOrEmpty
		}

		It "Has null ResponseMs" {
			$result = Test-SldgAIProvider
			$result.ResponseMs | Should -BeNullOrEmpty
		}

		It "Has error message" {
			$result = Test-SldgAIProvider
			$result.Error | Should -Not -BeNullOrEmpty
		}
	}

	Context "When Provider Configured" {
		BeforeAll {
			& $module {
				Set-PSFConfig -FullName 'SqlLabDataGenerator.AI.Provider' -Value 'Ollama'
				Set-PSFConfig -FullName 'SqlLabDataGenerator.AI.Model' -Value 'llama3'
				Set-PSFConfig -FullName 'SqlLabDataGenerator.AI.Endpoint' -Value 'http://localhost:11434'
			}
		}

		It "Includes provider name in result" {
			$result = Test-SldgAIProvider
			$result.Provider | Should -Be 'Ollama'
		}

		It "Includes model name in result" {
			$result = Test-SldgAIProvider
			$result.Model | Should -Be 'llama3'
		}

		It "Includes endpoint in result" {
			$result = Test-SldgAIProvider
			$result.Endpoint | Should -Be 'http://localhost:11434'
		}

		It "Returns a numeric ResponseMs when provider responds" {
			$result = Test-SldgAIProvider
			# May be Connected or Failed depending on environment; ResponseMs should exist either way
			$result.ResponseMs | Should -BeOfType [int]
		}

		AfterAll {
			& $module { Set-PSFConfig -FullName 'SqlLabDataGenerator.AI.Provider' -Value 'None' }
		}
	}
}
