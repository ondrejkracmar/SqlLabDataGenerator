function Connect-SldgDatabase {
	<#
	.SYNOPSIS
		Connects to a database for schema discovery and data generation.

	.DESCRIPTION
		Establishes a connection to a database using the specified provider.
		The connection is stored as the active connection for subsequent commands.

		Use the Server parameter set for SQL Server (ServerInstance + Database).
		Use the File parameter set for file-based databases like SQLite (Database path only).

	.PARAMETER ServerInstance
		The server instance to connect to (e.g., 'localhost', 'server\instance', 'server,port').
		Used with the Server parameter set (SQL Server, etc.).

	.PARAMETER Database
		The database name (Server set) or database file path (File set) to connect to.

	.PARAMETER Provider
		The database provider to use. Default is 'SqlServer'.

	.PARAMETER Credential
		SQL authentication credentials. If not specified, Windows/Integrated authentication is used.

	.PARAMETER TrustServerCertificate
		Whether to trust the server certificate without validation.

	.PARAMETER ConnectionTimeout
		Connection timeout in seconds. Default is 30.

	.EXAMPLE
		PS C:\> Connect-SldgDatabase -ServerInstance 'localhost' -Database 'AdventureWorks'

		Connects to AdventureWorks on localhost using Windows authentication.

	.EXAMPLE
		PS C:\> $cred = Get-Credential
		PS C:\> Connect-SldgDatabase -ServerInstance 'dbserver\SQLEXPRESS' -Database 'TestDB' -Credential $cred

		Connects using SQL authentication.

	.EXAMPLE
		PS C:\> Connect-SldgDatabase -Provider 'SQLite' -Database 'C:\Data\mydb.sqlite'

		Connects to a SQLite database file (ServerInstance is not required).
	#>
	[OutputType([SqlLabDataGenerator.Connection])]
	[CmdletBinding(DefaultParameterSetName = 'Server')]
	param (
		[Parameter(Mandatory, ParameterSetName = 'Server')]
		[ValidateNotNullOrEmpty()]
		[string]$ServerInstance,

		[Parameter(Mandatory)]
		[ValidateNotNullOrEmpty()]
		[string]$Database,

		[string]$Provider = 'SqlServer',

		[PSCredential]$Credential,

		[switch]$TrustServerCertificate,

		[int]$ConnectionTimeout = 30
	)

	# Validate provider
	$providerInfo = Get-SldgProviderInternal -Name $Provider

	$displayServer = if ($ServerInstance) { $ServerInstance } else { 'localhost' }
	Write-PSFMessage -Level Host -Message ($script:strings.'Connect.Connecting' -f $Provider, $Database, $displayServer)

	# Call provider's connect function
	$params = @{
		Database              = $Database
		ConnectionTimeout     = $ConnectionTimeout
	}
	if ($ServerInstance) { $params['ServerInstance'] = $ServerInstance }
	if ($Credential) { $params['Credential'] = $Credential }
	if ($TrustServerCertificate) { $params['TrustServerCertificate'] = $TrustServerCertificate }

	$connectionInfo = & $providerInfo.FunctionMap.Connect @params

	# Validate connection is alive before storing
	if ($connectionInfo.DbConnection -and $connectionInfo.DbConnection.State -ne 'Open') {
		Stop-PSFFunction -Message ($script:strings.'Connect.Failed' -f $Provider, $displayServer, $Database, 'Connection is not in Open state after connect.') -EnableException $true
	}

	# Store as active connection
	$script:SldgState.ActiveConnection = $connectionInfo
	$script:SldgState.ActiveProvider = $Provider

	Write-PSFMessage -Level Host -Message ($script:strings.'Connect.Success' -f $Provider, $displayServer, $Database)

	$connectionInfo
}
