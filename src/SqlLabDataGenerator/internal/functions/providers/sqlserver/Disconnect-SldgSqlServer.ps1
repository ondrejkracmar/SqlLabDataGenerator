function Disconnect-SldgSqlServer {
	<#
	.SYNOPSIS
		Closes and disposes a SQL Server connection.
	#>
	[CmdletBinding()]
	param (
		[Parameter(Mandatory)]
		$ConnectionInfo
	)

	if ($ConnectionInfo.Connection -and $ConnectionInfo.Connection.State -ne 'Closed') {
		$ConnectionInfo.Connection.Close()
		$ConnectionInfo.Connection.Dispose()
		Write-PSFMessage -Level Verbose -Message "Disconnected from SQL Server '$($ConnectionInfo.ServerInstance)'"
	}
}
