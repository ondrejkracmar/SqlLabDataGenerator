Describe "Get-SldgDatabaseSchema" {
	BeforeAll {
		Remove-Module SqlLabDataGenerator -ErrorAction Ignore
		Import-Module "$PSScriptRoot\..\..\..\SqlLabDataGenerator\SqlLabDataGenerator.psd1" -Force
		$module = Get-Module SqlLabDataGenerator
	}

	Context "Parameter Validation" {
		It "SchemaFilter accepts string array" {
			$cmd = Get-Command Get-SldgDatabaseSchema
			$cmd.Parameters['SchemaFilter'].ParameterType.Name | Should -Be 'String[]'
		}

		It "TableFilter accepts string array" {
			$cmd = Get-Command Get-SldgDatabaseSchema
			$cmd.Parameters['TableFilter'].ParameterType.Name | Should -Be 'String[]'
		}

		It "Has optional ConnectionInfo parameter" {
			$cmd = Get-Command Get-SldgDatabaseSchema
			$cmd.Parameters.ContainsKey('ConnectionInfo') | Should -BeTrue
		}

		It "SchemaFilter is not mandatory" {
			$cmd = Get-Command Get-SldgDatabaseSchema
			$attr = $cmd.Parameters['SchemaFilter'].Attributes.Where({ $_ -is [System.Management.Automation.ParameterAttribute] })
			if ($attr) {
				$attr.Mandatory | Should -BeFalse
			}
		}

		It "TableFilter is not mandatory" {
			$cmd = Get-Command Get-SldgDatabaseSchema
			$attr = $cmd.Parameters['TableFilter'].Attributes.Where({ $_ -is [System.Management.Automation.ParameterAttribute] })
			if ($attr) {
				$attr.Mandatory | Should -BeFalse
			}
		}
	}

	Context "Without Active Connection" {
		BeforeAll {
			& $module { $script:SldgState.ActiveConnection = $null }
		}

		It "Throws when no connection is available" {
			{ Get-SldgDatabaseSchema -ErrorAction Stop } | Should -Throw
		}
	}
}
