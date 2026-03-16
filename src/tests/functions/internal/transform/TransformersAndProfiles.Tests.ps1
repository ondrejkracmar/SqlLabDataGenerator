Describe "Transformer Tests" {
	BeforeAll {
		Remove-Module SqlLabDataGenerator -ErrorAction Ignore
		Import-Module "$PSScriptRoot\..\..\..\..\SqlLabDataGenerator\SqlLabDataGenerator.psd1" -Force
		$module = Get-Module SqlLabDataGenerator
	}

	Context "Get-SldgTransformer" {
		It "Returns built-in transformers" {
			$transformers = Get-SldgTransformer
			$transformers | Should -Not -BeNullOrEmpty
			$transformers.Count | Should -BeGreaterOrEqual 2
		}

		It "Contains EntraIdUser transformer" {
			$transformers = Get-SldgTransformer
			$transformers | Where-Object Name -eq 'EntraIdUser' | Should -Not -BeNullOrEmpty
		}

		It "Contains EntraIdGroup transformer" {
			$transformers = Get-SldgTransformer
			$transformers | Where-Object Name -eq 'EntraIdGroup' | Should -Not -BeNullOrEmpty
		}
	}

	Context "ConvertTo-SldgEntraIdUser" {
		BeforeAll {
			$script:testData = New-Object System.Data.DataTable
			[void]$script:testData.Columns.Add('FirstName', [string])
			[void]$script:testData.Columns.Add('LastName', [string])
			[void]$script:testData.Columns.Add('Email', [string])
			[void]$script:testData.Columns.Add('Phone', [string])
			[void]$script:testData.Columns.Add('Department', [string])

			$row = $script:testData.NewRow()
			$row['FirstName'] = 'John'
			$row['LastName'] = 'Doe'
			$row['Email'] = 'john.doe@test.com'
			$row['Phone'] = '+1-555-0100'
			$row['Department'] = 'Engineering'
			[void]$script:testData.Rows.Add($row)

			$row2 = $script:testData.NewRow()
			$row2['FirstName'] = 'Jane'
			$row2['LastName'] = 'Smith'
			$row2['Email'] = 'jane.smith@test.com'
			$row2['Phone'] = '+1-555-0200'
			$row2['Department'] = 'Marketing'
			[void]$script:testData.Rows.Add($row2)
		}

		It "Transforms data to EntraIdUser objects" {
			$result = & $module { param($d) ConvertTo-SldgEntraIdUser -Data $d } -ArgumentList $script:testData
			$result | Should -Not -BeNullOrEmpty
			@($result).Count | Should -Be 2
		}

		It "Sets correct displayName" {
			$result = & $module { param($d) ConvertTo-SldgEntraIdUser -Data $d } -ArgumentList $script:testData
			$result[0].displayName | Should -Be 'John Doe'
		}

		It "Generates userPrincipalName with domain" {
			$result = & $module { param($d) ConvertTo-SldgEntraIdUser -Data $d -Domain 'test.onmicrosoft.com' } -ArgumentList $script:testData
			$result[0].userPrincipalName | Should -Match '@test\.onmicrosoft\.com$'
		}

		It "Sets accountEnabled to true" {
			$result = & $module { param($d) ConvertTo-SldgEntraIdUser -Data $d } -ArgumentList $script:testData
			$result[0].accountEnabled | Should -BeTrue
		}

		It "Includes passwordProfile with forceChange" {
			$result = & $module { param($d) ConvertTo-SldgEntraIdUser -Data $d } -ArgumentList $script:testData
			$result[0].passwordProfile.forceChangePasswordNextSignIn | Should -BeTrue
		}

		It "Auto-detects column mappings for English column names" {
			$result = & $module { param($d) ConvertTo-SldgEntraIdUser -Data $d } -ArgumentList $script:testData
			$result[0].givenName | Should -Be 'John'
			$result[0].surname | Should -Be 'Doe'
		}

		It "Supports custom domain parameter" {
			$result = & $module { param($d) ConvertTo-SldgEntraIdUser -Data $d -Domain 'custom.com' } -ArgumentList $script:testData
			$result[0].userPrincipalName | Should -Match '@custom\.com$'
		}
	}

	Context "ConvertTo-SldgEntraIdGroup" {
		BeforeAll {
			$script:groupData = New-Object System.Data.DataTable
			[void]$script:groupData.Columns.Add('DepartmentName', [string])
			[void]$script:groupData.Columns.Add('Description', [string])

			$row = $script:groupData.NewRow()
			$row['DepartmentName'] = 'Engineering'
			$row['Description'] = 'Engineering department'
			[void]$script:groupData.Rows.Add($row)

			$row2 = $script:groupData.NewRow()
			$row2['DepartmentName'] = 'Marketing'
			$row2['Description'] = 'Marketing department'
			[void]$script:groupData.Rows.Add($row2)
		}

		It "Transforms data to EntraIdGroup objects" {
			$result = & $module { param($d) ConvertTo-SldgEntraIdGroup -Data $d } -ArgumentList $script:groupData
			$result | Should -Not -BeNullOrEmpty
			@($result).Count | Should -Be 2
		}

		It "Sets correct displayName" {
			$result = & $module { param($d) ConvertTo-SldgEntraIdGroup -Data $d } -ArgumentList $script:groupData
			$result[0].displayName | Should -Be 'Engineering'
		}

		It "Defaults to Security group type" {
			$result = & $module { param($d) ConvertTo-SldgEntraIdGroup -Data $d } -ArgumentList $script:groupData
			$result[0].securityEnabled | Should -BeTrue
			$result[0].mailEnabled | Should -BeFalse
		}

		It "Supports Microsoft365 group type" {
			$result = & $module { param($d) ConvertTo-SldgEntraIdGroup -Data $d -GroupType 'Microsoft365' } -ArgumentList $script:groupData
			$result[0].mailEnabled | Should -BeTrue
			$result[0].securityEnabled | Should -BeTrue
			$result[0].groupTypes | Should -Contain 'Unified'
		}

		It "Generates valid mailNickname" {
			$result = & $module { param($d) ConvertTo-SldgEntraIdGroup -Data $d } -ArgumentList $script:groupData
			$result[0].mailNickname | Should -Not -BeNullOrEmpty
			$result[0].mailNickname | Should -Match '^[a-z0-9]+$'
		}
	}

	Context "Export-SldgTransformedData - Validation" {
		It "Throws for unregistered transformer" {
			$dt = New-Object System.Data.DataTable
			{ Export-SldgTransformedData -Data $dt -Transformer 'NonExistent' } | Should -Throw
		}
	}

	Context "Register-SldgTransformer" {
		It "Registers a custom transformer" {
			{
				Register-SldgTransformer -Name 'TestTransformer' `
					-Description 'Test transformer' `
					-TransformFunction { param($Data) $Data } `
					-RequiredSemanticTypes @('Text') `
					-OutputType 'Test.Output'
			} | Should -Not -Throw
		}

		It "Custom transformer appears in Get-SldgTransformer" {
			$transformers = Get-SldgTransformer
			$transformers | Where-Object Name -eq 'TestTransformer' | Should -Not -BeNullOrEmpty
		}
	}
}

