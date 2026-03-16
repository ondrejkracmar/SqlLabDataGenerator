function Get-SldgLocaleData {
	<#
	.SYNOPSIS
		Returns data pool for the specified locale.
	.DESCRIPTION
		Resolves locale data in order of priority:
		1. Registered static locale pack (en-US, cs-CZ, or custom)
		2. AI-generated locale (when AI is configured and Generation.AILocale is enabled)
		3. Fallback to en-US
	#>
	[CmdletBinding()]
	param (
		[string]$Locale
	)

	if (-not $Locale) {
		$Locale = Get-PSFConfigValue -FullName 'SqlLabDataGenerator.Generation.Locale'
	}

	# 1. Return static pack if available
	if ($script:SldgState.Locales.ContainsKey($Locale)) {
		return $script:SldgState.Locales[$Locale]
	}

	# 2. Return cached AI locale if available
	if ($script:SldgState.AILocaleCache.ContainsKey($Locale)) {
		return $script:SldgState.AILocaleCache[$Locale]
	}

	# 3. Try AI generation if enabled and AI is configured
	$useAILocale = Get-PSFConfigValue -FullName 'SqlLabDataGenerator.Generation.AILocale'
	$aiProvider = Get-PSFConfigValue -FullName 'SqlLabDataGenerator.AI.Provider'

	if ($useAILocale -and $aiProvider -ne 'None') {
		Write-PSFMessage -Level Verbose -Message ($script:strings.'Locale.AIFallback' -f $Locale, $aiProvider)
		try {
			$aiData = New-SldgAILocaleData -Locale $Locale
			if ($aiData) {
				# Also register it so subsequent calls are instant
				$script:SldgState.Locales[$Locale] = $aiData
				return $aiData
			}
		}
		catch {
			Write-PSFMessage -Level Warning -Message ($script:strings.'Locale.AIFallbackFailed' -f $Locale, $_)
		}
	}

	# 4. Fallback to en-US
	if ($Locale -ne 'en-US' -and $script:SldgState.Locales.ContainsKey('en-US')) {
		Write-PSFMessage -Level Verbose -Message ($script:strings.'Locale.Fallback' -f $Locale, 'en-US')
		return $script:SldgState.Locales['en-US']
	}

	Stop-PSFFunction -Message ($script:strings.'Locale.NotFound' -f $Locale) -EnableException $true
}
