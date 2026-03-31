function Connect-SldgSqlServer {
	<#
	.SYNOPSIS
		Opens a SQL Server connection using SqlClient.
	#>
	[CmdletBinding()]
	param (
		[Parameter(Mandatory)]
		[string]$ServerInstance,

		[Parameter(Mandatory)]
		[string]$Database,

		[PSCredential]$Credential,

		[switch]$TrustServerCertificate,

		[int]$ConnectionTimeout = 30
	)

	$builder = New-Object Microsoft.Data.SqlClient.SqlConnectionStringBuilder
	$builder['Data Source'] = $ServerInstance
	$builder['Initial Catalog'] = $Database
	$builder['Connection Timeout'] = $ConnectionTimeout

	if ($TrustServerCertificate) {
		$builder['TrustServerCertificate'] = $true
	}

	if ($Credential) {
		$builder['User ID'] = $Credential.UserName
		$builder['Password'] = $Credential.GetNetworkCredential().Password
		$builder['Persist Security Info'] = $false
		Write-PSFMessage -Level Verbose -String 'Connect.SqlServer.CredentialWarning'
	}
	else {
		$builder['Integrated Security'] = $true
	}

	# Pass connection string directly to SqlConnection and clear builder immediately
	$connection = New-Object Microsoft.Data.SqlClient.SqlConnection($builder.ConnectionString)
	if ($Credential) { $builder['Password'] = ''; $builder.Clear() }
	try {
		$connection.Open()
		Write-PSFMessage -Level Verbose -String 'Connect.SqlServer.Connected' -StringValues $ServerInstance, $Database
	}
	catch {
		Stop-PSFFunction -Message ($script:strings.'Connect.Failed' -f 'SqlServer', $ServerInstance, $Database, $_) -EnableException $true -ErrorRecord $_
	}

	[SqlLabDataGenerator.Connection]@{
		DbConnection   = $connection
		ServerInstance = $ServerInstance
		Database       = $Database
		Provider       = 'SqlServer'
		ConnectedAt    = Get-Date
	}
}
