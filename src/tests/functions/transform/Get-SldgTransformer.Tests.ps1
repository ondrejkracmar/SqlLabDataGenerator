Describe "Get-SldgTransformer" {
	BeforeAll {
		Remove-Module SqlLabDataGenerator -ErrorAction Ignore
		Import-Module "$PSScriptRoot\..\..\..\SqlLabDataGenerator\SqlLabDataGenerator.psd1" -Force
		$module = Get-Module SqlLabDataGenerator
	}

	Context "Parameter Validation" {
		It "Has optional Name parameter" {
			$cmd = Get-Command Get-SldgTransformer
			$cmd.Parameters.ContainsKey('Name') | Should -BeTrue
		}

		It "Name parameter is a string" {
			$cmd = Get-Command Get-SldgTransformer
			$cmd.Parameters['Name'].ParameterType.Name | Should -Be 'String'
		}

		It "Name parameter defaults to wildcard" {
			# Get-Command doesn't reliably expose parameter defaults, so parse the source AST
			$cmd = Get-Command Get-SldgTransformer
			$ast = (Get-Command Get-SldgTransformer).ScriptBlock.Ast
			$nameParam = $ast.Body.ParamBlock.Parameters | Where-Object { $_.Name.VariablePath.UserPath -eq 'Name' }
			$nameParam.DefaultValue.Value | Should -Be '*'
		}
	}

	Context "Listing Transformers" {
		It "Returns results without parameters" {
			$result = Get-SldgTransformer
			$result | Should -Not -BeNullOrEmpty
		}

		It "Returns transformers with Name property" {
			$result = Get-SldgTransformer
			$result | ForEach-Object { $_.PSObject.Properties.Name | Should -Contain 'Name' }
		}

		It "Returns transformers with Description property" {
			$result = Get-SldgTransformer
			$result | ForEach-Object { $_.PSObject.Properties.Name | Should -Contain 'Description' }
		}

		It "Returns transformers with TransformFunction property" {
			$result = Get-SldgTransformer
			$result | ForEach-Object { $_.PSObject.Properties.Name | Should -Contain 'TransformFunction' }
		}
	}

	Context "Built-in Transformers" {
		It "Has EntraIdUser transformer" {
			$result = Get-SldgTransformer -Name 'EntraIdUser'
			$result | Should -Not -BeNullOrEmpty
			$result.Name | Should -Be 'EntraIdUser'
		}

		It "Has EntraIdGroup transformer" {
			$result = Get-SldgTransformer -Name 'EntraIdGroup'
			$result | Should -Not -BeNullOrEmpty
			$result.Name | Should -Be 'EntraIdGroup'
		}
	}

	Context "Wildcard Filtering" {
		It "Filters by wildcard pattern" {
			$result = Get-SldgTransformer -Name 'EntraId*'
			@($result).Count | Should -BeGreaterOrEqual 2
		}

		It "Returns nothing for non-matching pattern" {
			$result = Get-SldgTransformer -Name 'ZzzNonExistent*'
			$result | Should -BeNullOrEmpty
		}
	}
}
