Describe "Get-SldgColumnAnalysis" {
	BeforeAll {
		Remove-Module SqlLabDataGenerator -ErrorAction Ignore
		Import-Module "$PSScriptRoot\..\..\..\SqlLabDataGenerator\SqlLabDataGenerator.psd1" -Force
		$module = Get-Module SqlLabDataGenerator
	}

	Context "Parameter Validation" {
		It "Has mandatory Schema parameter" {
			$cmd = Get-Command Get-SldgColumnAnalysis
			$cmd.Parameters['Schema'].Attributes.Where({ $_ -is [System.Management.Automation.ParameterAttribute] }).Mandatory | Should -BeTrue
		}

		It "Has UseAI switch parameter" {
			$cmd = Get-Command Get-SldgColumnAnalysis
			$cmd.Parameters['UseAI'].SwitchParameter | Should -BeTrue
		}

		It "Has IndustryHint string parameter" {
			$cmd = Get-Command Get-SldgColumnAnalysis
			$cmd.Parameters['IndustryHint'].ParameterType.Name | Should -Be 'String'
		}

		It "Has Locale string parameter" {
			$cmd = Get-Command Get-SldgColumnAnalysis
			$cmd.Parameters['Locale'].ParameterType.Name | Should -Be 'String'
		}
	}

	Context "Pattern-Based Classification" {
		BeforeAll {
			$script:schema = [PSCustomObject]@{
				Database   = 'TestDB'
				Tables     = @(
					[PSCustomObject]@{
						SchemaName  = 'dbo'
						TableName   = 'Person'
						FullName    = 'dbo.Person'
						ColumnCount = 4
						Columns     = @(
							[PSCustomObject]@{
								ColumnName     = 'Id'
								DataType       = 'int'
								IsIdentity     = $true
								IsPrimaryKey   = $true
								IsNullable     = $false
								MaxLength      = $null
								ForeignKey     = $null
								SemanticType   = $null
								Classification = $null
							},
							[PSCustomObject]@{
								ColumnName     = 'Email'
								DataType       = 'nvarchar'
								IsIdentity     = $false
								IsPrimaryKey   = $false
								IsNullable     = $false
								MaxLength      = 256
								ForeignKey     = $null
								SemanticType   = $null
								Classification = $null
							},
							[PSCustomObject]@{
								ColumnName     = 'Phone'
								DataType       = 'nvarchar'
								IsIdentity     = $false
								IsPrimaryKey   = $false
								IsNullable     = $true
								MaxLength      = 50
								ForeignKey     = $null
								SemanticType   = $null
								Classification = $null
							},
							[PSCustomObject]@{
								ColumnName     = 'CreatedDate'
								DataType       = 'datetime'
								IsIdentity     = $false
								IsPrimaryKey   = $false
								IsNullable     = $false
								MaxLength      = $null
								ForeignKey     = $null
								SemanticType   = $null
								Classification = $null
							}
						)
						ForeignKeys = @()
					}
				)
				TableCount = 1
			}
		}

		It "Returns the enriched schema object" {
			$result = Get-SldgColumnAnalysis -Schema $script:schema
			$result | Should -Not -BeNullOrEmpty
			$result.Database | Should -Be 'TestDB'
			$result.ColumnClassifications | Should -Not -BeNullOrEmpty
			$result.ColumnClassifications.Count | Should -Be 4
		}

		It "Classifies Email column" {
			$result = Get-SldgColumnAnalysis -Schema $script:schema
			$emailCol = $result.Tables[0].Columns | Where-Object ColumnName -eq 'Email'
			$emailCol.SemanticType | Should -Not -BeNullOrEmpty
		}

		It "Classifies Phone column" {
			$result = Get-SldgColumnAnalysis -Schema $script:schema
			$phoneCol = $result.Tables[0].Columns | Where-Object ColumnName -eq 'Phone'
			$phoneCol.SemanticType | Should -Not -BeNullOrEmpty
		}

		It "Sets Classification property on columns" {
			$result = Get-SldgColumnAnalysis -Schema $script:schema
			foreach ($col in $result.Tables[0].Columns) {
				$col.Classification | Should -Not -BeNullOrEmpty
			}
		}

		It "Detects PII on email columns" {
			$result = Get-SldgColumnAnalysis -Schema $script:schema
			$emailCol = $result.Tables[0].Columns | Where-Object ColumnName -eq 'Email'
			$emailCol.Classification.IsPII | Should -BeTrue
		}
	}
}
