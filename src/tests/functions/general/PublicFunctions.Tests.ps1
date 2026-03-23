Describe "Public Functions - Configuration" {
	BeforeAll {
		Remove-Module SqlLabDataGenerator -ErrorAction Ignore
		Import-Module "$PSScriptRoot\..\..\..\SqlLabDataGenerator\SqlLabDataGenerator.psd1" -Force
		$module = Get-Module SqlLabDataGenerator
	}

	Context "Set-SldgAIProvider" {
		It "Sets AI provider to OpenAI" {
			$secureKey = ConvertTo-SecureString 'test-key' -AsPlainText -Force
			Set-SldgAIProvider -Provider 'OpenAI' -ApiKey $secureKey -Model 'gpt-4'
			$info = Get-SldgAIProvider
			$info.Provider | Should -Be 'OpenAI'
			$info.Model | Should -Be 'gpt-4'
		}

		It "Sets AI provider to None" {
			Set-SldgAIProvider -Provider 'None'
			$info = Get-SldgAIProvider
			$info.Provider | Should -Be 'None'
		}

		It "Sets AI provider to Ollama" {
			Set-SldgAIProvider -Provider 'Ollama' -Model 'llama3' -Endpoint 'http://localhost:11434'
			$info = Get-SldgAIProvider
			$info.Provider | Should -Be 'Ollama'
			$info.Model | Should -Be 'llama3'
		}

		AfterAll {
			Set-SldgAIProvider -Provider 'None'
		}
	}

	Context "Get-SldgAIProvider" {
		It "Returns provider info object" {
			$info = Get-SldgAIProvider
			$info | Should -Not -BeNullOrEmpty
			$info.PSObject.Properties.Name | Should -Contain 'Provider'
			$info.PSObject.Properties.Name | Should -Contain 'Model'
		}
	}
}

Describe "Public Functions - Locale" {
	BeforeAll {
		Remove-Module SqlLabDataGenerator -ErrorAction Ignore
		Import-Module "$PSScriptRoot\..\..\..\SqlLabDataGenerator\SqlLabDataGenerator.psd1" -Force
		$module = Get-Module SqlLabDataGenerator
	}

	Context "Register-SldgLocale" {
		It "Registers a manual locale" {
			$data = @{
				MaleNames       = @('Test1', 'Test2')
				FemaleNames     = @('Test3', 'Test4')
				LastNames       = @('TestL1', 'TestL2')
				StreetNames     = @('TestSt')
				StreetTypes     = @('St')
				Locations       = @(@{ City = 'TestCity'; State = 'TS'; ZipPrefix = '000' })
				Countries       = @('TestCountry')
				EmailDomains    = @('test.com')
				PhoneFormat     = @{
					AreaCodes     = @('000')
					Formats       = @{ Standard = '{Area}{Exchange}{Subscriber}' }
					ExchangeMin   = 100
					ExchangeMax   = 999
					SubscriberMin = 1000
					SubscriberMax = 9999
				}
				CompanyPrefixes  = @('Test')
				CompanyCores     = @('Corp')
				CompanySuffixes  = @('Inc')
				Departments      = @('IT')
				JobTitles        = @('Dev')
				Industries       = @('Tech')
			}
			{ Register-SldgLocale -Name 'test-XX' -Data $data } | Should -Not -Throw
		}
	}

	Context "Built-in Locales" {
		It "Has en-US locale registered" {
			$locale = & $module { $script:SldgState.Locales['en-US'] }
			$locale | Should -Not -BeNullOrEmpty
			$locale['MaleNames'].Count | Should -BeGreaterThan 0
			$locale['FemaleNames'].Count | Should -BeGreaterThan 0
		}

		It "Has cs-CZ locale registered" {
			$locale = & $module { $script:SldgState.Locales['cs-CZ'] }
			$locale | Should -Not -BeNullOrEmpty
			$locale['MaleNames'].Count | Should -BeGreaterThan 0
		}
	}
}

