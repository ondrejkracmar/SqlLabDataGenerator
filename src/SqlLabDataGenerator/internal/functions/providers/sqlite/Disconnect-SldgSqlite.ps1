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

	if ($ConnectionInfo.Connection) {
		try {
			$ConnectionInfo.Connection.Close()
			$ConnectionInfo.Connection.Dispose()
			Write-PSFMessage -Level Verbose -Message "Disconnected from SQLite database '$($ConnectionInfo.Database)'"
		}
		catch {
			Write-PSFMessage -Level Warning -Message "Error disconnecting from SQLite: $_"
		}
	}
}
