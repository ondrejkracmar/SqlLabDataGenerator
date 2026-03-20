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

	if ($ConnectionInfo.DbConnection -and $ConnectionInfo.DbConnection.State -ne 'Closed') {
		$ConnectionInfo.DbConnection.Close()
		$ConnectionInfo.DbConnection.Dispose()
		Write-PSFMessage -Level Verbose -String 'Connect.SqlServer.Disconnected' -StringValues $ConnectionInfo.ServerInstance
	}
}
