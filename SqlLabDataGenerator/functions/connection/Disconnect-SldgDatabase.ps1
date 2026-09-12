function Disconnect-SldgDatabase {
	<#
	.SYNOPSIS
		Disconnects from the active database connection.

	.DESCRIPTION
		Closes the active connection established by Connect-SldgDatabase and releases the
		PSSqlRepository session behind it.

	.EXAMPLE
		PS C:\> Disconnect-SldgDatabase

		Disconnects from the currently active database.
	#>
	[OutputType([void])]
	[CmdletBinding()]
	param ()

	$connectionInfo = $script:SldgState.ActiveConnection
	if (-not $connectionInfo) {
		Write-PSFMessage -Level Warning -String 'Disconnect.NoActive'
		return
	}

	Write-PSFMessage -Level Host -String 'Disconnect.Disconnecting' -StringValues $connectionInfo.Provider, $connectionInfo.ServerInstance, $connectionInfo.Database

	Disconnect-SldgRepositorySession -ConnectionInfo $connectionInfo

	$script:SldgState.ActiveConnection = $null
	$script:SldgState.ActiveProvider = $null
}
