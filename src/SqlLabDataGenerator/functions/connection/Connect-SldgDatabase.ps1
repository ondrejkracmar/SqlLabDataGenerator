function Connect-SldgDatabase {
	<#
	.SYNOPSIS
		Connects to a database for schema discovery and data generation.

	.DESCRIPTION
		Establishes a connection to a database using the specified provider.
		The connection is stored as the active connection for subsequent commands.
		Currently supports SQL Server via the built-in SqlServer provider.

	.PARAMETER ServerInstance
		The server instance to connect to (e.g., 'localhost', 'server\instance', 'server,port').

	.PARAMETER Database
		The database name to connect to.

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
	#>
	[CmdletBinding()]
	param (
		[Parameter(Mandatory)]
		[string]$ServerInstance,

		[Parameter(Mandatory)]
		[string]$Database,

		[string]$Provider = 'SqlServer',

		[PSCredential]$Credential,

		[switch]$TrustServerCertificate,

		[int]$ConnectionTimeout = 30
	)

	# Validate provider
	$providerInfo = Get-SldgProviderInternal -Name $Provider

	Write-PSFMessage -Level Host -Message ($script:strings.'Connect.Connecting' -f $Provider, $Database, $ServerInstance)

	# Call provider's connect function
	$params = @{
		ServerInstance        = $ServerInstance
		Database              = $Database
		ConnectionTimeout     = $ConnectionTimeout
	}
	if ($Credential) { $params['Credential'] = $Credential }
	if ($TrustServerCertificate) { $params['TrustServerCertificate'] = $TrustServerCertificate }

	$connectionInfo = & $providerInfo.FunctionMap.Connect @params

	# Validate connection is alive before storing
	if ($connectionInfo.Connection -and $connectionInfo.Connection.State -ne 'Open') {
		Stop-PSFFunction -Message ($script:strings.'Connect.Failed' -f $Provider, $ServerInstance, $Database, 'Connection is not in Open state after connect.') -EnableException $true
	}

	# Store as active connection
	$script:SldgState.ActiveConnection = $connectionInfo
	$script:SldgState.ActiveProvider = $Provider

	Write-PSFMessage -Level Host -Message ($script:strings.'Connect.Success' -f $Provider, $ServerInstance, $Database)

	$connectionInfo
}
