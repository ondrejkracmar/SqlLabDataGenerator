function Test-SldgCacheExpired {
	<#
	.SYNOPSIS
		Checks whether a cache entry has exceeded the configured TTL.
	.DESCRIPTION
		Centralizes the TTL expiration check used across AIValueCache,
		AILocaleCache, and AILocaleCategoryCache. Returns $true if the
		entry is expired (or has no timestamp), $false if still valid.
	#>
	[OutputType([bool])]
	[CmdletBinding()]
	param (
		[Parameter(Mandatory)]
		[string]$CacheName,

		[Parameter(Mandatory)]
		[string]$Key
	)

	$ttlMinutes = Get-PSFConfigValue -FullName 'SqlLabDataGenerator.Cache.TTLMinutes'
	if ($ttlMinutes -le 0) { return $false }

	$tsKey = "$CacheName|$Key"
	if (-not $script:SldgState.CacheTimestamps.ContainsKey($tsKey)) { return $false }

	([datetime]::UtcNow - $script:SldgState.CacheTimestamps[$tsKey]).TotalMinutes -gt $ttlMinutes
}
