function Assert-SldgConnectionOpen {
	<#
	.SYNOPSIS
		Validates that the database connection is in Open state.
	.DESCRIPTION
		Centralizes the connection staleness check used by multiple public commands.
		Throws a terminating error via Stop-PSFFunction when the connection is not open.
	#>
	[CmdletBinding()]
	param (
		[Parameter(Mandatory)]
		$ConnectionInfo
	)

	if ($ConnectionInfo.DbConnection -and $ConnectionInfo.DbConnection.State -ne 'Open') {
		Stop-PSFFunction -Message ($script:strings.'Connect.HealthCheckFailed' -f $ConnectionInfo.Provider, $ConnectionInfo.ServerInstance, $ConnectionInfo.Database) -EnableException $true
	}
}
