function Get-SldgProviderInternal {
	<#
	.SYNOPSIS
		Gets a registered database provider by name, or all providers.
	#>
	[CmdletBinding()]
	param (
		[string]$Name
	)

	if ($Name) {
		$provider = $script:SldgState.Providers[$Name]
		if (-not $provider) {
			$available = ($script:SldgState.Providers.Keys | Sort-Object) -join ', '
			Stop-PSFFunction -Message ($script:strings.'Provider.NotFound' -f $Name, $available) -EnableException $true
		}
		return $provider
	}

	$script:SldgState.Providers.Values
}
