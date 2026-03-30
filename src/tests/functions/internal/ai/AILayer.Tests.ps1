Describe "AI Layer Tests" {
	BeforeAll {
		Remove-Module SqlLabDataGenerator -ErrorAction Ignore
		Import-Module "$PSScriptRoot\..\..\..\..\SqlLabDataGenerator\SqlLabDataGenerator.psd1" -Force
		$module = Get-Module SqlLabDataGenerator
	}

	AfterAll {
		& $module { Set-PSFConfig -FullName 'SqlLabDataGenerator.AI.Provider' -Value 'None' }
	}

	Context "Invoke-SldgAIRequest - Provider Validation" {
		It "Returns null when provider is None" {
			& $module { Set-PSFConfig -FullName 'SqlLabDataGenerator.AI.Provider' -Value 'None' }
			$result = & $module { Invoke-SldgAIRequest -SystemPrompt 'test' -UserMessage 'test' }
			$result | Should -BeNullOrEmpty
		}

		It "Returns null when OpenAI has no API key" {
			& $module {
				Set-PSFConfig -FullName 'SqlLabDataGenerator.AI.Provider' -Value 'OpenAI'
				Set-PSFConfig -FullName 'SqlLabDataGenerator.AI.ApiKey' -Value $null
			}
			$result = & $module { Invoke-SldgAIRequest -SystemPrompt 'test' -UserMessage 'test' }
			$result | Should -BeNullOrEmpty
		}

		It "Returns null when AzureOpenAI has no API key" {
			& $module {
				Set-PSFConfig -FullName 'SqlLabDataGenerator.AI.Provider' -Value 'AzureOpenAI'
				Set-PSFConfig -FullName 'SqlLabDataGenerator.AI.ApiKey' -Value $null
			}
			$result = & $module { Invoke-SldgAIRequest -SystemPrompt 'test' -UserMessage 'test' }
			$result | Should -BeNullOrEmpty
		}

		AfterAll {
			& $module { Set-PSFConfig -FullName 'SqlLabDataGenerator.AI.Provider' -Value 'None' }
		}
	}

	Context "Invoke-SldgAIRequest - Retry and Rate Limiting Config" {
		BeforeAll {
			& $module { Set-PSFConfig -FullName 'SqlLabDataGenerator.AI.RetryCount' -Value 3 }
			& $module { Set-PSFConfig -FullName 'SqlLabDataGenerator.AI.RetryDelaySeconds' -Value 2 }
		}

		It "Has retry configuration defaults" {
			$retryCount = & $module { Get-PSFConfigValue -FullName 'SqlLabDataGenerator.AI.RetryCount' }
			$retryCount | Should -Be 3

			$retryDelay = & $module { Get-PSFConfigValue -FullName 'SqlLabDataGenerator.AI.RetryDelaySeconds' }
			$retryDelay | Should -Be 2

			$timeout = & $module { Get-PSFConfigValue -FullName 'SqlLabDataGenerator.AI.TimeoutSeconds' }
			$timeout | Should -Be 120

			$rateLimit = & $module { Get-PSFConfigValue -FullName 'SqlLabDataGenerator.AI.RateLimitPerMinute' }
			$rateLimit | Should -Be 30
		}
	}

	Context "Invoke-SldgAIRequest - Rate Limiting" {
		It "Tracks request timestamps in SldgState" {
			& $module {
				while ($script:SldgState.AIRequestTimestamps.TryDequeue([ref]$null)) { }
			}
			$type = & $module { $script:SldgState.AIRequestTimestamps.GetType().Name }
			$type | Should -Be 'ConcurrentQueue`1'
			$count = & $module { $script:SldgState.AIRequestTimestamps.Count }
			$count | Should -Be 0
		}
	}

	Context "New-SldgAIGeneratedBatch - Input Validation" {
		BeforeAll {
			& $module { Set-PSFConfig -FullName 'SqlLabDataGenerator.AI.Provider' -Value 'None' }
		}

		It "Returns null when AI provider is None" {
			$cols = @(
				[PSCustomObject]@{ ColumnName = 'FirstName'; DataType = 'nvarchar'; SemanticType = 'FirstName'; MaxLength = 50; IsNullable = $false }
			)
			$result = & $module { param($c) New-SldgAIGeneratedBatch -Columns $c -TableName 'dbo.Test' -BatchSize 5 } (,$cols)
			$result | Should -BeNullOrEmpty
		}
	}

	Context "Get-SldgAIColumnAnalysis - No AI Provider" {
		BeforeAll {
			& $module { Set-PSFConfig -FullName 'SqlLabDataGenerator.AI.Provider' -Value 'None' }
		}

		It "Returns null when AI is not configured" {
			$schemaModel = [PSCustomObject]@{
				Database   = 'TestDB'
				Tables     = @()
				TableCount = 0
			}
			$result = & $module { param($s) Get-SldgAIColumnAnalysis -SchemaModel $s } $schemaModel
			$result | Should -BeNullOrEmpty
		}
	}

	Context "Get-SldgAIPlanAdvice - No AI Provider" {
		BeforeAll {
			& $module { Set-PSFConfig -FullName 'SqlLabDataGenerator.AI.Provider' -Value 'None' }
		}

		It "Returns null when AI is not configured" {
			$schemaModel = [PSCustomObject]@{
				Database   = 'TestDB'
				Tables     = @()
				TableCount = 0
			}
			$result = & $module { param($s) Get-SldgAIPlanAdvice -SchemaModel $s -BaseRowCount 100 } $schemaModel
			$result | Should -BeNullOrEmpty
		}
	}

	Context "AI Value Cache" {
		It "Uses cached AI batch when available" {
			$cacheKey = "dbo.Test|FirstName:FirstName|en-US"
			$cachedData = @(
				@{ FirstName = 'John' },
				@{ FirstName = 'Jane' },
				@{ FirstName = 'Bob' },
				@{ FirstName = 'Alice' },
				@{ FirstName = 'Eve' }
			)
			& $module { param($k, $d) $script:SldgState.AIValueCache[$k] = $d } $cacheKey (,$cachedData)

			$cached = & $module { param($k) $script:SldgState.AIValueCache[$k] } $cacheKey
			$cached | Should -Not -BeNullOrEmpty
			$cached.Count | Should -Be 5
		}

		It "Clears AI cache when provider changes" {
			& $module { $script:SldgState.AIValueCache['test'] = @('data') }
			Set-SldgAIProvider -Provider 'None'
			$cache = & $module { $script:SldgState.AIValueCache }
			$cache.Count | Should -Be 0
		}
	}
}
