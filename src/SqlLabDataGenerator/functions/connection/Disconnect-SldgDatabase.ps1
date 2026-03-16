function Disconnect-SldgDatabase {
	<#
	.SYNOPSIS
		Disconnects from the active database connection.

	.DESCRIPTION
		Closes and disposes the active database connection established by Connect-SldgDatabase.

	.EXAMPLE
		PS C:\> Disconnect-SldgDatabase

		Disconnects from the currently active database.
	#>
	[CmdletBinding()]
	param ()

	$connectionInfo = $script:SldgState.ActiveConnection
	if (-not $connectionInfo) {
		Write-PSFMessage -Level Warning -Message $script:strings.'Disconnect.NoActive'
		return
	}

	$provider = Get-SldgProviderInternal -Name $connectionInfo.Provider
	Write-PSFMessage -Level Host -Message ($script:strings.'Disconnect.Disconnecting' -f $connectionInfo.Provider, $connectionInfo.ServerInstance, $connectionInfo.Database)

	& $provider.FunctionMap.Disconnect -ConnectionInfo $connectionInfo

	$script:SldgState.ActiveConnection = $null
	$script:SldgState.ActiveProvider = $null
}
