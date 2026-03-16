Describe "Register-SldgTransformer" {
	BeforeAll {
		Remove-Module SqlLabDataGenerator -ErrorAction Ignore
		Import-Module "$PSScriptRoot\..\..\..\SqlLabDataGenerator\SqlLabDataGenerator.psd1" -Force
		$module = Get-Module SqlLabDataGenerator
	}

	Context "Parameter Validation" {
		It "Has mandatory Name parameter" {
			$cmd = Get-Command Register-SldgTransformer
			$cmd.Parameters['Name'].Attributes.Where({ $_ -is [System.Management.Automation.ParameterAttribute] }).Mandatory | Should -BeTrue
		}

		It "Has mandatory Description parameter" {
			$cmd = Get-Command Register-SldgTransformer
			$cmd.Parameters['Description'].Attributes.Where({ $_ -is [System.Management.Automation.ParameterAttribute] }).Mandatory | Should -BeTrue
		}

		It "Has mandatory TransformFunction parameter" {
			$cmd = Get-Command Register-SldgTransformer
			$cmd.Parameters['TransformFunction'].Attributes.Where({ $_ -is [System.Management.Automation.ParameterAttribute] }).Mandatory | Should -BeTrue
		}

		It "Has optional RequiredSemanticTypes string array parameter" {
			$cmd = Get-Command Register-SldgTransformer
			$cmd.Parameters.ContainsKey('RequiredSemanticTypes') | Should -BeTrue
			$cmd.Parameters['RequiredSemanticTypes'].ParameterType.Name | Should -Be 'String[]'
		}

		It "Has optional OutputType string parameter" {
			$cmd = Get-Command Register-SldgTransformer
			$cmd.Parameters.ContainsKey('OutputType') | Should -BeTrue
			$cmd.Parameters['OutputType'].ParameterType.Name | Should -Be 'String'
		}
	}

	Context "Registration" {
		BeforeAll {
			# Define a dummy transform function in the module scope
			& $module {
				function script:ConvertTo-PesterTestItem {
					param([System.Data.DataTable]$Data)
					foreach ($row in $Data.Rows) { [PSCustomObject]@{ Item = $row[0] } }
				}
			}
		}

		It "Registers a new transformer" {
			Register-SldgTransformer -Name 'PesterTest' -Description 'Pester test transformer' -TransformFunction 'ConvertTo-PesterTestItem'
			$t = Get-SldgTransformer -Name 'PesterTest'
			$t | Should -Not -BeNullOrEmpty
		}

		It "Registered transformer has correct name" {
			$t = Get-SldgTransformer -Name 'PesterTest'
			$t.Name | Should -Be 'PesterTest'
		}

		It "Registered transformer has correct description" {
			$t = Get-SldgTransformer -Name 'PesterTest'
			$t.Description | Should -Be 'Pester test transformer'
		}

		It "Overwrites existing transformer with same name" {
			Register-SldgTransformer -Name 'PesterTest' -Description 'Updated description' -TransformFunction 'ConvertTo-PesterTestItem'
			$t = Get-SldgTransformer -Name 'PesterTest'
			$t.Description | Should -Be 'Updated description'
		}

		It "Registers with RequiredSemanticTypes" {
			Register-SldgTransformer -Name 'PesterTyped' -Description 'Typed transformer' -TransformFunction 'ConvertTo-PesterTestItem' -RequiredSemanticTypes @('Email', 'FullName')
			$t = Get-SldgTransformer -Name 'PesterTyped'
			$t.RequiredSemanticTypes | Should -Contain 'Email'
			$t.RequiredSemanticTypes | Should -Contain 'FullName'
		}

		It "Registers with OutputType" {
			Register-SldgTransformer -Name 'PesterOutput' -Description 'Output typed' -TransformFunction 'ConvertTo-PesterTestItem' -OutputType 'Test.OutputObject'
			$t = Get-SldgTransformer -Name 'PesterOutput'
			$t.OutputType | Should -Be 'Test.OutputObject'
		}

		AfterAll {
			& $module {
				$script:SldgState.Transformers.Remove('PesterTest')
				$script:SldgState.Transformers.Remove('PesterTyped')
				$script:SldgState.Transformers.Remove('PesterOutput')
			}
		}
	}
}
