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

	# S-1: Use SqlCredential to keep the password in a SecureString instead of
	# extracting it to a managed string via GetNetworkCredential().Password.
	# SqlCredential requires that the connection string does NOT contain
	# 'User ID', 'Password', or 'Integrated Security'.
	$sqlCredential = $null
	if ($Credential) {
		$securePassword = $Credential.Password.Copy()
		$securePassword.MakeReadOnly()
		$sqlCredential = [Microsoft.Data.SqlClient.SqlCredential]::new($Credential.UserName, $securePassword)
		Write-PSFMessage -Level Verbose -Message $script:strings.'Connect.SqlServer.CredentialWarning'
	}
	else {
		$builder['Integrated Security'] = $true
	}

	$connection = New-Object Microsoft.Data.SqlClient.SqlConnection($builder.ConnectionString)
	if ($sqlCredential) { $connection.Credential = $sqlCredential }
	try {
		$connection.Open()
		Write-PSFMessage -Level Verbose -Message ($script:strings.'Connect.SqlServer.Connected' -f $ServerInstance, $Database)
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
