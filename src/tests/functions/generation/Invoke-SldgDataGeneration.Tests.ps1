Describe "Invoke-SldgDataGeneration" {
	BeforeAll {
		Remove-Module SqlLabDataGenerator -ErrorAction Ignore
		Import-Module "$PSScriptRoot\..\..\..\SqlLabDataGenerator\SqlLabDataGenerator.psd1" -Force
		$module = Get-Module SqlLabDataGenerator
	}

	Context "Parameter Validation" {
		It "Has mandatory Plan parameter" {
			$cmd = Get-Command Invoke-SldgDataGeneration
			$cmd.Parameters['Plan'].Attributes.Where({ $_ -is [System.Management.Automation.ParameterAttribute] }).Mandatory | Should -BeTrue
		}

		It "Has NoInsert switch parameter" {
			$cmd = Get-Command Invoke-SldgDataGeneration
			$cmd.Parameters['NoInsert'].SwitchParameter | Should -BeTrue
		}

		It "Has PassThru switch parameter" {
			$cmd = Get-Command Invoke-SldgDataGeneration
			$cmd.Parameters['PassThru'].SwitchParameter | Should -BeTrue
		}

		It "Has UseTransaction switch parameter" {
			$cmd = Get-Command Invoke-SldgDataGeneration
			$cmd.Parameters['UseTransaction'].SwitchParameter | Should -BeTrue
		}

		It "Supports ShouldProcess" {
			$cmd = Get-Command Invoke-SldgDataGeneration
			$cmd.CmdletBinding | Should -BeTrue
			$cmd.Parameters.ContainsKey('WhatIf') | Should -BeTrue
			$cmd.Parameters.ContainsKey('Confirm') | Should -BeTrue
		}

		It "Has ConnectionInfo parameter" {
			$cmd = Get-Command Invoke-SldgDataGeneration
			$cmd.Parameters.ContainsKey('ConnectionInfo') | Should -BeTrue
		}
	}

	Context "Without Active Connection or NoInsert" {
		BeforeAll {
			& $module { $script:SldgState.ActiveConnection = $null }
		}

		It "Throws when no connection and NoInsert not specified" {
			$fakePlan = [PSCustomObject]@{ Database = 'TestDB'; Mode = 'Synthetic'; Tables = @(); TableCount = 0 }
			{ Invoke-SldgDataGeneration -Plan $fakePlan -ErrorAction Stop } | Should -Throw
		}
	}

	Context "NoInsert Mode" {
		BeforeAll {
			& $module { $script:SldgState.ActiveConnection = $null }

			$script:mockPlan = [PSCustomObject]@{
				Database        = 'TestDB'
				Mode            = 'Synthetic'
				Tables          = @()
				TableCount      = 0
				GeneratorMap    = @{}
				GenerationRules = @{}
			}
		}

		It "Succeeds with -NoInsert and no connection" {
			$result = Invoke-SldgDataGeneration -Plan $script:mockPlan -NoInsert
			$result | Should -Not -BeNullOrEmpty
		}

		It "Returns GenerationResult type" {
			$result = Invoke-SldgDataGeneration -Plan $script:mockPlan -NoInsert
			$result.PSTypeNames | Should -Contain 'SqlLabDataGenerator.GenerationResult'
		}

		It "Result has required audit properties" {
			$result = Invoke-SldgDataGeneration -Plan $script:mockPlan -NoInsert
			$result.PSObject.Properties.Name | Should -Contain 'StartedAt'
			$result.PSObject.Properties.Name | Should -Contain 'Duration'
			$result.PSObject.Properties.Name | Should -Contain 'User'
			$result.PSObject.Properties.Name | Should -Contain 'CompletedAt'
		}

		It "Result has table tracking properties" {
			$result = Invoke-SldgDataGeneration -Plan $script:mockPlan -NoInsert
			$result.PSObject.Properties.Name | Should -Contain 'Database'
			$result.PSObject.Properties.Name | Should -Contain 'Mode'
			$result.PSObject.Properties.Name | Should -Contain 'TableCount'
			$result.PSObject.Properties.Name | Should -Contain 'TotalRows'
			$result.PSObject.Properties.Name | Should -Contain 'Tables'
			$result.PSObject.Properties.Name | Should -Contain 'SuccessCount'
			$result.PSObject.Properties.Name | Should -Contain 'FailureCount'
		}

		It "Database matches plan" {
			$result = Invoke-SldgDataGeneration -Plan $script:mockPlan -NoInsert
			$result.Database | Should -Be 'TestDB'
		}

		It "Mode matches plan" {
			$result = Invoke-SldgDataGeneration -Plan $script:mockPlan -NoInsert
			$result.Mode | Should -Be 'Synthetic'
		}

		It "User contains current identity" {
			$result = Invoke-SldgDataGeneration -Plan $script:mockPlan -NoInsert
			$result.User | Should -Not -BeNullOrEmpty
		}
	}

	Context "NoInsert with actual table plan" {
		BeforeAll {
			& $module { $script:SldgState.ActiveConnection = $null }

			# Build a plan with a concrete table that has generatable columns
			$script:tablePlan = [PSCustomObject]@{
				SchemaName  = 'dbo'
				TableName   = 'TestPerson'
				FullName    = 'dbo.TestPerson'
				RowCount    = 5
				Columns     = @(
					[PSCustomObject]@{
						ColumnName   = 'Id'
						DataType     = 'int'
						SemanticType = $null
						Skip         = $true
						IsPrimaryKey = $true
						IsUnique     = $true
						IsNullable   = $false
						MaxLength    = $null
						ForeignKey   = $null
						IsPII        = $false
						CustomRule   = $null
					}
					[PSCustomObject]@{
						ColumnName   = 'FirstName'
						DataType     = 'nvarchar'
						SemanticType = 'PersonFirstName'
						Skip         = $false
						IsPrimaryKey = $false
						IsUnique     = $false
						IsNullable   = $false
						MaxLength    = 100
						ForeignKey   = $null
						IsPII        = $true
						CustomRule   = $null
					}
					[PSCustomObject]@{
						ColumnName   = 'Age'
						DataType     = 'int'
						SemanticType = $null
						Skip         = $false
						IsPrimaryKey = $false
						IsUnique     = $false
						IsNullable   = $true
						MaxLength    = $null
						ForeignKey   = $null
						IsPII        = $false
						CustomRule   = $null
					}
				)
				ForeignKeys = @()
			}

			$script:realPlan = [PSCustomObject]@{
				Database        = 'TestDB'
				Mode            = 'Synthetic'
				Tables          = @($script:tablePlan)
				TableCount      = 1
				GeneratorMap    = $null
				GenerationRules = @{}
			}
		}

		It "Generates rows with NoInsert and PassThru" {
			$result = Invoke-SldgDataGeneration -Plan $script:realPlan -NoInsert -PassThru -ErrorAction SilentlyContinue
			$result | Should -Not -BeNullOrEmpty
			$result.TotalRows | Should -Be 5
			$result.SuccessCount | Should -Be 1
			$result.FailureCount | Should -Be 0
		}

		It "PassThru result contains DataTable with rows" {
			$result = Invoke-SldgDataGeneration -Plan $script:realPlan -NoInsert -PassThru -ErrorAction SilentlyContinue
			$table = $result.Tables[0]
			$table.DataTable | Should -Not -BeNullOrEmpty
			$table.DataTable.Rows.Count | Should -Be 5
		}

		It "Generated FirstName column is not empty" {
			$result = Invoke-SldgDataGeneration -Plan $script:realPlan -NoInsert -PassThru -ErrorAction SilentlyContinue
			$dt = $result.Tables[0].DataTable
			foreach ($row in $dt.Rows) {
				$row['FirstName'] | Should -Not -BeNullOrEmpty
			}
		}
	}

	Context "Parallel Parameter Validation" {
		It "Has Parallel switch parameter" {
			$cmd = Get-Command Invoke-SldgDataGeneration
			$cmd.Parameters['Parallel'].SwitchParameter | Should -BeTrue
		}

		It "Has ThrottleLimit parameter" {
			$cmd = Get-Command Invoke-SldgDataGeneration
			$cmd.Parameters.ContainsKey('ThrottleLimit') | Should -BeTrue
		}

		It "Succeeds with Parallel flag on empty plan in NoInsert mode" {
			$emptyPlan = [PSCustomObject]@{
				Database        = 'TestDB'
				Mode            = 'Synthetic'
				Tables          = @()
				TableCount      = 0
				GeneratorMap    = @{}
				GenerationRules = @{}
			}
			& $module { $script:SldgState.ActiveConnection = $null }
			$result = Invoke-SldgDataGeneration -Plan $emptyPlan -NoInsert -Parallel
			$result | Should -Not -BeNullOrEmpty
			$result.TotalRows | Should -Be 0
		}
	}
}
