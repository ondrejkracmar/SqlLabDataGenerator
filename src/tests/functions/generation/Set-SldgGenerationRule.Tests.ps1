Describe "Set-SldgGenerationRule" {
	BeforeAll {
		Remove-Module SqlLabDataGenerator -ErrorAction Ignore
		Import-Module "$PSScriptRoot\..\..\..\SqlLabDataGenerator\SqlLabDataGenerator.psd1" -Force
		$module = Get-Module SqlLabDataGenerator
	}

	Context "Parameter Validation" {
		It "Has mandatory Plan parameter" {
			$cmd = Get-Command Set-SldgGenerationRule
			$cmd.Parameters['Plan'].Attributes.Where({ $_ -is [System.Management.Automation.ParameterAttribute] }).Mandatory | Should -BeTrue
		}

		It "Has mandatory TableName parameter" {
			$cmd = Get-Command Set-SldgGenerationRule
			$cmd.Parameters['TableName'].Attributes.Where({ $_ -is [System.Management.Automation.ParameterAttribute] }).Mandatory | Should -BeTrue
		}

		It "Has mandatory ColumnName parameter" {
			$cmd = Get-Command Set-SldgGenerationRule
			$cmd.Parameters['ColumnName'].Attributes.Where({ $_ -is [System.Management.Automation.ParameterAttribute] }).Mandatory | Should -BeTrue
		}

		It "ValueList parameter accepts string array" {
			$cmd = Get-Command Set-SldgGenerationRule
			$cmd.Parameters['ValueList'].ParameterType.Name | Should -Be 'String[]'
		}

		It "Generator parameter accepts string" {
			$cmd = Get-Command Set-SldgGenerationRule
			$cmd.Parameters['Generator'].ParameterType.Name | Should -Be 'String'
		}

		It "GeneratorParams parameter accepts hashtable" {
			$cmd = Get-Command Set-SldgGenerationRule
			$cmd.Parameters['GeneratorParams'].ParameterType.Name | Should -Be 'Hashtable'
		}

		It "ScriptBlock parameter accepts scriptblock" {
			$cmd = Get-Command Set-SldgGenerationRule
			$cmd.Parameters['ScriptBlock'].ParameterType.Name | Should -Be 'ScriptBlock'
		}
	}

	Context "Rule Application" {
		BeforeAll {
			$script:testPlan = [PSCustomObject]@{
				Database        = 'TestDB'
				Mode            = 'Synthetic'
				GenerationRules = @{}
				Tables          = @(
					[PSCustomObject]@{
						FullName   = 'dbo.Customer'
						SchemaName = 'dbo'
						TableName  = 'Customer'
						RowCount   = 100
						Columns    = @(
							[PSCustomObject]@{ ColumnName = 'Status'; DataType = 'nvarchar'; CustomRule = $null },
							[PSCustomObject]@{ ColumnName = 'Currency'; DataType = 'nvarchar'; CustomRule = $null },
							[PSCustomObject]@{ ColumnName = 'SKU'; DataType = 'nvarchar'; CustomRule = $null }
						)
					}
				)
			}
		}

		It "Sets ValueList rule" {
			Set-SldgGenerationRule -Plan $script:testPlan -TableName 'dbo.Customer' -ColumnName 'Status' -ValueList @('Active', 'Inactive', 'Pending')
			$script:testPlan.GenerationRules['dbo.Customer']['Status'].ValueList | Should -Contain 'Active'
			$script:testPlan.GenerationRules['dbo.Customer']['Status'].ValueList | Should -Contain 'Inactive'
		}

		It "Sets StaticValue rule" {
			Set-SldgGenerationRule -Plan $script:testPlan -TableName 'dbo.Customer' -ColumnName 'Currency' -StaticValue 'USD'
			$script:testPlan.GenerationRules['dbo.Customer']['Currency'].StaticValue | Should -Be 'USD'
		}

		It "Sets ScriptBlock rule" {
			$sb = { "SKU-$(Get-Random -Minimum 10000 -Maximum 99999)" }
			Set-SldgGenerationRule -Plan $script:testPlan -TableName 'dbo.Customer' -ColumnName 'SKU' -ScriptBlock $sb
			$script:testPlan.GenerationRules['dbo.Customer']['SKU'].ScriptBlock | Should -Not -BeNullOrEmpty
		}

		It "Sets Generator override rule" {
			Set-SldgGenerationRule -Plan $script:testPlan -TableName 'dbo.Customer' -ColumnName 'Status' -Generator 'CompanyName'
			$script:testPlan.GenerationRules['dbo.Customer']['Status'].Generator | Should -Be 'CompanyName'
		}

		It "Updates column plan CustomRule property" {
			Set-SldgGenerationRule -Plan $script:testPlan -TableName 'dbo.Customer' -ColumnName 'Currency' -StaticValue 'EUR'
			$col = $script:testPlan.Tables[0].Columns | Where-Object ColumnName -eq 'Currency'
			$col.CustomRule.StaticValue | Should -Be 'EUR'
		}

		It "Can set rules for multiple columns on same table" {
			$script:testPlan.GenerationRules = @{}
			Set-SldgGenerationRule -Plan $script:testPlan -TableName 'dbo.Customer' -ColumnName 'Status' -ValueList @('A', 'B')
			Set-SldgGenerationRule -Plan $script:testPlan -TableName 'dbo.Customer' -ColumnName 'Currency' -StaticValue 'CZK'
			$script:testPlan.GenerationRules['dbo.Customer'].Keys.Count | Should -Be 2
		}

		It "Overwrites existing rule for same column" {
			Set-SldgGenerationRule -Plan $script:testPlan -TableName 'dbo.Customer' -ColumnName 'Status' -ValueList @('X', 'Y')
			$script:testPlan.GenerationRules['dbo.Customer']['Status'].ValueList | Should -Contain 'X'
			$script:testPlan.GenerationRules['dbo.Customer']['Status'].ValueList | Should -Not -Contain 'A'
		}

		It "Handles StaticValue of null" {
			Set-SldgGenerationRule -Plan $script:testPlan -TableName 'dbo.Customer' -ColumnName 'Status' -StaticValue $null
			$script:testPlan.GenerationRules['dbo.Customer']['Status'].ContainsKey('StaticValue') | Should -BeTrue
		}
	}
}
