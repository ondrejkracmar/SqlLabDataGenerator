Describe "Get-SldgAIProvider" {
	BeforeAll {
		Remove-Module SqlLabDataGenerator -ErrorAction Ignore
		Import-Module "$PSScriptRoot\..\..\..\SqlLabDataGenerator\SqlLabDataGenerator.psd1" -Force
		$module = Get-Module SqlLabDataGenerator
	}

	AfterAll {
		& $module { Set-PSFConfig -FullName 'SqlLabDataGenerator.AI.Provider' -Value 'None' }
	}

	Context "Parameter Validation" {
		It "Has no mandatory parameters" {
			$cmd = Get-Command Get-SldgAIProvider
			$mandatoryParams = $cmd.Parameters.Values | Where-Object {
				$_.Attributes.Where({ $_ -is [System.Management.Automation.ParameterAttribute] }).Mandatory -eq $true
			}
			$mandatoryParams | Should -BeNullOrEmpty
		}
	}

	Context "Return Object Structure" {
		It "Returns an object with PSTypeName SqlLabDataGenerator.AIProviderInfo" {
			$result = Get-SldgAIProvider
			$result.PSObject.TypeNames | Should -Contain 'SqlLabDataGenerator.AIProviderInfo'
		}

		It "Contains Provider property" {
			$result = Get-SldgAIProvider
			$result.PSObject.Properties.Name | Should -Contain 'Provider'
		}

		It "Contains Model property" {
			$result = Get-SldgAIProvider
			$result.PSObject.Properties.Name | Should -Contain 'Model'
		}

		It "Contains Endpoint property" {
			$result = Get-SldgAIProvider
			$result.PSObject.Properties.Name | Should -Contain 'Endpoint'
		}

		It "Contains ApiKeySet property" {
			$result = Get-SldgAIProvider
			$result.PSObject.Properties.Name | Should -Contain 'ApiKeySet'
		}

		It "Contains MaxTokens property" {
			$result = Get-SldgAIProvider
			$result.PSObject.Properties.Name | Should -Contain 'MaxTokens'
		}

		It "Contains Temperature property" {
			$result = Get-SldgAIProvider
			$result.PSObject.Properties.Name | Should -Contain 'Temperature'
		}
	}

	Context "Default Values" {
		BeforeAll {
			& $module { Set-PSFConfig -FullName 'SqlLabDataGenerator.AI.Provider' -Value 'None' }
		}

		It "Returns None as default provider" {
			$result = Get-SldgAIProvider
			$result.Provider | Should -Be 'None'
		}

		It "Shows ApiKeySet as false when no key is configured" {
			& $module { Set-PSFConfig -FullName 'SqlLabDataGenerator.AI.ApiKey' -Value $null }
			$result = Get-SldgAIProvider
			$result.ApiKeySet | Should -BeFalse
		}
	}

	Context "After Configuring Provider" {
		It "Reflects Ollama configuration" {
			& $module {
				Set-PSFConfig -FullName 'SqlLabDataGenerator.AI.Provider' -Value 'Ollama'
				Set-PSFConfig -FullName 'SqlLabDataGenerator.AI.Model' -Value 'llama3'
				Set-PSFConfig -FullName 'SqlLabDataGenerator.AI.Endpoint' -Value 'http://localhost:11434'
			}
			$result = Get-SldgAIProvider
			$result.Provider | Should -Be 'Ollama'
			$result.Model | Should -Be 'llama3'
			$result.Endpoint | Should -Be 'http://localhost:11434'
		}

		AfterAll {
			& $module { Set-PSFConfig -FullName 'SqlLabDataGenerator.AI.Provider' -Value 'None' }
		}
	}
}
