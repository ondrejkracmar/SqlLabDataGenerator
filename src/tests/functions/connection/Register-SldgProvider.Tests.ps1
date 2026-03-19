Describe "Register-SldgProvider" {
	BeforeAll {
		Remove-Module SqlLabDataGenerator -ErrorAction Ignore
		Import-Module "$PSScriptRoot\..\..\..\SqlLabDataGenerator\SqlLabDataGenerator.psd1" -Force
		$module = Get-Module SqlLabDataGenerator

		# Define stub functions with correct parameter signatures for provider registration
		function global:Connect-Test { param($ServerInstance, $Database) }
		function global:Get-TestSchema { param($ConnectionInfo) }
		function global:Write-TestData { param($ConnectionInfo, $SchemaName, $TableName, $Data) }
		function global:Read-TestData { param($ConnectionInfo, $SchemaName, $TableName) }
		function global:Disconnect-Test { param($ConnectionInfo) }
		function global:Connect-TestV2 { param($ServerInstance, $Database) }
		function global:Get-TestSchemaV2 { param($ConnectionInfo) }
		function global:Write-TestDataV2 { param($ConnectionInfo, $SchemaName, $TableName, $Data) }
		function global:Read-TestDataV2 { param($ConnectionInfo, $SchemaName, $TableName) }
		function global:Disconnect-TestV2 { param($ConnectionInfo) }
	}

	AfterAll {
		# Clean up any test providers
		& $module { $script:SldgState.Providers.Remove('TestProvider') }
		# Clean up stub functions
		@('Connect-Test','Get-TestSchema','Write-TestData','Read-TestData','Disconnect-Test','Connect-TestV2','Get-TestSchemaV2','Write-TestDataV2','Read-TestDataV2','Disconnect-TestV2') | ForEach-Object { Remove-Item "function:global:$_" -ErrorAction Ignore }
	}

	Context "Parameter Validation" {
		It "Has mandatory Name parameter" {
			$cmd = Get-Command Register-SldgProvider
			$cmd.Parameters['Name'].Attributes.Where({ $_ -is [System.Management.Automation.ParameterAttribute] }).Mandatory | Should -BeTrue
		}

		It "Has mandatory ConnectFunction parameter" {
			$cmd = Get-Command Register-SldgProvider
			$cmd.Parameters['ConnectFunction'].Attributes.Where({ $_ -is [System.Management.Automation.ParameterAttribute] }).Mandatory | Should -BeTrue
		}

		It "Has mandatory GetSchemaFunction parameter" {
			$cmd = Get-Command Register-SldgProvider
			$cmd.Parameters['GetSchemaFunction'].Attributes.Where({ $_ -is [System.Management.Automation.ParameterAttribute] }).Mandatory | Should -BeTrue
		}

		It "Has mandatory WriteDataFunction parameter" {
			$cmd = Get-Command Register-SldgProvider
			$cmd.Parameters['WriteDataFunction'].Attributes.Where({ $_ -is [System.Management.Automation.ParameterAttribute] }).Mandatory | Should -BeTrue
		}

		It "Has mandatory ReadDataFunction parameter" {
			$cmd = Get-Command Register-SldgProvider
			$cmd.Parameters['ReadDataFunction'].Attributes.Where({ $_ -is [System.Management.Automation.ParameterAttribute] }).Mandatory | Should -BeTrue
		}

		It "Has mandatory DisconnectFunction parameter" {
			$cmd = Get-Command Register-SldgProvider
			$cmd.Parameters['DisconnectFunction'].Attributes.Where({ $_ -is [System.Management.Automation.ParameterAttribute] }).Mandatory | Should -BeTrue
		}
	}

	Context "Registration" {
		It "Registers a custom provider successfully" {
			Register-SldgProvider -Name 'TestProvider' `
				-ConnectFunction 'Connect-Test' `
				-GetSchemaFunction 'Get-TestSchema' `
				-WriteDataFunction 'Write-TestData' `
				-ReadDataFunction 'Read-TestData' `
				-DisconnectFunction 'Disconnect-Test'

			$providers = & $module { $script:SldgState.Providers }
			$providers.Keys | Should -Contain 'TestProvider'
		}

		It "Stores correct function map" {
			$provider = & $module { $script:SldgState.Providers['TestProvider'] }
			$provider.FunctionMap.Connect | Should -Be 'Connect-Test'
			$provider.FunctionMap.GetSchema | Should -Be 'Get-TestSchema'
			$provider.FunctionMap.WriteData | Should -Be 'Write-TestData'
			$provider.FunctionMap.ReadData | Should -Be 'Read-TestData'
			$provider.FunctionMap.Disconnect | Should -Be 'Disconnect-Test'
		}

		It "Overwrites existing provider with same name" {
			Register-SldgProvider -Name 'TestProvider' `
				-ConnectFunction 'Connect-TestV2' `
				-GetSchemaFunction 'Get-TestSchemaV2' `
				-WriteDataFunction 'Write-TestDataV2' `
				-ReadDataFunction 'Read-TestDataV2' `
				-DisconnectFunction 'Disconnect-TestV2'

			$provider = & $module { $script:SldgState.Providers['TestProvider'] }
			$provider.FunctionMap.Connect | Should -Be 'Connect-TestV2'
		}
	}

	Context "Built-in Providers" {
		It "SqlServer provider has all required function mappings" {
			$provider = & $module { $script:SldgState.Providers['SqlServer'] }
			$provider.FunctionMap.Keys | Should -Contain 'Connect'
			$provider.FunctionMap.Keys | Should -Contain 'GetSchema'
			$provider.FunctionMap.Keys | Should -Contain 'WriteData'
			$provider.FunctionMap.Keys | Should -Contain 'ReadData'
			$provider.FunctionMap.Keys | Should -Contain 'Disconnect'
		}

		It "SQLite provider has all required function mappings" {
			$provider = & $module { $script:SldgState.Providers['SQLite'] }
			$provider.FunctionMap.Keys | Should -Contain 'Connect'
			$provider.FunctionMap.Keys | Should -Contain 'GetSchema'
			$provider.FunctionMap.Keys | Should -Contain 'WriteData'
			$provider.FunctionMap.Keys | Should -Contain 'ReadData'
			$provider.FunctionMap.Keys | Should -Contain 'Disconnect'
		}
	}
}
