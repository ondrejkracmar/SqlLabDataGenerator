Describe "Profile Round-Trip & Edge Cases" {
	BeforeAll {
		Remove-Module SqlLabDataGenerator -ErrorAction Ignore
		Import-Module "$PSScriptRoot\..\..\..\SqlLabDataGenerator\SqlLabDataGenerator.psd1" -Force
		$module = Get-Module SqlLabDataGenerator
	}

	Context "Export → Import Round-Trip Fidelity" {
		BeforeAll {
			$script:plan = [PSCustomObject]@{
				Database        = 'RoundTripDB'
				Mode            = 'Synthetic'
				TotalRows       = 350
				GenerationRules = @{}
				Tables          = @(
					[PSCustomObject]@{
						FullName   = 'dbo.Orders'
						SchemaName = 'dbo'
						TableName  = 'Orders'
						RowCount   = 200
						Order      = 1
						Columns    = @(
							[PSCustomObject]@{
								ColumnName   = 'OrderId'
								DataType     = 'int'
								SemanticType = $null
								Generator    = 'Identity'
								IsPII        = $false
								Skip         = $true
								ForeignKey   = $null
								CustomRule   = $null
							},
							[PSCustomObject]@{
								ColumnName   = 'CustomerEmail'
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
								CustomRule   = @{ ValueList = @('New', 'Processing', 'Shipped', 'Delivered') }
							},
							[PSCustomObject]@{
								ColumnName   = 'Amount'
								DataType     = 'decimal'
								SemanticType = 'Currency'
								Generator    = 'Financial'
								IsPII        = $false
								Skip         = $false
								ForeignKey   = $null
								CustomRule   = @{ StaticValue = 99.99 }
							}
						)
					},
					[PSCustomObject]@{
						FullName   = 'dbo.Items'
						SchemaName = 'dbo'
						TableName  = 'Items'
						RowCount   = 150
						Order      = 2
						Columns    = @(
							[PSCustomObject]@{
								ColumnName   = 'ItemId'
								DataType     = 'int'
								SemanticType = $null
								Generator    = 'Identity'
								IsPII        = $false
								Skip         = $true
								ForeignKey   = $null
								CustomRule   = $null
							},
							[PSCustomObject]@{
								ColumnName   = 'OrderId'
								DataType     = 'int'
								SemanticType = $null
								Generator    = $null
								IsPII        = $false
								Skip         = $false
								ForeignKey   = [PSCustomObject]@{
									ReferencedSchema = 'dbo'
									ReferencedTable  = 'Orders'
									ReferencedColumn = 'OrderId'
								}
								CustomRule   = $null
							}
						)
					}
				)
			}
		}

		It "Exported JSON re-imports and preserves row counts" {
			$exportPath = Join-Path $TestDrive 'roundtrip.json'
			Export-SldgGenerationProfile -Plan $script:plan -Path $exportPath

			# Create a fresh plan with default row counts to prove import overrides them
			$freshPlan = [PSCustomObject]@{
				Database        = 'RoundTripDB'
				Mode            = 'Synthetic'
				TotalRows       = 0
				GenerationRules = @{}
				Tables          = @(
					[PSCustomObject]@{
						FullName   = 'dbo.Orders'
						SchemaName = 'dbo'
						TableName  = 'Orders'
						RowCount   = 10
						Columns    = @(
							[PSCustomObject]@{ ColumnName = 'Status'; DataType = 'nvarchar'; CustomRule = $null },
							[PSCustomObject]@{ ColumnName = 'Amount'; DataType = 'decimal'; CustomRule = $null }
						)
					}
				)
			}
			Import-SldgGenerationProfile -Path $exportPath -Plan $freshPlan

			$freshPlan.Tables[0].RowCount | Should -Be 200
		}

		It "Exported JSON preserves ValueList custom rules" {
			$exportPath = Join-Path $TestDrive 'roundtrip_rules.json'
			Export-SldgGenerationProfile -Plan $script:plan -Path $exportPath
			$json = Get-Content $exportPath -Raw | ConvertFrom-Json
			$json.tables.'dbo.Orders'.columns.Status.valueList | Should -Contain 'New'
			$json.tables.'dbo.Orders'.columns.Status.valueList | Should -Contain 'Delivered'
		}

		It "Exported JSON preserves StaticValue custom rules" {
			$exportPath = Join-Path $TestDrive 'roundtrip_static.json'
			Export-SldgGenerationProfile -Plan $script:plan -Path $exportPath
			$json = Get-Content $exportPath -Raw | ConvertFrom-Json
			$json.tables.'dbo.Orders'.columns.Amount.staticValue | Should -Be 99.99
		}

		It "Exported JSON preserves foreign key references" {
			$exportPath = Join-Path $TestDrive 'roundtrip_fk.json'
			Export-SldgGenerationProfile -Plan $script:plan -Path $exportPath
			$json = Get-Content $exportPath -Raw | ConvertFrom-Json
			$json.tables.'dbo.Items'.columns.OrderId.foreignKey.referencedTable | Should -Be 'dbo.Orders'
			$json.tables.'dbo.Items'.columns.OrderId.foreignKey.referencedColumn | Should -Be 'OrderId'
		}
	}

	Context "SQLite-Style Tables (No Schema)" {
		BeforeAll {
			$script:sqlitePlan = [PSCustomObject]@{
				Database        = 'sqlite_test.db'
				Mode            = 'Synthetic'
				TotalRows       = 50
				GenerationRules = @{}
				Tables          = @(
					[PSCustomObject]@{
						FullName   = 'Products'
						SchemaName = $null
						TableName  = 'Products'
						RowCount   = 50
						Order      = 1
						Columns    = @(
							[PSCustomObject]@{
								ColumnName   = 'Name'
								DataType     = 'TEXT'
								SemanticType = 'FullName'
								Generator    = 'PersonName'
								IsPII        = $false
								Skip         = $false
								ForeignKey   = $null
								CustomRule   = $null
							}
						)
					}
				)
			}
		}

		It "Exports and produces valid JSON for schema-less tables" {
			$exportPath = Join-Path $TestDrive 'sqlite_profile.json'
			Export-SldgGenerationProfile -Plan $script:sqlitePlan -Path $exportPath
			$json = Get-Content $exportPath -Raw | ConvertFrom-Json
			$json | Should -Not -BeNullOrEmpty
			$json.tables.Products | Should -Not -BeNullOrEmpty
		}

		It "Re-imports for schema-less table names" {
			$exportPath = Join-Path $TestDrive 'sqlite_reimport.json'
			Export-SldgGenerationProfile -Plan $script:sqlitePlan -Path $exportPath

			$freshPlan = [PSCustomObject]@{
				Database        = 'sqlite_test.db'
				Mode            = 'Synthetic'
				TotalRows       = 0
				GenerationRules = @{}
				Tables          = @(
					[PSCustomObject]@{
						FullName   = 'Products'
						SchemaName = $null
						TableName  = 'Products'
						RowCount   = 10
						Columns    = @(
							[PSCustomObject]@{ ColumnName = 'Name'; DataType = 'TEXT'; CustomRule = $null }
						)
					}
				)
			}
			Import-SldgGenerationProfile -Path $exportPath -Plan $freshPlan
			$freshPlan.Tables[0].RowCount | Should -Be 50
		}
	}

	Context "ScriptBlock Injection Rejection" {
		BeforeAll {
			$script:injectionProfilePath = Join-Path $TestDrive 'injection-profile.json'
			@{
				tables = @{
					'dbo.Users' = @{
						columns = @{
							Email = @{
								scriptBlock = 'Get-Process | Stop-Process -Force'
							}
						}
					}
				}
			} | ConvertTo-Json -Depth 10 | Set-Content -Path $script:injectionProfilePath -Encoding UTF8

			$script:targetPlan = [PSCustomObject]@{
				Database        = 'SecurityTestDB'
				Mode            = 'Synthetic'
				TotalRows       = 10
				GenerationRules = @{}
				Tables          = @(
					[PSCustomObject]@{
						FullName   = 'dbo.Users'
						SchemaName = 'dbo'
						TableName  = 'Users'
						RowCount   = 10
						Columns    = @(
							[PSCustomObject]@{ ColumnName = 'Email'; DataType = 'nvarchar'; CustomRule = $null }
						)
					}
				)
			}
		}

		It "Skips columns with scriptBlock key in profile (does not throw)" {
			{ Import-SldgGenerationProfile -Path $script:injectionProfilePath -Plan $script:targetPlan } | Should -Not -Throw
		}

		It "Does not apply scriptBlock as a generation rule" {
			Import-SldgGenerationProfile -Path $script:injectionProfilePath -Plan $script:targetPlan
			# The column should NOT have acquired a custom rule from the poisoned profile
			$col = $script:targetPlan.Tables[0].Columns | Where-Object ColumnName -eq 'Email'
			$col.CustomRule | Should -BeNullOrEmpty
		}
	}
}
