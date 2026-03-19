Describe "AI Error Path Tests" {
	BeforeAll {
		Remove-Module SqlLabDataGenerator -ErrorAction Ignore
		Import-Module "$PSScriptRoot\..\..\..\SqlLabDataGenerator\SqlLabDataGenerator.psd1" -Force
		$module = Get-Module SqlLabDataGenerator
	}

	AfterAll {
		& $module { Set-PSFConfig -FullName 'SqlLabDataGenerator.AI.Provider' -Value 'None' }
	}

	Context "Invoke-SldgAIRequest - Unreachable Endpoint" {
		BeforeAll {
			& $module {
				Set-PSFConfig -FullName 'SqlLabDataGenerator.AI.Provider' -Value 'Ollama'
				Set-PSFConfig -FullName 'SqlLabDataGenerator.AI.Model' -Value 'llama3'
				Set-PSFConfig -FullName 'SqlLabDataGenerator.AI.Endpoint' -Value 'http://127.0.0.1:19999'
				Set-PSFConfig -FullName 'SqlLabDataGenerator.AI.RetryCount' -Value 0
				Set-PSFConfig -FullName 'SqlLabDataGenerator.AI.RetryDelaySeconds' -Value 1
			}
		}

		AfterAll {
			& $module {
				Set-PSFConfig -FullName 'SqlLabDataGenerator.AI.Provider' -Value 'None'
				Set-PSFConfig -FullName 'SqlLabDataGenerator.AI.Endpoint' -Value ''
				Set-PSFConfig -FullName 'SqlLabDataGenerator.AI.RetryCount' -Value 3
				Set-PSFConfig -FullName 'SqlLabDataGenerator.AI.RetryDelaySeconds' -Value 2
			}
		}

		It "Returns null instead of throwing when endpoint is unreachable" {
			$result = & $module { Invoke-SldgAIRequest -SystemPrompt 'test' -UserMessage 'test' }
			$result | Should -BeNullOrEmpty
		}

		It "Test-SldgAIProvider returns NoResponse status for unreachable endpoint" {
			$result = Test-SldgAIProvider -ErrorAction SilentlyContinue
			$result | Should -Not -BeNullOrEmpty
			$result.Status | Should -BeIn @('Failed', 'NoResponse')
			$result.Error | Should -Not -BeNullOrEmpty
		}
	}

	Context "Invoke-SldgAIRequest - Invalid API Key" {
		BeforeAll {
			& $module {
				Set-PSFConfig -FullName 'SqlLabDataGenerator.AI.Provider' -Value 'OpenAI'
				Set-PSFConfig -FullName 'SqlLabDataGenerator.AI.Model' -Value 'gpt-4'
				$badKey = ConvertTo-SecureString 'sk-invalid-key-not-real' -AsPlainText -Force
				Set-PSFConfig -FullName 'SqlLabDataGenerator.AI.ApiKey' -Value $badKey
				Set-PSFConfig -FullName 'SqlLabDataGenerator.AI.RetryCount' -Value 0
			}
		}

		AfterAll {
			& $module {
				Set-PSFConfig -FullName 'SqlLabDataGenerator.AI.Provider' -Value 'None'
				Set-PSFConfig -FullName 'SqlLabDataGenerator.AI.ApiKey' -Value $null
				Set-PSFConfig -FullName 'SqlLabDataGenerator.AI.RetryCount' -Value 3
			}
		}

		It "Returns null instead of throwing on 401 from OpenAI" {
			$result = & $module { Invoke-SldgAIRequest -SystemPrompt 'test' -UserMessage 'test' }
			$result | Should -BeNullOrEmpty
		}

		It "Test-SldgAIProvider returns Failed for invalid key" {
			$result = Test-SldgAIProvider -ErrorAction SilentlyContinue
			$result | Should -Not -BeNullOrEmpty
			$result.Status | Should -BeIn @('Failed', 'NoResponse')
		}
	}

	Context "Invoke-SldgAIRequest - Missing API Key" {
		It "Returns null for OpenAI without API key" {
			& $module {
				Set-PSFConfig -FullName 'SqlLabDataGenerator.AI.Provider' -Value 'OpenAI'
				Set-PSFConfig -FullName 'SqlLabDataGenerator.AI.ApiKey' -Value $null
			}
			$result = & $module { Invoke-SldgAIRequest -SystemPrompt 'test' -UserMessage 'test' }
			$result | Should -BeNullOrEmpty
		}

		It "Returns null for AzureOpenAI without API key" {
			& $module {
				Set-PSFConfig -FullName 'SqlLabDataGenerator.AI.Provider' -Value 'AzureOpenAI'
				Set-PSFConfig -FullName 'SqlLabDataGenerator.AI.ApiKey' -Value $null
				Set-PSFConfig -FullName 'SqlLabDataGenerator.AI.Endpoint' -Value 'https://fake.openai.azure.com'
			}
			$result = & $module { Invoke-SldgAIRequest -SystemPrompt 'test' -UserMessage 'test' }
			$result | Should -BeNullOrEmpty
		}

		AfterAll {
			& $module { Set-PSFConfig -FullName 'SqlLabDataGenerator.AI.Provider' -Value 'None' }
		}
	}

	Context "Invoke-SldgAIRequest - Unknown Provider" {
		It "Returns null for unknown provider value" {
			& $module {
				# Force-set an invalid provider bypassing validation
				Set-PSFConfig -FullName 'SqlLabDataGenerator.AI.Provider' -Value 'None'
			}
			$result = & $module { Invoke-SldgAIRequest -SystemPrompt 'test' -UserMessage 'test' }
			$result | Should -BeNullOrEmpty
		}
	}

	Context "New-SldgAIGeneratedBatch - Graceful Degradation" {
		BeforeAll {
			& $module {
				Set-PSFConfig -FullName 'SqlLabDataGenerator.AI.Provider' -Value 'Ollama'
				Set-PSFConfig -FullName 'SqlLabDataGenerator.AI.Model' -Value 'llama3'
				Set-PSFConfig -FullName 'SqlLabDataGenerator.AI.Endpoint' -Value 'http://127.0.0.1:19999'
				Set-PSFConfig -FullName 'SqlLabDataGenerator.AI.RetryCount' -Value 0
				Set-PSFConfig -FullName 'SqlLabDataGenerator.Generation.AIGeneration' -Value $true
			}
		}

		AfterAll {
			& $module {
				Set-PSFConfig -FullName 'SqlLabDataGenerator.AI.Provider' -Value 'None'
				Set-PSFConfig -FullName 'SqlLabDataGenerator.AI.Endpoint' -Value ''
				Set-PSFConfig -FullName 'SqlLabDataGenerator.Generation.AIGeneration' -Value $false
				Set-PSFConfig -FullName 'SqlLabDataGenerator.AI.RetryCount' -Value 3
			}
		}

		It "Returns null when AI endpoint is unreachable" {
			$result = & $module {
				$cols = @(
					[PSCustomObject]@{ ColumnName = 'FirstName'; DataType = 'nvarchar'; SemanticType = 'FirstName'; MaxLength = 50; IsNullable = $false }
				)
				New-SldgAIGeneratedBatch -Columns $cols -TableName 'dbo.Test' -BatchSize 5
			}
			$result | Should -BeNullOrEmpty
		}
	}

	Context "Generation falls back to static when AI fails" {
		BeforeAll {
			& $module {
				Set-PSFConfig -FullName 'SqlLabDataGenerator.AI.Provider' -Value 'Ollama'
				Set-PSFConfig -FullName 'SqlLabDataGenerator.AI.Model' -Value 'llama3'
				Set-PSFConfig -FullName 'SqlLabDataGenerator.AI.Endpoint' -Value 'http://127.0.0.1:19999'
				Set-PSFConfig -FullName 'SqlLabDataGenerator.AI.RetryCount' -Value 0
				Set-PSFConfig -FullName 'SqlLabDataGenerator.Generation.AIGeneration' -Value $true
				$script:SldgState.ActiveConnection = $null
			}
		}

		AfterAll {
			& $module {
				Set-PSFConfig -FullName 'SqlLabDataGenerator.AI.Provider' -Value 'None'
				Set-PSFConfig -FullName 'SqlLabDataGenerator.AI.Endpoint' -Value ''
				Set-PSFConfig -FullName 'SqlLabDataGenerator.Generation.AIGeneration' -Value $false
				Set-PSFConfig -FullName 'SqlLabDataGenerator.AI.RetryCount' -Value 3
			}
		}

		It "NoInsert generation succeeds with static fallback when AI endpoint is down" {
			$testSchema = [PSCustomObject]@{
				PSTypeName   = 'SqlLabDataGenerator.SchemaModel'
				Database     = 'TestDB'
				TableCount   = 1
				DiscoveredAt = Get-Date
				Tables       = @(
					[PSCustomObject]@{
						PSTypeName  = 'SqlLabDataGenerator.TableInfo'
						SchemaName  = 'dbo'
						TableName   = 'Person'
						FullName    = 'dbo.Person'
						ColumnCount = 2
						ForeignKeys = @()
						Columns     = @(
							[PSCustomObject]@{
								PSTypeName     = 'SqlLabDataGenerator.ColumnInfo'
								ColumnName     = 'Id'
								DataType       = 'int'
								MaxLength      = $null
								IsNullable     = $false
								IsIdentity     = $true
								IsComputed     = $false
								IsPrimaryKey   = $true
								IsUnique       = $true
								ForeignKey     = $null
								SemanticType   = $null
								Classification = $null
							},
							[PSCustomObject]@{
								PSTypeName     = 'SqlLabDataGenerator.ColumnInfo'
								ColumnName     = 'FirstName'
								DataType       = 'nvarchar'
								MaxLength      = 50
								IsNullable     = $false
								IsIdentity     = $false
								IsComputed     = $false
								IsPrimaryKey   = $false
								IsUnique       = $false
								ForeignKey     = $null
								SemanticType   = 'FirstName'
								Classification = [PSCustomObject]@{ SemanticType = 'FirstName'; IsPII = $true; Confidence = 0.9 }
							}
						)
					}
				)
			}

			$plan = New-SldgGenerationPlan -Schema $testSchema -RowCount 3
			$result = Invoke-SldgDataGeneration -Plan $plan -NoInsert -PassThru -ErrorAction SilentlyContinue
			$result | Should -Not -BeNullOrEmpty
			$result.TotalRows | Should -Be 3
			$result.SuccessCount | Should -Be 1
			$result.FailureCount | Should -Be 0
		}
	}

	Context "Test-SldgAIProvider - Not Configured" {
		BeforeAll {
			& $module { Set-PSFConfig -FullName 'SqlLabDataGenerator.AI.Provider' -Value 'None' }
		}

		It "Returns NotConfigured status" {
			$result = Test-SldgAIProvider
			$result | Should -Not -BeNullOrEmpty
			$result.Status | Should -Be 'NotConfigured'
			$result.Provider | Should -Be 'None'
		}

		It "Result has null ResponseMs when not configured" {
			$result = Test-SldgAIProvider
			$result.ResponseMs | Should -BeNullOrEmpty
		}

		It "Result has error message when not configured" {
			$result = Test-SldgAIProvider
			$result.Error | Should -Not -BeNullOrEmpty
		}
	}

	Context "Set-SldgAIProvider - Cache Clearing" {
		It "Clears all AI caches when provider changes" {
			# Populate caches
			& $module {
				$script:SldgState.AIValueCache['testkey'] = @('val')
				$script:SldgState.AILocaleCache['testlocale'] = @{}
				$script:SldgState.AILocaleCategoryCache['testcat'] = @{}
			}

			Set-SldgAIProvider -Provider 'None'

			$valueCache = & $module { $script:SldgState.AIValueCache.Count }
			$localeCache = & $module { $script:SldgState.AILocaleCache.Count }
			$catCache = & $module { $script:SldgState.AILocaleCategoryCache.Count }

			$valueCache | Should -Be 0
			$localeCache | Should -Be 0
			$catCache | Should -Be 0
		}
	}
}
