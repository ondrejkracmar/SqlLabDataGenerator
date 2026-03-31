function Clear-SldgCache {
	<#
	.SYNOPSIS
		Clears AI-generated data caches without affecting connection or registrations.

	.DESCRIPTION
		Removes all cached AI-generated values, locale data, and locale categories.
		The active database connection, registered providers, transformers, locales,
		generation plans, and AI model overrides are preserved.

		Use this when:
		- You changed the AI provider or model and want fresh generation
		- You updated prompt templates and want to see the effect
		- Cached data appears stale or incorrect
		- You want to free memory used by AI caches

	.PARAMETER CacheName
		Optional. Clear only a specific cache: AIValueCache, AILocaleCache, or AILocaleCategoryCache.
		If not specified, all caches are cleared.

	.EXAMPLE
		PS C:\> Clear-SldgCache

		Clears all AI caches.

	.EXAMPLE
		PS C:\> Clear-SldgCache -CacheName AIValueCache

		Clears only the AI batch value cache (keeps locale caches).
	#>
	[OutputType([void])]
	[CmdletBinding(SupportsShouldProcess)]
	param (
		[ValidateSet('AIValueCache', 'AILocaleCache', 'AILocaleCategoryCache')]
		[string]$CacheName
	)

	$session = $script:SldgState

	if ($CacheName) {
		if (-not $PSCmdlet.ShouldProcess($CacheName, 'Clear cache')) { return }

		$count = $session.$CacheName.Count
		$session.$CacheName.Clear()

		# Clear related timestamps
		$timestampPrefix = "${CacheName}$($script:CacheKeySeparator)"
		$keysToRemove = @($session.CacheTimestamps.Keys | Where-Object { $_.StartsWith($timestampPrefix) })
		foreach ($key in $keysToRemove) {
			[void]$session.CacheTimestamps.TryRemove($key, [ref]$null)
		}

		Write-PSFMessage -Level Host -String 'Cache.Cleared' -StringValues $count, $CacheName
	}
	else {
		if (-not $PSCmdlet.ShouldProcess('All AI caches', 'Clear cache')) { return }

		$totalCount = $session.AIValueCache.Count + $session.AILocaleCache.Count + $session.AILocaleCategoryCache.Count

		$session.ClearCaches()

		Write-PSFMessage -Level Host -String 'Cache.ClearedAll' -StringValues $totalCount
	}
}
