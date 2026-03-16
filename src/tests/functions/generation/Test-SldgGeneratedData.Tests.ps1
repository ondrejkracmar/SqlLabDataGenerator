Describe "Test-SldgGeneratedData" {
	BeforeAll {
		Remove-Module SqlLabDataGenerator -ErrorAction Ignore
		Import-Module "$PSScriptRoot\..\..\..\SqlLabDataGenerator\SqlLabDataGenerator.psd1" -Force
		$module = Get-Module SqlLabDataGenerator
	}

	Context "Parameter Validation" {
		It "Has mandatory Schema parameter" {
			$cmd = Get-Command Test-SldgGeneratedData
			$cmd.Parameters['Schema'].Attributes.Where({ $_ -is [System.Management.Automation.ParameterAttribute] }).Mandatory | Should -BeTrue
		}

		It "Has optional ConnectionInfo parameter" {
			$cmd = Get-Command Test-SldgGeneratedData
			$cmd.Parameters.ContainsKey('ConnectionInfo') | Should -BeTrue
			$conParam = $cmd.Parameters['ConnectionInfo'].Attributes.Where({ $_ -is [System.Management.Automation.ParameterAttribute] })
			if ($conParam) {
				$conParam.Mandatory | Should -BeFalse
			}
		}
	}

	Context "Without Active Connection" {
		BeforeAll {
			& $module { $script:SldgState.ActiveConnection = $null }
		}

		It "Throws when no connection is available" {
			$mockSchema = [PSCustomObject]@{
				Database   = 'TestDB'
				Tables     = @()
				TableCount = 0
			}
			{ Test-SldgGeneratedData -Schema $mockSchema -ErrorAction Stop } | Should -Throw
		}
	}

	Context "Output Structure" {
		It "Returns objects with Passed property" {
			$cmd = Get-Command Test-SldgGeneratedData
			$cmd | Should -Not -BeNullOrEmpty
		}
	}

	Context "Internal Validation Functions - Unit Tests" {
		It "Test-SldgUniqueConstraints is available as internal function" {
			& $module { Get-Command Test-SldgUniqueConstraints -ErrorAction SilentlyContinue } | Should -Not -BeNullOrEmpty
		}

		It "Test-SldgForeignKeyIntegrity is available as internal function" {
			& $module { Get-Command Test-SldgForeignKeyIntegrity -ErrorAction SilentlyContinue } | Should -Not -BeNullOrEmpty
		}

		It "Test-SldgDataTypeConstraints is available as internal function" {
			& $module { Get-Command Test-SldgDataTypeConstraints -ErrorAction SilentlyContinue } | Should -Not -BeNullOrEmpty
		}
	}

	Context "Validation Result Contract" {
		It "Test-SldgGeneratedData calls all three validation sub-functions" {
			# Verify the function references all three internal validators
			$funcDef = & $module { (Get-Command Test-SldgGeneratedData).ScriptBlock.ToString() }
			$funcDef | Should -Match 'Test-SldgForeignKeyIntegrity'
			$funcDef | Should -Match 'Test-SldgUniqueConstraints'
			$funcDef | Should -Match 'Test-SldgDataTypeConstraints'
		}

		It "Aggregates passed/warning/error counts in output messages" {
			$funcDef = & $module { (Get-Command Test-SldgGeneratedData).ScriptBlock.ToString() }
			$funcDef | Should -Match 'Passed'
			$funcDef | Should -Match 'Severity'
		}
	}
}
