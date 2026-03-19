function Register-SldgProvider {
	<#
	.SYNOPSIS
		Registers a custom database provider for data generation.

	.DESCRIPTION
		Registers a new database provider that implements the required interface
		for schema discovery and data operations. This enables support for
		databases beyond the built-in SQL Server provider.

		Each provider must supply functions for: Connect, GetSchema, WriteData, ReadData, Disconnect.

	.PARAMETER Name
		Unique name for the provider (e.g., 'PostgreSQL', 'Oracle', 'MySQL').

	.PARAMETER ConnectFunction
		Name of the function that establishes a database connection.

	.PARAMETER GetSchemaFunction
		Name of the function that reads the database schema.

	.PARAMETER WriteDataFunction
		Name of the function that writes generated data to a table.

	.PARAMETER ReadDataFunction
		Name of the function that reads existing data from a table.

	.PARAMETER DisconnectFunction
		Name of the function that closes the database connection.

	.EXAMPLE
		PS C:\> Register-SldgProvider -Name 'PostgreSQL' `
		>>     -ConnectFunction 'Connect-PostgreSql' `
		>>     -GetSchemaFunction 'Get-PostgreSqlSchema' `
		>>     -WriteDataFunction 'Write-PostgreSqlData' `
		>>     -ReadDataFunction 'Read-PostgreSqlData' `
		>>     -DisconnectFunction 'Disconnect-PostgreSql'

		Registers a PostgreSQL provider with all required interface functions.
	#>
	[CmdletBinding()]
	param (
		[Parameter(Mandatory)]
		[string]$Name,

		[Parameter(Mandatory)]
		[string]$ConnectFunction,

		[Parameter(Mandatory)]
		[string]$GetSchemaFunction,

		[Parameter(Mandatory)]
		[string]$WriteDataFunction,

		[Parameter(Mandatory)]
		[string]$ReadDataFunction,

		[Parameter(Mandatory)]
		[string]$DisconnectFunction
	)

	$functionMap = @{
		Connect    = $ConnectFunction
		GetSchema  = $GetSchemaFunction
		WriteData  = $WriteDataFunction
		ReadData   = $ReadDataFunction
		Disconnect = $DisconnectFunction
	}

	Register-SldgProviderInternal -Name $Name -FunctionMap $functionMap
}