Describe "Profile Import/Export Tests" {
	BeforeAll {
		Remove-Module SqlLabDataGenerator -ErrorAction Ignore
		Import-Module "$PSScriptRoot\..\..\..\..\SqlLabDataGenerator\SqlLabDataGenerator.psd1" -Force
		$module = Get-Module SqlLabDataGenerator
	}

	Context "Export-SldgGenerationProfile" {
		BeforeAll {
			# Build a minimal plan object
			$script:testPlan = [PSCustomObject]@{
				PSTypeName      = 'SqlLabDataGenerator.GenerationPlan'
				Database        = 'TestDB'
				Mode            = 'Synthetic'
				Tables          = @(
					[PSCustomObject]@{
						PSTypeName  = 'SqlLabDataGenerator.TablePlan'
						Order       = 1
						SchemaName  = 'dbo'
						TableName   = 'Customer'
						FullName    = 'dbo.Customer'
						RowCount    = 100
						Columns     = @(
							[PSCustomObject]@{
								ColumnName   = 'FirstName'
								DataType     = 'nvarchar'
								SemanticType = 'FirstName'
								Generator    = 'New-SldgPersonName'
								IsPII        = $true
								IsPrimaryKey = $false
								IsUnique     = $false
								IsNullable   = $false
								MaxLength    = 50
								ForeignKey   = $null
								Skip         = $false
								CustomRule   = $null
							},
							[PSCustomObject]@{
								ColumnName   = 'Status'
								DataType     = 'nvarchar'
								SemanticType = 'Status'
								Generator    = 'New-SldgText'
								IsPII        = $false
								IsPrimaryKey = $false
								IsUnique     = $false
								IsNullable   = $true
								MaxLength    = 20
								ForeignKey   = $null
								Skip         = $false
								CustomRule   = @{ ValueList = @('Active', 'Inactive') }
							}
						)
						ForeignKeys = @()
						ColumnCount = 2
					}
				)
				TableCount      = 1
				TotalRows       = 100
				GeneratorMap    = @{}
				CreatedAt       = Get-Date
				GenerationRules = @{}
			}
			$script:exportPath = Join-Path $TestDrive 'test-profile.json'
		}

		It "Exports plan to JSON file" {
			{ Export-SldgGenerationProfile -Plan $script:testPlan -Path $script:exportPath } | Should -Not -Throw
			$script:exportPath | Should -Exist
		}

		It "Exported JSON is valid" {
			$content = Get-Content -Path $script:exportPath -Raw
			{ $content | ConvertFrom-Json } | Should -Not -Throw
		}

		It "Exported JSON contains table data" {
			$content = Get-Content -Path $script:exportPath -Raw | ConvertFrom-Json
			$content.tables.'dbo.Customer' | Should -Not -BeNullOrEmpty
			$content.tables.'dbo.Customer'.rowCount | Should -Be 100
		}

		It "Exported JSON contains column data" {
			$content = Get-Content -Path $script:exportPath -Raw | ConvertFrom-Json
			$content.tables.'dbo.Customer'.columns.FirstName | Should -Not -BeNullOrEmpty
			$content.tables.'dbo.Customer'.columns.FirstName.semanticType | Should -Be 'FirstName'
		}

		It "Exports ValueList custom rules" {
			$content = Get-Content -Path $script:exportPath -Raw | ConvertFrom-Json
			$content.tables.'dbo.Customer'.columns.Status.valueList | Should -Contain 'Active'
		}

		It "Includes PII flags with -IncludeSemanticAnalysis" {
			$piiPath = Join-Path $TestDrive 'test-profile-pii.json'
			Export-SldgGenerationProfile -Plan $script:testPlan -Path $piiPath -IncludeSemanticAnalysis
			$content = Get-Content -Path $piiPath -Raw | ConvertFrom-Json
			$content.tables.'dbo.Customer'.columns.FirstName.isPII | Should -BeTrue
		}
	}

	Context "Import-SldgGenerationProfile" {
		BeforeAll {
			# Create a profile JSON
			$profileContent = @{
				tables = @{
					'dbo.Customer' = @{
						rowCount = 500
						columns  = @{
							'Status' = @{
								valueList = @('Active', 'Inactive', 'Pending')
							}
							'Currency' = @{
								staticValue = 'USD'
							}
						}
					}
				}
			} | ConvertTo-Json -Depth 10
			$script:importPath = Join-Path $TestDrive 'import-profile.json'
			$profileContent | Set-Content -Path $script:importPath

			# Build a plan to apply the profile to
			$script:importPlan = [PSCustomObject]@{
				PSTypeName      = 'SqlLabDataGenerator.GenerationPlan'
				Database        = 'TestDB'
				Mode            = 'Synthetic'
				Tables          = @(
					[PSCustomObject]@{
						PSTypeName  = 'SqlLabDataGenerator.TablePlan'
						Order       = 1
						SchemaName  = 'dbo'
						TableName   = 'Customer'
						FullName    = 'dbo.Customer'
						RowCount    = 100
						Columns     = @(
							[PSCustomObject]@{ ColumnName = 'Status'; DataType = 'nvarchar'; SemanticType = 'Status' }
							[PSCustomObject]@{ ColumnName = 'Currency'; DataType = 'nvarchar'; SemanticType = 'Currency' }
						)
						ForeignKeys = @()
						ColumnCount = 2
					}
				)
				TableCount      = 1
				TotalRows       = 100
				GeneratorMap    = @{}
				CreatedAt       = Get-Date
				GenerationRules = @{}
			}
		}

		It "Imports profile without error" {
			{ Import-SldgGenerationProfile -Path $script:importPath -Plan $script:importPlan } | Should -Not -Throw
		}

		It "Updates row count from profile" {
			Import-SldgGenerationProfile -Path $script:importPath -Plan $script:importPlan
			$script:importPlan.Tables[0].RowCount | Should -Be 500
		}

		It "Updates TotalRows after import" {
			Import-SldgGenerationProfile -Path $script:importPath -Plan $script:importPlan
			$script:importPlan.TotalRows | Should -Be 500
		}

		It "Throws for non-existent file" {
			{ Import-SldgGenerationProfile -Path 'C:\nonexistent\file.json' -Plan $script:importPlan } | Should -Throw
		}
	}
}