Describe "Public Functions - Provider" {
	BeforeAll {
		Remove-Module SqlLabDataGenerator -ErrorAction Ignore
		Import-Module "$PSScriptRoot\..\..\..\SqlLabDataGenerator\SqlLabDataGenerator.psd1" -Force
		$module = Get-Module SqlLabDataGenerator
	}

	Context "Built-in Providers" {
		It "Has SqlServer provider registered" {
			$providers = & $module { $script:SldgState.Providers }
			$providers.ContainsKey('SqlServer') | Should -BeTrue
		}

		It "Has SQLite provider registered" {
			$providers = & $module { $script:SldgState.Providers }
			$providers.ContainsKey('SQLite') | Should -BeTrue
		}

		It "SqlServer provider has all 5 functions" {
			$provider = & $module { $script:SldgState.Providers['SqlServer'] }
			$provider.FunctionMap.Keys | Should -Contain 'Connect'
			$provider.FunctionMap.Keys | Should -Contain 'GetSchema'
			$provider.FunctionMap.Keys | Should -Contain 'WriteData'
			$provider.FunctionMap.Keys | Should -Contain 'ReadData'
			$provider.FunctionMap.Keys | Should -Contain 'Disconnect'
		}
	}

}

Describe "Public Functions - Generation" {
	BeforeAll {
		Remove-Module SqlLabDataGenerator -ErrorAction Ignore
		Import-Module "$PSScriptRoot\..\..\..\SqlLabDataGenerator\SqlLabDataGenerator.psd1" -Force
		$module = Get-Module SqlLabDataGenerator
	}

	Context "New-SldgGenerationPlan" {
		BeforeAll {
			$script:testSchema = [PSCustomObject]@{
				PSTypeName   = 'SqlLabDataGenerator.SchemaModel'
				Database     = 'TestDB'
				TableCount   = 1
				DiscoveredAt = Get-Date
				Tables       = @(
					[PSCustomObject]@{
						PSTypeName  = 'SqlLabDataGenerator.TableInfo'
						SchemaName  = 'dbo'
						TableName   = 'Customer'
						FullName    = 'dbo.Customer'
						ColumnCount = 3
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
								Classification = [PSCustomObject]@{ SemanticType = 'FirstName'; IsPII = $true; Confidence = 0.8 }
							},
							[PSCustomObject]@{
								PSTypeName     = 'SqlLabDataGenerator.ColumnInfo'
								ColumnName     = 'Email'
								DataType       = 'nvarchar'
								MaxLength      = 100
								IsNullable     = $true
								IsIdentity     = $false
								IsComputed     = $false
								IsPrimaryKey   = $false
								IsUnique       = $false
								ForeignKey     = $null
								SemanticType   = 'Email'
								Classification = [PSCustomObject]@{ SemanticType = 'Email'; IsPII = $true; Confidence = 0.8 }
							}
						)
					}
				)
			}
		}

		It "Creates a generation plan" {
			$plan = New-SldgGenerationPlan -Schema $testSchema -RowCount 10
			$plan | Should -Not -BeNullOrEmpty
			$plan.Database | Should -Be 'TestDB'
			$plan.TableCount | Should -Be 1
		}

		It "Plan has correct row count" {
			$plan = New-SldgGenerationPlan -Schema $testSchema -RowCount 50
			$plan.Tables[0].RowCount | Should -Be 50
			$plan.TotalRows | Should -Be 50
		}

		It "Plan has GenerationPlan type" {
			$plan = New-SldgGenerationPlan -Schema $testSchema -RowCount 10
			$plan.PSObject.TypeNames | Should -Contain 'SqlLabDataGenerator.GenerationPlan'
		}

		It "Plan columns have correct metadata" {
			$plan = New-SldgGenerationPlan -Schema $testSchema -RowCount 10
			$cols = $plan.Tables[0].Columns

			$idCol = $cols | Where-Object { $_.ColumnName -eq 'Id' }
			$idCol.IsPrimaryKey | Should -BeTrue

			$fnCol = $cols | Where-Object { $_.ColumnName -eq 'FirstName' }
			$fnCol.SemanticType | Should -Be 'FirstName'
		}
	}

	Context "Set-SldgGenerationRule" {
		It "Sets a ValueList rule" {
			$plan = New-SldgGenerationPlan -Schema $testSchema -RowCount 10
			{ Set-SldgGenerationRule -Plan $plan -TableName 'dbo.Customer' -ColumnName 'FirstName' -ValueList @('Alice', 'Bob') } | Should -Not -Throw
		}

		It "Sets a StaticValue rule" {
			$plan = New-SldgGenerationPlan -Schema $testSchema -RowCount 10
			{ Set-SldgGenerationRule -Plan $plan -TableName 'dbo.Customer' -ColumnName 'Email' -StaticValue 'test@test.com' } | Should -Not -Throw
		}
	}
}

