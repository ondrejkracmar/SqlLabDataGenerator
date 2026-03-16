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

	$builder = New-Object System.Data.SqlClient.SqlConnectionStringBuilder
	$builder['Data Source'] = $ServerInstance
	$builder['Initial Catalog'] = $Database
	$builder['Connection Timeout'] = $ConnectionTimeout

	if ($TrustServerCertificate) {
		$builder['TrustServerCertificate'] = $true
	}

	if ($Credential) {
		$builder['User ID'] = $Credential.UserName
		$builder['Password'] = $Credential.GetNetworkCredential().Password
	}
	else {
		$builder['Integrated Security'] = $true
	}

	$connection = New-Object System.Data.SqlClient.SqlConnection($builder.ConnectionString)
	try {
		$connection.Open()
		Write-PSFMessage -Level Verbose -Message "Connected to SQL Server '$ServerInstance' database '$Database'"
	}
	catch {
		Stop-PSFFunction -Message ($script:strings.'Connect.Failed' -f 'SqlServer', $ServerInstance, $Database, $_) -EnableException $true -ErrorRecord $_
	}

	[PSCustomObject]@{
		PSTypeName     = 'SqlLabDataGenerator.Connection'
		Connection     = $connection
		ServerInstance = $ServerInstance
		Database       = $Database
		Provider       = 'SqlServer'
		ConnectedAt    = Get-Date
	}
}
