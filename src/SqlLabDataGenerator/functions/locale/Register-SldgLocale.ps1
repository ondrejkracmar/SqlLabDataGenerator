function Register-SldgLocale {
	<#
	.SYNOPSIS
		Registers a locale data pack for data generation — manually or via AI.

	.DESCRIPTION
		Registers a new locale with culture-specific data pools for generating
		realistic localized data. Three modes:

		1. Manual: Provide a hashtable with all required data keys.
		2. AI-generated: Use -UseAI to let AI generate the entire locale pack
		   for any culture/language (requires configured AI provider).
		3. Mixed: Use -MixFrom to combine categories from different languages
		   via AI (e.g., Czech names + German addresses).

		Built-in locales: en-US, cs-CZ
		AI can generate any locale on-the-fly (de-DE, fr-FR, ja-JP, ...).

	.PARAMETER Name
		The locale identifier (e.g., 'de-DE', 'fr-FR', 'sk-SK').

	.PARAMETER Data
		A hashtable containing the locale data pools. Required keys:
		MaleNames, FemaleNames, LastNames, StreetNames, StreetTypes, Locations,
		Countries, EmailDomains, PhoneFormat, CompanyPrefixes, CompanyCores,
		CompanySuffixes, Departments, JobTitles, Industries.

	.PARAMETER UseAI
		Generate the locale data pack automatically via the configured AI provider.
		Works with any language/culture code — no pre-built data pack needed.

	.PARAMETER MixFrom
		A hashtable mapping categories to language/culture codes for AI generation.
		Enables mixing different languages per data category.
		Valid categories: PersonNames, Addresses, PhoneFormat, Companies,
		Identifiers, Email, Text.

	.PARAMETER PoolSize
		Number of items per data pool when generating via AI. Default: 30.

	.PARAMETER CustomInstructions
		Additional instructions to pass to the AI for fine-tuning data generation
		(e.g., "Focus on historical names from 18th century" or "Use only rural addresses").

	.PARAMETER Force
		Overwrite an existing locale with the same name. Also bypasses AI cache.

	.EXAMPLE
		PS C:\> Register-SldgLocale -Name 'de-DE' -UseAI

		AI generates a complete German locale pack automatically.

	.EXAMPLE
		PS C:\> Register-SldgLocale -Name 'custom-mix' -MixFrom @{
		>>     PersonNames = 'cs-CZ'
		>>     Addresses   = 'de-DE'
		>>     Companies   = 'en-US'
		>>     PhoneFormat = 'cs-CZ'
		>>     Text        = 'cs-CZ'
		>> }

		Creates a mixed locale: Czech names, German addresses, English companies.

	.EXAMPLE
		PS C:\> Register-SldgLocale -Name 'ja-JP' -UseAI -PoolSize 50 -CustomInstructions "Include both traditional and modern Japanese names"

		AI generates Japanese locale with 50 items per pool and custom guidance.

	.EXAMPLE
		PS C:\> Register-SldgLocale -Name 'sk-SK' -Data @{
		>>     MaleNames = @('Jan', 'Peter', 'Martin', ...)
		>>     # ... all required keys
		>> }

		Manually registers a Slovak locale data pack.
	#>
	[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSReviewUnusedParameter', 'UseAI', Justification = 'Switch drives parameter set selection')]
	[OutputType([void])]
	[CmdletBinding(DefaultParameterSetName = 'Manual')]
	param (
		[Parameter(Mandatory)]
		[ValidatePattern('^[a-zA-Z][a-zA-Z0-9]*(-[a-zA-Z][a-zA-Z0-9]*)*$')]
		[string]$Name,

		[Parameter(Mandatory, ParameterSetName = 'Manual')]
		[hashtable]$Data,

		[Parameter(Mandatory, ParameterSetName = 'AI')]
		[switch]$UseAI,

		[Parameter(Mandatory, ParameterSetName = 'Mix')]
		[hashtable]$MixFrom,

		[Parameter(ParameterSetName = 'AI')]
		[Parameter(ParameterSetName = 'Mix')]
		[int]$PoolSize = 30,

		[Parameter(ParameterSetName = 'AI')]
		[Parameter(ParameterSetName = 'Mix')]
		[string]$CustomInstructions,

		[switch]$Force
	)

	switch ($PSCmdlet.ParameterSetName) {
		'Manual' {
			Register-SldgLocaleInternal -Name $Name -Data $Data
		}
		'AI' {
			try {
				$aiData = New-SldgAILocaleData -Locale $Name -PoolSize $PoolSize -Force:$Force
				$script:SldgState.Locales[$Name] = $aiData
			}
			catch {
				Write-PSFMessage -Level Warning -Message ($script:strings.'Locale.AIGenerationFailed' -f $Name, $_.Exception.Message)
				if ($script:SldgState.Locales.ContainsKey('en-US')) {
					Write-PSFMessage -Level Warning -Message ($script:strings.'Locale.AIFallbackFailed' -f $Name, $_.Exception.Message)
					$script:SldgState.Locales[$Name] = $script:SldgState.Locales['en-US']
				}
				else {
					throw
				}
			}
		}
		'Mix' {
			Write-PSFMessage -Level Host -Message ($script:strings.'Locale.AIMixGenerating' -f $Name, ($MixFrom.Keys -join ', '))

			# Start with en-US as base, then overlay AI-generated categories
			$baseLocale = if ($script:SldgState.Locales.ContainsKey('en-US')) {
				# Deep-clone the base (nested hashtables + arrays of hashtables are reference types)
				$clone = @{}
				foreach ($k in $script:SldgState.Locales['en-US'].Keys) {
					$v = $script:SldgState.Locales['en-US'][$k]
					$clone[$k] = if ($v -is [hashtable]) {
						$innerClone = @{}
						foreach ($ik in $v.Keys) {
							$iv = $v[$ik]
							$innerClone[$ik] = if ($iv -is [hashtable]) { $iv.Clone() } elseif ($iv -is [array]) { @($iv) } else { $iv }
						}
						$innerClone
					} elseif ($v -is [array]) {
						@($v | ForEach-Object { if ($_ -is [hashtable]) { $_.Clone() } else { $_ } })
					} else { $v }
				}
				$clone
			}
			else {
				@{}
			}

			foreach ($category in $MixFrom.Keys) {
				$lang = $MixFrom[$category]
				$validCategories = @('PersonNames', 'Addresses', 'PhoneFormat', 'Companies', 'Identifiers', 'Email', 'Text')
				if ($category -notin $validCategories) {
					Write-PSFMessage -Level Warning -Message ($script:strings.'Locale.UnknownCategory' -f $category, ($validCategories -join ', '))
					continue
				}

				# Check if the language has a static pack — use it first
				$staticData = $null
				if ($script:SldgState.Locales.ContainsKey($lang)) {
					$staticData = $script:SldgState.Locales[$lang]
				}

				if ($staticData) {
					# Merge from static pack
					$categoryKeys = switch ($category) {
						'PersonNames' { @('MaleNames', 'FemaleNames', 'LastNames') }
						'Addresses' { @('StreetNames', 'StreetTypes', 'Locations', 'Countries', 'ZipFormat', 'AddressFormat', 'StateLabel') }
						'PhoneFormat' { @('PhoneFormat') }
						'Companies' { @('CompanyPrefixes', 'CompanyCores', 'CompanySuffixes', 'Departments', 'JobTitles', 'Industries') }
						'Identifiers' { @('NationalIdFormat', 'TaxIdFormat', 'IBANCountries', 'Currencies') }
						'Email' { @('EmailDomains') }
						'Text' { @('Statuses', 'Genders', 'Categories') }
					}
					foreach ($key in $categoryKeys) {
						if ($staticData.ContainsKey($key)) {
							$baseLocale[$key] = $staticData[$key]
						}
					}
				}
				else {
					# Generate via AI
					$params = @{
						Category = $category
						Language = $lang
						Count    = $PoolSize
						Force    = $Force
					}
					if ($CustomInstructions) { $params['CustomInstructions'] = $CustomInstructions }
					try {
						$catData = New-SldgAILocaleCategory @params
						foreach ($key in $catData.Keys) {
							$baseLocale[$key] = $catData[$key]
						}
					}
					catch {
						Write-PSFMessage -Level Warning -Message ($script:strings.'Locale.AICategoryMixFailed' -f $category, $lang, $_.Exception.Message)
					}
				}
			}

			$script:SldgState.Locales[$Name] = $baseLocale

			# Validate required keys are present after mixing (same contract as Manual mode)
			$requiredKeys = @('MaleNames', 'FemaleNames', 'LastNames', 'StreetNames', 'StreetTypes', 'Locations', 'Countries', 'EmailDomains', 'PhoneFormat', 'CompanyPrefixes', 'CompanyCores', 'CompanySuffixes', 'Departments', 'JobTitles', 'Industries')
			$missingKeys = @($requiredKeys | Where-Object { -not $baseLocale.ContainsKey($_) })
			if ($missingKeys.Count -gt 0) {
				Write-PSFMessage -Level Warning -Message ($script:strings.'Locale.MixMissingKeys' -f $Name, ($missingKeys -join ', '))
			}
		}
	}

	Write-PSFMessage -Level Host -Message ($script:strings.'Locale.Registered' -f $Name)
}
