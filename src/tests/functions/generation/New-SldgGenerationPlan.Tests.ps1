Describe "New-SldgGenerationPlan" {
	BeforeAll {
		Remove-Module SqlLabDataGenerator -ErrorAction Ignore
		Import-Module "$PSScriptRoot\..\..\..\SqlLabDataGenerator\SqlLabDataGenerator.psd1" -Force
		$module = Get-Module SqlLabDataGenerator
	}

	Context "Parameter Validation" {
		It "Has mandatory Schema parameter" {
			$cmd = Get-Command New-SldgGenerationPlan
			$cmd.Parameters['Schema'].Attributes.Where({ $_ -is [System.Management.Automation.ParameterAttribute] }).Mandatory | Should -BeTrue
		}

		It "RowCount parameter is integer" {
			$cmd = Get-Command New-SldgGenerationPlan
			$cmd.Parameters['RowCount'].ParameterType.Name | Should -Be 'Int32'
		}

		It "TableRowCounts parameter is hashtable" {
			$cmd = Get-Command New-SldgGenerationPlan
			$cmd.Parameters['TableRowCounts'].ParameterType.Name | Should -Be 'Hashtable'
		}

		It "Mode parameter validates against known values" {
			$cmd = Get-Command New-SldgGenerationPlan
			$validateSet = $cmd.Parameters['Mode'].Attributes.Where({ $_ -is [System.Management.Automation.ValidateSetAttribute] })
			$validateSet | Should -Not -BeNullOrEmpty
			$validateSet.ValidValues | Should -Contain 'Synthetic'
			$validateSet.ValidValues | Should -Contain 'Masking'
			$validateSet.ValidValues | Should -Contain 'Scenario'
		}

		It "Has UseAI switch parameter" {
			$cmd = Get-Command New-SldgGenerationPlan
			$cmd.Parameters['UseAI'].SwitchParameter | Should -BeTrue
		}

		It "Has IndustryHint string parameter" {
			$cmd = Get-Command New-SldgGenerationPlan
			$cmd.Parameters['IndustryHint'].ParameterType.Name | Should -Be 'String'
		}
	}

	Context "Plan Generation" {
		BeforeAll {
			$script:mockSchema = [PSCustomObject]@{
				Database   = 'TestDB'
				Tables     = @(
					[PSCustomObject]@{
						SchemaName  = 'dbo'
						TableName   = 'Customer'
						FullName    = 'dbo.Customer'
						ColumnCount = 3
						Columns     = @(
							[PSCustomObject]@{
								ColumnName     = 'Id'
								DataType       = 'int'
								IsIdentity     = $true
								IsComputed     = $false
								IsPrimaryKey   = $true
								IsUnique       = $true
								IsNullable     = $false
								MaxLength      = $null
								ForeignKey     = $null
								SemanticType   = $null
								Classification = $null
								GenerationRule = $null
							},
							[PSCustomObject]@{
								ColumnName     = 'Name'
								DataType       = 'nvarchar'
								IsIdentity     = $false
								IsComputed     = $false
								IsPrimaryKey   = $false
								IsUnique       = $false
								IsNullable     = $false
								MaxLength      = 100
								ForeignKey     = $null
								SemanticType   = 'FullName'
								Classification = [PSCustomObject]@{ SemanticType = 'FullName'; IsPII = $true }
								GenerationRule = $null
							},
							[PSCustomObject]@{
								ColumnName     = 'Email'
								DataType       = 'nvarchar'
								IsIdentity     = $false
								IsComputed     = $false
								IsPrimaryKey   = $false
								IsUnique       = $true
								IsNullable     = $false
								MaxLength      = 256
								ForeignKey     = $null
								SemanticType   = 'Email'
								Classification = [PSCustomObject]@{ SemanticType = 'Email'; IsPII = $true }
								GenerationRule = $null
							}
						)
						ForeignKeys = @()
					}
				)
				TableCount = 1
			}
		}

		It "Returns a GenerationPlan type" {
			$plan = New-SldgGenerationPlan -Schema $script:mockSchema -RowCount 10
			$plan.PSTypeNames | Should -Contain 'SqlLabDataGenerator.GenerationPlan'
		}

		It "Plan contains correct database" {
			$plan = New-SldgGenerationPlan -Schema $script:mockSchema -RowCount 10
			$plan.Database | Should -Be 'TestDB'
		}

		It "Plan uses specified row count" {
			$plan = New-SldgGenerationPlan -Schema $script:mockSchema -RowCount 50
			$plan.Tables[0].RowCount | Should -Be 50
		}

		It "Plan stores table count" {
			$plan = New-SldgGenerationPlan -Schema $script:mockSchema -RowCount 10
			$plan.TableCount | Should -Be 1
		}

		It "Identity columns are marked as Skip" {
			$plan = New-SldgGenerationPlan -Schema $script:mockSchema -RowCount 10
			$idCol = $plan.Tables[0].Columns | Where-Object ColumnName -eq 'Id'
			$idCol.Skip | Should -BeTrue
		}

		It "Non-identity columns are not skipped" {
			$plan = New-SldgGenerationPlan -Schema $script:mockSchema -RowCount 10
			$nameCol = $plan.Tables[0].Columns | Where-Object ColumnName -eq 'Name'
			$nameCol.Skip | Should -BeFalse
		}

		It "Column plan preserves semantic type" {
			$plan = New-SldgGenerationPlan -Schema $script:mockSchema -RowCount 10
			$emailCol = $plan.Tables[0].Columns | Where-Object ColumnName -eq 'Email'
			$emailCol.SemanticType | Should -Be 'Email'
		}

		It "Has GeneratorMap" {
			$plan = New-SldgGenerationPlan -Schema $script:mockSchema -RowCount 10
			$plan.GeneratorMap | Should -Not -BeNullOrEmpty
		}

		It "Has CreatedAt timestamp" {
			$before = Get-Date
			$plan = New-SldgGenerationPlan -Schema $script:mockSchema -RowCount 10
			$plan.CreatedAt | Should -BeGreaterOrEqual $before
		}

		It "Has empty GenerationRules initially" {
			$plan = New-SldgGenerationPlan -Schema $script:mockSchema -RowCount 10
			$plan.GenerationRules.Count | Should -Be 0
		}

		It "TableRowCounts override default row count" {
			$plan = New-SldgGenerationPlan -Schema $script:mockSchema -RowCount 10 -TableRowCounts @{ 'dbo.Customer' = 999 }
			$plan.Tables[0].RowCount | Should -Be 999
		}
	}

	Context "Plan Storage" {
		It "Stores plan in module state" {
			$plan = New-SldgGenerationPlan -Schema $script:mockSchema -RowCount 10
			$storedPlan = & $module { $script:SldgState.GenerationPlans['TestDB'] }
			$storedPlan | Should -Not -BeNullOrEmpty
			$storedPlan.Database | Should -Be 'TestDB'
		}
	}
}
