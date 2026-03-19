function Invoke-SldgCacheEviction {
	<#
	.SYNOPSIS
		Evicts expired or overflow entries from module caches.
	.DESCRIPTION
		Checks each module cache (AILocaleCache, AILocaleCategoryCache, AIValueCache)
		and removes entries that exceed the configured max-size or TTL.
		Called automatically before cache writes.
	#>
	[CmdletBinding()]
	param (
		[Parameter(Mandatory)]
		[hashtable]$Cache,

		[string]$CacheName = 'Unknown'
	)

	$maxEntries = Get-PSFConfigValue -FullName 'SqlLabDataGenerator.Cache.MaxEntries'
	$ttlMinutes = Get-PSFConfigValue -FullName 'SqlLabDataGenerator.Cache.TTLMinutes'

	# TTL eviction: remove expired entries based on their timestamp
	$timestampCache = $script:SldgState.CacheTimestamps
	if ($timestampCache -and $ttlMinutes -gt 0) {
		$now = [datetime]::UtcNow
		$expiredKeys = @(foreach ($key in @($Cache.Keys)) {
			$tsKey = "$CacheName|$key"
			if ($timestampCache.ContainsKey($tsKey) -and ($now - $timestampCache[$tsKey]).TotalMinutes -gt $ttlMinutes) {
				$key
			}
		})
		foreach ($key in $expiredKeys) {
			$Cache.Remove($key)
			$timestampCache.Remove("$CacheName|$key")
		}
		if ($expiredKeys.Count -gt 0) {
			Write-PSFMessage -Level Verbose -Message "Cache '$CacheName': TTL-evicted $($expiredKeys.Count) expired entries"
		}
	}

	# Size eviction: remove oldest entries (by timestamp) if over max
	if ($Cache.Count -le $maxEntries) { return }

	$toRemove = $Cache.Count - $maxEntries
	# Sort by insertion timestamp so we evict truly oldest entries, not random hashtable order
	$sortedKeys = @($Cache.Keys) | Sort-Object {
		$tsKey = "$CacheName|$_"
		if ($timestampCache -and $timestampCache.ContainsKey($tsKey)) { $timestampCache[$tsKey] } else { [datetime]::MinValue }
	}
	for ($i = 0; $i -lt $toRemove; $i++) {
		$Cache.Remove($sortedKeys[$i])
		if ($timestampCache) { $timestampCache.Remove("$CacheName|$($sortedKeys[$i])") }
	}

	Write-PSFMessage -Level Verbose -Message "Cache '$CacheName': size-evicted $toRemove entries (max: $maxEntries)"
}
