Describe "Get-SldgScenarioTemplate" {
	BeforeAll {
		Remove-Module SqlLabDataGenerator -ErrorAction Ignore
		Import-Module "$PSScriptRoot\..\..\..\..\SqlLabDataGenerator\SqlLabDataGenerator.psd1" -Force
		$module = Get-Module SqlLabDataGenerator
	}

	Context "Named Scenario Retrieval" {
		It "Returns eCommerce template by name" {
			$result = & $module { Get-SldgScenarioTemplate -Name 'eCommerce' }
			$result | Should -Not -BeNullOrEmpty
			$result.Name | Should -Be 'eCommerce'
			$result.PSTypeNames | Should -Contain 'SqlLabDataGenerator.ScenarioTemplate'
		}

		It "Returns Healthcare template by name" {
			$result = & $module { Get-SldgScenarioTemplate -Name 'Healthcare' }
			$result | Should -Not -BeNullOrEmpty
			$result.Name | Should -Be 'Healthcare'
		}

		It "Returns HR template by name" {
			$result = & $module { Get-SldgScenarioTemplate -Name 'HR' }
			$result.Name | Should -Be 'HR'
		}

		It "Returns Finance template by name" {
			$result = & $module { Get-SldgScenarioTemplate -Name 'Finance' }
			$result.Name | Should -Be 'Finance'
		}

		It "Returns Education template by name" {
			$result = & $module { Get-SldgScenarioTemplate -Name 'Education' }
			$result.Name | Should -Be 'Education'
		}

		It "Returns null for unknown scenario name" {
			$result = & $module { Get-SldgScenarioTemplate -Name 'UnknownScenario' }
			$result | Should -BeNullOrEmpty
		}
	}

	Context "Template Structure" {
		BeforeAll {
			$script:template = & $module { Get-SldgScenarioTemplate -Name 'eCommerce' }
		}

		It "Has Description property" {
			$script:template.Description | Should -Not -BeNullOrEmpty
		}

		It "Has TableRoles with patterns" {
			$script:template.TableRoles | Should -Not -BeNullOrEmpty
			$script:template.TableRoles.Count | Should -BeGreaterThan 0
		}

		It "Has ValueRules with arrays" {
			$script:template.ValueRules | Should -Not -BeNullOrEmpty
			$script:template.ValueRules.Count | Should -BeGreaterThan 0
		}

		It "TableRoles entries have Role and Multiplier" {
			foreach ($key in $script:template.TableRoles.Keys) {
				$entry = $script:template.TableRoles[$key]
				$entry.Role | Should -Not -BeNullOrEmpty -Because "Pattern '$key' needs a Role"
				$entry.Multiplier | Should -BeGreaterThan 0 -Because "Pattern '$key' needs a positive Multiplier"
			}
		}

		It "ValueRules entries are non-empty arrays" {
			foreach ($key in $script:template.ValueRules.Keys) {
				$values = $script:template.ValueRules[$key]
				$values.Count | Should -BeGreaterThan 0 -Because "ValueRule '$key' must have options"
			}
		}
	}

	Context "Auto-Detection" {
		It "Auto-detects eCommerce from matching schema" {
			$mockSchema = [PSCustomObject]@{
				Tables = @(
					[PSCustomObject]@{ TableName = 'Customer'; SchemaName = 'dbo' }
					[PSCustomObject]@{ TableName = 'Product'; SchemaName = 'dbo' }
					[PSCustomObject]@{ TableName = 'Order'; SchemaName = 'dbo' }
					[PSCustomObject]@{ TableName = 'OrderDetail'; SchemaName = 'dbo' }
					[PSCustomObject]@{ TableName = 'Category'; SchemaName = 'dbo' }
				)
			}
			$result = & $module { param($s) Get-SldgScenarioTemplate -Name 'Auto' -Schema $s } $mockSchema
			$result | Should -Not -BeNullOrEmpty
			$result.Name | Should -Be 'eCommerce'
		}

		It "Auto-detects Healthcare from matching schema" {
			$mockSchema = [PSCustomObject]@{
				Tables = @(
					[PSCustomObject]@{ TableName = 'Patient'; SchemaName = 'dbo' }
					[PSCustomObject]@{ TableName = 'Visit'; SchemaName = 'dbo' }
					[PSCustomObject]@{ TableName = 'Diagnosis'; SchemaName = 'dbo' }
					[PSCustomObject]@{ TableName = 'Prescription'; SchemaName = 'dbo' }
					[PSCustomObject]@{ TableName = 'Doctor'; SchemaName = 'dbo' }
				)
			}
			$result = & $module { param($s) Get-SldgScenarioTemplate -Name 'Auto' -Schema $s } $mockSchema
			$result | Should -Not -BeNullOrEmpty
			$result.Name | Should -Be 'Healthcare'
		}

		It "Returns null when schema does not match any scenario (threshold 3)" {
			$mockSchema = [PSCustomObject]@{
				Tables = @(
					[PSCustomObject]@{ TableName = 'Customer'; SchemaName = 'dbo' }
					[PSCustomObject]@{ TableName = 'RandomTable'; SchemaName = 'dbo' }
				)
			}
			$result = & $module { param($s) Get-SldgScenarioTemplate -Name 'Auto' -Schema $s } $mockSchema
			$result | Should -BeNullOrEmpty
		}

		It "Returns null when schema is empty" {
			$mockSchema = [PSCustomObject]@{ Tables = @() }
			$result = & $module { param($s) Get-SldgScenarioTemplate -Name 'Auto' -Schema $s } $mockSchema
			$result | Should -BeNullOrEmpty
		}
	}
}
