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
		try {
			$ConnectionInfo.DbConnection.Close()
			$ConnectionInfo.DbConnection.Dispose()
			Write-PSFMessage -Level Verbose -Message ($script:strings.'Connect.SqlServer.Disconnected' -f $ConnectionInfo.ServerInstance)
		}
		catch {
			Write-PSFMessage -Level Warning -Message ($script:strings.'Connect.SqlServer.DisconnectFailed' -f $ConnectionInfo.ServerInstance, $_)
		}
	}
}