Describe "Public Functions - Transformer" {
	BeforeAll {
		Remove-Module SqlLabDataGenerator -ErrorAction Ignore
		Import-Module "$PSScriptRoot\..\..\..\SqlLabDataGenerator\SqlLabDataGenerator.psd1" -Force
	}

	Context "Get-SldgTransformer" {
		It "Lists available transformers" {
			$result = Get-SldgTransformer
			$result | Should -Not -BeNullOrEmpty
		}

		It "Has EntraIdUser transformer" {
			$result = Get-SldgTransformer -Name 'EntraIdUser'
			$result | Should -Not -BeNullOrEmpty
			$result.Name | Should -Be 'EntraIdUser'
		}

		It "Has EntraIdGroup transformer" {
			$result = Get-SldgTransformer -Name 'EntraIdGroup'
			$result | Should -Not -BeNullOrEmpty
		}

		It "Supports wildcard filtering" {
			$result = Get-SldgTransformer -Name 'EntraId*'
			@($result).Count | Should -Be 2
		}
	}

	Context "Register-SldgTransformer" {
		It "Registers a custom transformer" {
			function ConvertTo-TestTransform { param($Data) $Data }
			{ Register-SldgTransformer -Name 'TestTransform' -Description 'Test' -TransformFunction 'ConvertTo-TestTransform' } | Should -Not -Throw
			$result = Get-SldgTransformer -Name 'TestTransform'
			$result.Name | Should -Be 'TestTransform'
		}
	}
}

Describe "Public Functions - Profile" {
	BeforeAll {
		Remove-Module SqlLabDataGenerator -ErrorAction Ignore
		Import-Module "$PSScriptRoot\..\..\..\SqlLabDataGenerator\SqlLabDataGenerator.psd1" -Force
		$module = Get-Module SqlLabDataGenerator

		$testSchema = [PSCustomObject]@{
			PSTypeName   = 'SqlLabDataGenerator.SchemaModel'
			Database     = 'TestDB'
			TableCount   = 1
			DiscoveredAt = Get-Date
			Tables       = @(
				[PSCustomObject]@{
					PSTypeName  = 'SqlLabDataGenerator.TableInfo'
					SchemaName  = 'dbo'
					TableName   = 'Customer'
					FullName    = 'dbo.Customer'
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
							ColumnName     = 'Name'
							DataType       = 'nvarchar'
							MaxLength      = 100
							IsNullable     = $false
							IsIdentity     = $false
							IsComputed     = $false
							IsPrimaryKey   = $false
							IsUnique       = $false
							ForeignKey     = $null
							SemanticType   = 'FullName'
							Classification = [PSCustomObject]@{ SemanticType = 'FullName'; IsPII = $true; Confidence = 0.8 }
						}
					)
				}
			)
		}
		$script:testPlan = New-SldgGenerationPlan -Schema $testSchema -RowCount 10
	}

	Context "Export-SldgGenerationProfile" {
		It "Exports a plan to JSON" {
			$tempFile = Join-Path $TestDrive 'test-profile.json'
			Export-SldgGenerationProfile -Plan $testPlan -Path $tempFile
			Test-Path $tempFile | Should -BeTrue
		}

		It "Exported JSON has valid structure" {
			$tempFile = Join-Path $TestDrive 'test-profile2.json'
			Export-SldgGenerationProfile -Plan $testPlan -Path $tempFile
			$json = Get-Content $tempFile -Raw | ConvertFrom-Json
			$json.database | Should -Be 'TestDB'
			$json.tables | Should -Not -BeNullOrEmpty
		}
	}

	Context "Import-SldgGenerationProfile" {
		It "Imports a profile and applies rules" {
			$tempFile = Join-Path $TestDrive 'import-profile.json'
			@{
				tables = @{
					'dbo.Customer' = @{
						rowCount = 200
						columns  = @{
							'Name' = @{ staticValue = 'TestName' }
						}
					}
				}
			} | ConvertTo-Json -Depth 10 | Set-Content -Path $tempFile -Encoding UTF8

			$plan = New-SldgGenerationPlan -Schema $testSchema -RowCount 10
			Import-SldgGenerationProfile -Path $tempFile -Plan $plan
			$plan.Tables[0].RowCount | Should -Be 200
		}
	}
}
