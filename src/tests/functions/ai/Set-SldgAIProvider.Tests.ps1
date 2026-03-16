Describe "Set-SldgAIProvider" {
	BeforeAll {
		Remove-Module SqlLabDataGenerator -ErrorAction Ignore
		Import-Module "$PSScriptRoot\..\..\..\SqlLabDataGenerator\SqlLabDataGenerator.psd1" -Force
		$module = Get-Module SqlLabDataGenerator
	}

	AfterAll {
		& $module { Set-PSFConfig -FullName 'SqlLabDataGenerator.AI.Provider' -Value 'None' }
	}

	Context "Parameter Validation" {
		It "Has mandatory Provider parameter" {
			$cmd = Get-Command Set-SldgAIProvider
			$cmd.Parameters['Provider'].Attributes.Where({ $_ -is [System.Management.Automation.ParameterAttribute] }).Mandatory | Should -BeTrue
		}

		It "Provider parameter validates against known values" {
			$cmd = Get-Command Set-SldgAIProvider
			$validateSet = $cmd.Parameters['Provider'].Attributes.Where({ $_ -is [System.Management.Automation.ValidateSetAttribute] })
			$validateSet | Should -Not -BeNullOrEmpty
			$validateSet.ValidValues | Should -Contain 'Ollama'
			$validateSet.ValidValues | Should -Contain 'OpenAI'
			$validateSet.ValidValues | Should -Contain 'AzureOpenAI'
			$validateSet.ValidValues | Should -Contain 'None'
		}

		It "ApiKey parameter accepts SecureString" {
			$cmd = Get-Command Set-SldgAIProvider
			$cmd.Parameters['ApiKey'].ParameterType.Name | Should -Be 'SecureString'
		}

		It "Credential parameter accepts PSCredential" {
			$cmd = Get-Command Set-SldgAIProvider
			$cmd.Parameters['Credential'].ParameterType.Name | Should -Be 'PSCredential'
		}

		It "Has EnableAIGeneration switch parameter" {
			$cmd = Get-Command Set-SldgAIProvider
			$cmd.Parameters['EnableAIGeneration'].SwitchParameter | Should -BeTrue
		}

		It "Has EnableAILocale switch parameter" {
			$cmd = Get-Command Set-SldgAIProvider
			$cmd.Parameters['EnableAILocale'].SwitchParameter | Should -BeTrue
		}

		It "Has SkipCertificateCheck switch parameter" {
			$cmd = Get-Command Set-SldgAIProvider
			$cmd.Parameters['SkipCertificateCheck'].SwitchParameter | Should -BeTrue
		}
	}

	Context "Configuration Persistence" {
		It "Sets Ollama provider configuration" {
			Set-SldgAIProvider -Provider Ollama -Model 'llama3' -Endpoint 'http://localhost:11434'
			$provider = & $module { Get-PSFConfigValue -FullName 'SqlLabDataGenerator.AI.Provider' }
			$provider | Should -Be 'Ollama'
		}

		It "Stores model name" {
			$model = & $module { Get-PSFConfigValue -FullName 'SqlLabDataGenerator.AI.Model' }
			$model | Should -Be 'llama3'
		}

		It "Stores endpoint URL" {
			$endpoint = & $module { Get-PSFConfigValue -FullName 'SqlLabDataGenerator.AI.Endpoint' }
			$endpoint | Should -Be 'http://localhost:11434'
		}

		It "Stores MaxTokens value" {
			Set-SldgAIProvider -Provider Ollama -MaxTokens 2048
			$maxTokens = & $module { Get-PSFConfigValue -FullName 'SqlLabDataGenerator.AI.MaxTokens' }
			$maxTokens | Should -Be 2048
		}

		It "Stores Temperature value" {
			Set-SldgAIProvider -Provider Ollama -Temperature 0.7
			$temp = & $module { Get-PSFConfigValue -FullName 'SqlLabDataGenerator.AI.Temperature' }
			$temp | Should -Be 0.7
		}
	}

	Context "Provider Reset" {
		It "Setting provider to None clears configuration" {
			Set-SldgAIProvider -Provider None
			$provider = & $module { Get-PSFConfigValue -FullName 'SqlLabDataGenerator.AI.Provider' }
			$provider | Should -Be 'None'
		}
	}

	Context "Cache Clearing" {
		It "Clears AI caches when provider changes" {
			& $module {
				$script:SldgState.AIValueCache['test'] = 'value'
				$script:SldgState.Caches.SemanticTypeCache['test'] = 'value'
			}
			Set-SldgAIProvider -Provider Ollama
			$valueCache = & $module { $script:SldgState.AIValueCache.Count }
			$semanticCache = & $module { $script:SldgState.Caches.SemanticTypeCache.Count }
			$valueCache | Should -Be 0
			$semanticCache | Should -Be 0
		}
	}

	Context "Credential Handling" {
		It "Stores API key as SecureString" {
			$secureKey = ConvertTo-SecureString 'test-key-123' -AsPlainText -Force
			Set-SldgAIProvider -Provider OpenAI -ApiKey $secureKey
			$storedKey = & $module { Get-PSFConfigValue -FullName 'SqlLabDataGenerator.AI.ApiKey' }
			$storedKey | Should -BeOfType [SecureString]
		}

		It "Stores credential password as API key" {
			$securePassword = ConvertTo-SecureString 'cred-key-456' -AsPlainText -Force
			$credential = [PSCredential]::new('apiuser', $securePassword)
			Set-SldgAIProvider -Provider OpenAI -Credential $credential
			$storedKey = & $module { Get-PSFConfigValue -FullName 'SqlLabDataGenerator.AI.ApiKey' }
			$storedKey | Should -BeOfType [SecureString]
		}

		AfterAll {
			& $module { Set-PSFConfig -FullName 'SqlLabDataGenerator.AI.Provider' -Value 'None' }
		}
	}
}
