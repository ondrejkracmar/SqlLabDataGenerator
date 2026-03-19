Describe "Import-SldgGenerationProfile" {
	BeforeAll {
		Remove-Module SqlLabDataGenerator -ErrorAction Ignore
		Import-Module "$PSScriptRoot\..\..\..\SqlLabDataGenerator\SqlLabDataGenerator.psd1" -Force
		$module = Get-Module SqlLabDataGenerator
	}

	Context "Parameter Validation" {
		It "Has mandatory Path parameter" {
			$cmd = Get-Command Import-SldgGenerationProfile
			$cmd.Parameters['Path'].Attributes.Where({ $_ -is [System.Management.Automation.ParameterAttribute] }).Mandatory | Should -BeTrue
		}

		It "Path parameter has ValidateScript for file existence" {
			$cmd = Get-Command Import-SldgGenerationProfile
			$validateScript = $cmd.Parameters['Path'].Attributes.Where({ $_ -is [System.Management.Automation.ValidateScriptAttribute] })
			$validateScript | Should -Not -BeNullOrEmpty
		}

		It "Has mandatory Plan parameter" {
			$cmd = Get-Command Import-SldgGenerationProfile
			$cmd.Parameters['Plan'].Attributes.Where({ $_ -is [System.Management.Automation.ParameterAttribute] }).Mandatory | Should -BeTrue
		}
	}

	Context "Import Functionality" {
		BeforeAll {
			# Create a test plan
			$script:testPlan = [PSCustomObject]@{
				Database        = 'ImportTestDB'
				Mode            = 'Synthetic'
				TableCount      = 1
				TotalRows       = 10
				GenerationRules = @{}
				Tables          = @(
					[PSCustomObject]@{
						FullName   = 'dbo.Customer'
						SchemaName = 'dbo'
						TableName  = 'Customer'
						RowCount   = 10
						Columns    = @(
							[PSCustomObject]@{ ColumnName = 'Status'; DataType = 'nvarchar'; CustomRule = $null },
							[PSCustomObject]@{ ColumnName = 'Currency'; DataType = 'nvarchar'; CustomRule = $null }
						)
					}
				)
			}

			# Create a test profile JSON
			$script:profilePath = Join-Path $TestDrive 'test-profile.json'
			$profileContent = @{
				tables = @{
					'dbo.Customer' = @{
						rowCount = 500
						columns  = @{
							Status   = @{ valueList = @('Active', 'Inactive', 'Pending') }
							Currency = @{ staticValue = 'USD' }
						}
					}
				}
			}
			$profileContent | ConvertTo-Json -Depth 10 | Set-Content -Path $script:profilePath -Encoding UTF8
		}

		It "Imports profile without error" {
			{ Import-SldgGenerationProfile -Path $script:profilePath -Plan $script:testPlan } | Should -Not -Throw
		}

		It "Overrides row count from profile" {
			Import-SldgGenerationProfile -Path $script:profilePath -Plan $script:testPlan
			$script:testPlan.Tables[0].RowCount | Should -Be 500
		}

		It "Applies ValueList rule from profile" {
			Import-SldgGenerationProfile -Path $script:profilePath -Plan $script:testPlan
			$script:testPlan.GenerationRules['dbo.Customer']['Status'].ValueList | Should -Contain 'Active'
			$script:testPlan.GenerationRules['dbo.Customer']['Status'].ValueList | Should -Contain 'Inactive'
			$script:testPlan.GenerationRules['dbo.Customer']['Status'].ValueList | Should -Contain 'Pending'
		}

		It "Applies StaticValue rule from profile" {
			Import-SldgGenerationProfile -Path $script:profilePath -Plan $script:testPlan
			$script:testPlan.GenerationRules['dbo.Customer']['Currency'].StaticValue | Should -Be 'USD'
		}

		It "Throws when Path does not exist" {
			{ Import-SldgGenerationProfile -Path 'C:\nonexistent\fake.json' -Plan $script:testPlan } | Should -Throw
		}
	}

	Context "Profile With Generator Override" {
		BeforeAll {
			$script:genPlan = [PSCustomObject]@{
				Database        = 'GenTestDB'
				Mode            = 'Synthetic'
				TableCount      = 1
				TotalRows       = 10
				GenerationRules = @{}
				Tables          = @(
					[PSCustomObject]@{
						FullName   = 'dbo.Person'
						SchemaName = 'dbo'
						TableName  = 'Person'
						RowCount   = 10
						Columns    = @(
							[PSCustomObject]@{ ColumnName = 'Email'; DataType = 'nvarchar'; CustomRule = $null }
						)
					}
				)
			}

			$script:genProfilePath = Join-Path $TestDrive 'gen-profile.json'
			@{
				tables = @{
					'dbo.Person' = @{
						columns = @{
							Email = @{ generator = 'Email' }
						}
					}
				}
			} | ConvertTo-Json -Depth 10 | Set-Content -Path $script:genProfilePath -Encoding UTF8
		}

		It "Applies generator override from profile" {
			Import-SldgGenerationProfile -Path $script:genProfilePath -Plan $script:genPlan
			$script:genPlan.GenerationRules['dbo.Person']['Email'].Generator | Should -Be 'Email'
		}
	}
}
