function Get-SldgSession {
	<#
	.SYNOPSIS
		Returns the current SqlLabDataGenerator session state.

	.DESCRIPTION
		Provides a summary of the active session including connection details,
		registered providers, locale packs, AI configuration, cache sizes,
		and generation history.

		Use this to inspect what is currently loaded and active without
		navigating internal state. Useful for diagnostics and scripting.

	.PARAMETER Full
		Returns the raw SldgSession object with all internal collections.
		By default, a summary PSCustomObject is returned.

	.EXAMPLE
		PS C:\> Get-SldgSession

		Returns a summary of the current session.

	.EXAMPLE
		PS C:\> Get-SldgSession -Full

		Returns the raw SldgSession object with all collections.

	.EXAMPLE
		PS C:\> (Get-SldgSession).CacheSizes

		Shows the number of entries in each AI cache.
	#>
	[OutputType([SqlLabDataGenerator.SessionInfo])]
	[OutputType([SqlLabDataGenerator.SldgSession], ParameterSetName = 'Full')]
	[CmdletBinding()]
	param (
		[Parameter(ParameterSetName = 'Full')]
		[switch]$Full
	)

	$session = $script:SldgState

	if ($Full) {
		return $session
	}

	# Connection summary
	$conn = $session.ActiveConnection
	$connectionSummary = if ($conn) {
		[SqlLabDataGenerator.ConnectionSummary]@{
			Provider       = $conn.Provider
			ServerInstance = $conn.ServerInstance
			Database       = $conn.Database
			State          = if ($conn.DbConnection) { $conn.DbConnection.State.ToString() } else { 'Disposed' }
		}
	}
	else { $null }

	# AI provider summary
	$aiProvider = Get-PSFConfigValue -FullName 'SqlLabDataGenerator.AI.Provider'
	$aiModel = Get-PSFConfigValue -FullName 'SqlLabDataGenerator.AI.Model'
	$aiOverrides = [System.Collections.Generic.Dictionary[string, string]]::new()
	foreach ($key in $session.AIModelOverrides.Keys) {
		$override = $session.AIModelOverrides[$key]
		if ($override -is [hashtable]) {
			$aiOverrides[$key] = "$($override.Provider)/$($override.Model)"
		}
	}

	$aiSummary = [SqlLabDataGenerator.AIProviderSummary]@{
		Provider  = $aiProvider
		Model     = $aiModel
		Overrides = if ($aiOverrides.Count -gt 0) { $aiOverrides } else { $null }
	}

	# Cache sizes
	$cacheSizes = [SqlLabDataGenerator.CacheSummary]@{
		AIValueCache          = $session.AIValueCache.Count
		AILocaleCache         = $session.AILocaleCache.Count
		AILocaleCategoryCache = $session.AILocaleCategoryCache.Count
		CacheTimestamps       = $session.CacheTimestamps.Count
	}

	# Generation history
	$generationHistory = @()
	foreach ($key in $session.GeneratedData.Keys) {
		$data = $session.GeneratedData[$key]
		if ($data) {
			$generationHistory += [SqlLabDataGenerator.GenerationHistoryEntry]@{
				Database = $key
				Tables   = if ($data -is [array]) { $data.Count } else { 1 }
			}
		}
	}

	[SqlLabDataGenerator.SessionInfo]@{
		SessionId              = $session.SessionId
		CreatedAt              = $session.CreatedAt
		Connection             = $connectionSummary
		AIProvider             = $aiSummary
		RegisteredProviders    = @($session.Providers.Keys)
		RegisteredTransformers = @($session.Transformers.Keys)
		RegisteredLocales      = @($session.Locales.Keys)
		CacheSizes             = $cacheSizes
		GenerationPlans        = @($session.GenerationPlans.Keys)
		GenerationHistory      = $generationHistory
	}
}
