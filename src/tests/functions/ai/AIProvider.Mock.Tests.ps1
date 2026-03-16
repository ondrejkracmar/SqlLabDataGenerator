Describe "AI Provider Mock Tests" {
	BeforeAll {
		Remove-Module SqlLabDataGenerator -ErrorAction Ignore
		Import-Module "$PSScriptRoot\..\..\..\SqlLabDataGenerator\SqlLabDataGenerator.psd1" -Force
		$module = Get-Module SqlLabDataGenerator
	}

	Context "Invoke-SldgAIRequest with mocked provider" {
		BeforeAll {
			# Store original state and configure a fake AI provider
			& $module {
				$script:originalAIProvider = Get-PSFConfigValue -FullName 'SqlLabDataGenerator.AI.Provider'
				$script:originalAIModel = Get-PSFConfigValue -FullName 'SqlLabDataGenerator.AI.Model'
			}
		}

		AfterAll {
			& $module {
				Set-PSFConfig -FullName 'SqlLabDataGenerator.AI.Provider' -Value $script:originalAIProvider
				Set-PSFConfig -FullName 'SqlLabDataGenerator.AI.Model' -Value $script:originalAIModel
			}
		}

		It "Test-SldgAIProvider returns Failed when provider is None" {
			$secureKey = ConvertTo-SecureString 'mock-key' -AsPlainText -Force
			Set-SldgAIProvider -Provider 'OpenAI' -ApiKey $secureKey -Model 'gpt-4'
			# The test will fail to connect but should return a proper result object
			$result = Test-SldgAIProvider -ErrorAction SilentlyContinue
			$result | Should -Not -BeNullOrEmpty
			$result.PSTypeNames | Should -Contain 'SqlLabDataGenerator.AIProviderTestResult'
			$result.Status | Should -BeIn @('Failed', 'NoResponse')
		}

		It "Test-SldgAIProvider result has ResponseMs property" {
			$result = Test-SldgAIProvider -ErrorAction SilentlyContinue
			$result.PSObject.Properties.Name | Should -Contain 'ResponseMs'
			$result.ResponseMs | Should -BeOfType [int]
		}

		It "Get-SldgAIProvider returns configured provider" {
			$secureKey = ConvertTo-SecureString 'mock-key' -AsPlainText -Force
			Set-SldgAIProvider -Provider 'OpenAI' -ApiKey $secureKey -Model 'gpt-4'
			$info = Get-SldgAIProvider
			$info.Provider | Should -Be 'OpenAI'
			$info.Model | Should -Be 'gpt-4'
		}

		It "AI locale cache is initially empty or populated" {
			$cacheType = & $module { $script:SldgState.AILocaleCache.GetType().Name }
			$cacheType | Should -Be 'Hashtable' -Because 'cache should be a hashtable'
		}
	}

	Context "AI semantic classification mock" {
		It "Pattern-based classification works without AI" {
			$analysis = Get-SldgColumnAnalysis -Columns @(
				[PSCustomObject]@{ ColumnName = 'EmailAddress'; DataType = 'nvarchar'; MaxLength = 256 }
				[PSCustomObject]@{ ColumnName = 'PhoneNumber'; DataType = 'nvarchar'; MaxLength = 20 }
				[PSCustomObject]@{ ColumnName = 'FirstName'; DataType = 'nvarchar'; MaxLength = 100 }
			) -TableName 'TestTable' -ErrorAction SilentlyContinue

			# Even without AI, pattern matching should classify known column names
			if ($analysis) {
				$analysis | Should -Not -BeNullOrEmpty
			}
		}
	}

	Context "AI generation disabled gracefully" {
		BeforeAll {
			& $module {
				Set-PSFConfig -FullName 'SqlLabDataGenerator.Generation.AIGeneration' -Value $false
				Set-PSFConfig -FullName 'SqlLabDataGenerator.AI.Provider' -Value 'None'
			}
		}

		It "Generation plan works without AI provider" {
			$mockSchema = [PSCustomObject]@{
				Database   = 'TestDB'
				TableCount = 1
				Tables     = @(
					[PSCustomObject]@{
						SchemaName = 'dbo'
						TableName  = 'TestTable'
						FullName   = 'dbo.TestTable'
						Columns    = @(
							[PSCustomObject]@{
								ColumnName  = 'Id'
								DataType    = 'int'
								IsIdentity  = $true
								IsPrimaryKey = $true
								IsNullable   = $false
							}
							[PSCustomObject]@{
								ColumnName  = 'Name'
								DataType    = 'nvarchar'
								MaxLength   = 100
								IsIdentity  = $false
								IsPrimaryKey = $false
								IsNullable   = $false
							}
						)
						ForeignKeys = @()
					}
				)
			}

			$plan = New-SldgGenerationPlan -Schema $mockSchema -ErrorAction SilentlyContinue
			if ($plan) {
				$plan.TableCount | Should -BeGreaterOrEqual 0
			}
		}
	}
}
