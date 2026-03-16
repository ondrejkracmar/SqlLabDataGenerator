Describe "Export-SldgGenerationProfile" {
	BeforeAll {
		Remove-Module SqlLabDataGenerator -ErrorAction Ignore
		Import-Module "$PSScriptRoot\..\..\..\SqlLabDataGenerator\SqlLabDataGenerator.psd1" -Force
		$module = Get-Module SqlLabDataGenerator
	}

	Context "Parameter Validation" {
		It "Has mandatory Plan parameter" {
			$cmd = Get-Command Export-SldgGenerationProfile
			$cmd.Parameters['Plan'].Attributes.Where({ $_ -is [System.Management.Automation.ParameterAttribute] }).Mandatory | Should -BeTrue
		}

		It "Has mandatory Path parameter" {
			$cmd = Get-Command Export-SldgGenerationProfile
			$cmd.Parameters['Path'].Attributes.Where({ $_ -is [System.Management.Automation.ParameterAttribute] }).Mandatory | Should -BeTrue
		}

		It "Has IncludeSemanticAnalysis switch" {
			$cmd = Get-Command Export-SldgGenerationProfile
			$cmd.Parameters['IncludeSemanticAnalysis'].SwitchParameter | Should -BeTrue
		}
	}

	Context "Export Functionality" {
		BeforeAll {
			$script:testPlan = [PSCustomObject]@{
				Database = 'ProfileTestDB'
				Mode     = 'Synthetic'
				Tables   = @(
					[PSCustomObject]@{
						FullName   = 'dbo.Users'
						SchemaName = 'dbo'
						TableName  = 'Users'
						RowCount   = 100
						Order      = 1
						Columns    = @(
							[PSCustomObject]@{
								ColumnName   = 'Id'
								DataType     = 'int'
								SemanticType = $null
								Generator    = 'Identity'
								IsPII        = $false
								Skip         = $true
								ForeignKey   = $null
								CustomRule   = $null
							},
							[PSCustomObject]@{
								ColumnName   = 'Email'
								DataType     = 'nvarchar'
								SemanticType = 'Email'
								Generator    = 'Email'
								IsPII        = $true
								Skip         = $false
								ForeignKey   = $null
								CustomRule   = $null
							},
							[PSCustomObject]@{
								ColumnName   = 'Status'
								DataType     = 'nvarchar'
								SemanticType = 'Text'
								Generator    = 'Text'
								IsPII        = $false
								Skip         = $false
								ForeignKey   = $null
								CustomRule   = @{ ValueList = @('Active', 'Inactive') }
							}
						)
					}
				)
			}
		}

		It "Creates JSON file at specified path" {
			$outPath = Join-Path $TestDrive 'profile.json'
			Export-SldgGenerationProfile -Plan $script:testPlan -Path $outPath
			Test-Path $outPath | Should -BeTrue
		}

		It "Output is valid JSON" {
			$outPath = Join-Path $TestDrive 'profile_valid.json'
			Export-SldgGenerationProfile -Plan $script:testPlan -Path $outPath
			$json = Get-Content $outPath -Raw | ConvertFrom-Json
			$json | Should -Not -BeNullOrEmpty
		}

		It "JSON contains database name" {
			$outPath = Join-Path $TestDrive 'profile_db.json'
			Export-SldgGenerationProfile -Plan $script:testPlan -Path $outPath
			$json = Get-Content $outPath -Raw | ConvertFrom-Json
			$json.database | Should -Be 'ProfileTestDB'
		}

		It "JSON contains mode" {
			$outPath = Join-Path $TestDrive 'profile_mode.json'
			Export-SldgGenerationProfile -Plan $script:testPlan -Path $outPath
			$json = Get-Content $outPath -Raw | ConvertFrom-Json
			$json.mode | Should -Be 'Synthetic'
		}

		It "JSON contains table definitions" {
			$outPath = Join-Path $TestDrive 'profile_tables.json'
			Export-SldgGenerationProfile -Plan $script:testPlan -Path $outPath
			$json = Get-Content $outPath -Raw | ConvertFrom-Json
			$json.tables.'dbo.Users' | Should -Not -BeNullOrEmpty
		}

		It "Skipped columns are excluded" {
			$outPath = Join-Path $TestDrive 'profile_skip.json'
			Export-SldgGenerationProfile -Plan $script:testPlan -Path $outPath
			$json = Get-Content $outPath -Raw | ConvertFrom-Json
			$json.tables.'dbo.Users'.columns.Id | Should -BeNullOrEmpty
		}

		It "Non-skipped columns are included" {
			$outPath = Join-Path $TestDrive 'profile_cols.json'
			Export-SldgGenerationProfile -Plan $script:testPlan -Path $outPath
			$json = Get-Content $outPath -Raw | ConvertFrom-Json
			$json.tables.'dbo.Users'.columns.Email | Should -Not -BeNullOrEmpty
		}

		It "Custom rules are preserved in export" {
			$outPath = Join-Path $TestDrive 'profile_rules.json'
			Export-SldgGenerationProfile -Plan $script:testPlan -Path $outPath
			$json = Get-Content $outPath -Raw | ConvertFrom-Json
			$json.tables.'dbo.Users'.columns.Status.valueList | Should -Contain 'Active'
		}

		It "Creates parent directory if needed" {
			$outPath = Join-Path $TestDrive 'nested\dir\profile.json'
			Export-SldgGenerationProfile -Plan $script:testPlan -Path $outPath
			Test-Path $outPath | Should -BeTrue
		}

		It "Includes PII flag when IncludeSemanticAnalysis specified" {
			$outPath = Join-Path $TestDrive 'profile_pii.json'
			Export-SldgGenerationProfile -Plan $script:testPlan -Path $outPath -IncludeSemanticAnalysis
			$json = Get-Content $outPath -Raw | ConvertFrom-Json
			$json.tables.'dbo.Users'.columns.Email.isPII | Should -BeTrue
		}

		It "JSON contains createdAt timestamp" {
			$outPath = Join-Path $TestDrive 'profile_ts.json'
			Export-SldgGenerationProfile -Plan $script:testPlan -Path $outPath
			$json = Get-Content $outPath -Raw | ConvertFrom-Json
			$json.createdAt | Should -Not -BeNullOrEmpty
		}
	}
}
