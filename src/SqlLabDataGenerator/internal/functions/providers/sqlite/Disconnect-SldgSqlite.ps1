function Disconnect-SldgSqlite {
	<#
	.SYNOPSIS
		Closes and disposes the SQLite connection.
	#>
	[CmdletBinding()]
	param (
		[Parameter(Mandatory)]
		$ConnectionInfo
	)

	if ($ConnectionInfo.DbConnection) {
		try {
			$ConnectionInfo.DbConnection.Close()
			$ConnectionInfo.DbConnection.Dispose()
			Write-PSFMessage -Level Verbose -Message ($script:strings.'Connect.SQLite.Disconnected' -f $ConnectionInfo.Database)
		}
		catch {
			Write-PSFMessage -Level Warning -Message ($script:strings.'Connect.SQLite.DisconnectFailed' -f $_)
		}
	}
}
