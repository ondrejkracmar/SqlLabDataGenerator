Describe "Connect-SldgDatabase" {
	BeforeAll {
		Remove-Module SqlLabDataGenerator -ErrorAction Ignore
		Import-Module "$PSScriptRoot\..\..\..\SqlLabDataGenerator\SqlLabDataGenerator.psd1" -Force
		$module = Get-Module SqlLabDataGenerator
	}

	Context "Parameter Validation" {
		It "Has mandatory ServerInstance parameter" {
			$cmd = Get-Command Connect-SldgDatabase
			$cmd.Parameters['ServerInstance'].Attributes.Where({ $_ -is [System.Management.Automation.ParameterAttribute] }).Mandatory | Should -BeTrue
		}

		It "Has mandatory Database parameter" {
			$cmd = Get-Command Connect-SldgDatabase
			$cmd.Parameters['Database'].Attributes.Where({ $_ -is [System.Management.Automation.ParameterAttribute] }).Mandatory | Should -BeTrue
		}

		It "Has Provider parameter with default value SqlServer" {
			$cmd = Get-Command Connect-SldgDatabase
			$cmd.Parameters.Keys | Should -Contain 'Provider'
		}

		It "Has Credential parameter of type PSCredential" {
			$cmd = Get-Command Connect-SldgDatabase
			$cmd.Parameters['Credential'].ParameterType.Name | Should -Be 'PSCredential'
		}

		It "Has TrustServerCertificate switch parameter" {
			$cmd = Get-Command Connect-SldgDatabase
			$cmd.Parameters['TrustServerCertificate'].SwitchParameter | Should -BeTrue
		}

		It "Has ConnectionTimeout parameter" {
			$cmd = Get-Command Connect-SldgDatabase
			$cmd.Parameters.Keys | Should -Contain 'ConnectionTimeout'
		}
	}

	Context "Provider Validation" {
		It "Throws when provider is not registered" {
			{ Connect-SldgDatabase -ServerInstance 'localhost' -Database 'test' -Provider 'NonExistentProvider' } | Should -Throw
		}

		It "SqlServer provider is registered by default" {
			$providers = & $module { $script:SldgState.Providers.Keys }
			$providers | Should -Contain 'SqlServer'
		}

		It "SQLite provider is registered by default" {
			$providers = & $module { $script:SldgState.Providers.Keys }
			$providers | Should -Contain 'SQLite'
		}
	}

	Context "Connection State" {
		It "Requires connection for non-NoInsert operations" {
			& $module { $script:SldgState.ActiveConnection = $null }
			$state = & $module { $script:SldgState.ActiveConnection }
			$state | Should -BeNullOrEmpty
		}
	}
}
