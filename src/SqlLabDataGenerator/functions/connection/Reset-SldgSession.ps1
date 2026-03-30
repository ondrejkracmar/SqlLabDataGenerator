function Reset-SldgSession {
	<#
	.SYNOPSIS
		Resets the SqlLabDataGenerator session to a clean state.

	.DESCRIPTION
		Closes the active database connection, clears all registered providers,
		transformers, locales, generation plans, AI caches, and model overrides.

		After reset, the module behaves as if freshly imported — built-in providers
		and locales are NOT re-registered automatically. Use Import-Module -Force
		if you need a fresh module import with built-in registrations.

		Use Clear-SldgCache if you only want to clear AI caches without losing
		connection and registrations.

	.PARAMETER Force
		Skips the confirmation prompt.

	.EXAMPLE
		PS C:\> Reset-SldgSession

		Prompts for confirmation, then resets the entire session.

	.EXAMPLE
		PS C:\> Reset-SldgSession -Force

		Resets the session without confirmation.
	#>
	[OutputType([void])]
	[CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]
	param (
		[switch]$Force
	)

	if ($Force -or $PSCmdlet.ShouldProcess('SqlLabDataGenerator session', 'Reset all state (connection, providers, caches, plans)')) {
		$session = $script:SldgState

		# Log what is being cleared for diagnostics
		$connInfo = $session.ActiveConnection
		if ($connInfo) {
			Write-PSFMessage -Level Verbose -String 'Session.ClosingConnection' -StringValues $connInfo.Provider, $connInfo.Database
		}

		$providerCount = $session.Providers.Count
		$localeCount = $session.Locales.Count
		$cacheTotal = $session.AIValueCache.Count + $session.AILocaleCache.Count + $session.AILocaleCategoryCache.Count

		$session.Reset()

		Write-PSFMessage -Level Host -String 'Session.ResetComplete' -StringValues $providerCount, $localeCount, $cacheTotal
	}
}
