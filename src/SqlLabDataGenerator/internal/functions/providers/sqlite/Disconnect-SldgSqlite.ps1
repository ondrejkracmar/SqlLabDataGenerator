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
			Write-PSFMessage -Level Verbose -String 'Connect.SQLite.Disconnected' -StringValues $ConnectionInfo.Database
		}
		catch {
			Write-PSFMessage -Level Warning -String 'Connect.SQLite.DisconnectFailed' -StringValues $_
		}
	}
}
