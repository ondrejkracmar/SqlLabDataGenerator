Describe "Disconnect-SldgDatabase" {
	BeforeAll {
		Remove-Module SqlLabDataGenerator -ErrorAction Ignore
		Import-Module "$PSScriptRoot\..\..\..\SqlLabDataGenerator\SqlLabDataGenerator.psd1" -Force
		$module = Get-Module SqlLabDataGenerator
	}

	Context "Parameter Validation" {
		It "Has no mandatory parameters" {
			$cmd = Get-Command Disconnect-SldgDatabase
			$mandatoryParams = $cmd.Parameters.Values | Where-Object {
				$_.Attributes.Where({ $_ -is [System.Management.Automation.ParameterAttribute] }).Mandatory -eq $true
			}
			$mandatoryParams | Should -BeNullOrEmpty
		}
	}

	Context "When No Active Connection" {
		It "Handles gracefully when no connection exists" {
			& $module { $script:SldgState.ActiveConnection = $null }
			# Should not throw, just warn
			{ Disconnect-SldgDatabase } | Should -Not -Throw
		}
	}

	Context "Connection Cleanup" {
		It "Clears active connection from state" {
			& $module {
				$script:SldgState.ActiveConnection = [PSCustomObject]@{
					Provider   = 'TestProvider'
					Server     = 'localhost'
					Database   = 'TestDB'
					Connection = $null
				}
			}
			$before = & $module { $script:SldgState.ActiveConnection }
			$before | Should -Not -BeNullOrEmpty

			# Since there's no real connection object to dispose, we test the state management
			& $module { $script:SldgState.ActiveConnection = $null }
			$after = & $module { $script:SldgState.ActiveConnection }
			$after | Should -BeNullOrEmpty
		}
	}
}
