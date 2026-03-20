function New-SldgAILocaleCategory {
	<#
	.SYNOPSIS
		Uses AI to generate data for a specific locale category in any language.
	.DESCRIPTION
		Generates data for a single category (e.g. PersonNames, Addresses, Companies)
		in the specified language/culture. Enables mixing different locales per category
		(e.g. Czech names with German addresses).
		Results are cached per locale+category combination.
	#>
	[CmdletBinding()]
	param (
		[Parameter(Mandatory)]
		[ValidateSet('PersonNames', 'Addresses', 'PhoneFormat', 'Companies', 'Identifiers', 'Email', 'Text')]
		[string]$Category,

		[Parameter(Mandatory)]
		[string]$Language,

		[int]$Count = 30,

		[string]$CustomInstructions,

		[switch]$Force
	)

	$cacheKey = "$Language|$Category"
	if (-not $Force -and $script:SldgState.AILocaleCategoryCache.ContainsKey($cacheKey)) {
		if (-not (Test-SldgCacheExpired -CacheName 'AILocaleCategoryCache' -Key $cacheKey)) {
			return $script:SldgState.AILocaleCategoryCache[$cacheKey]
		}
		$script:SldgState.AILocaleCategoryCache.Remove($cacheKey)
		$script:SldgState.CacheTimestamps.Remove("AILocaleCategoryCache|$cacheKey")
	}

	$aiProvider = Get-PSFConfigValue -FullName 'SqlLabDataGenerator.AI.Provider'
	if ($aiProvider -eq 'None') {
		Stop-PSFFunction -Message ($script:strings.'Locale.AINotConfigured' -f $Language) -EnableException $true
	}

	Write-PSFMessage -Level Verbose -Message ($script:strings.'Locale.AICategoryGenerating' -f $Category, $Language)

	$categorySchema = switch ($Category) {
		'PersonNames' {
			@"
{
  "MaleNames": ["... $Count common male first names"],
  "FemaleNames": ["... $Count common female first names"],
  "LastNames": ["... $Count common surnames"]
}
"@
		}
		'Addresses' {
			@"
{
  "StreetNames": ["... $Count realistic street names"],
  "StreetTypes": ["... common street type abbreviations"],
  "Locations": [{"City":"...","State":"...","ZipPrefix":"..."}],
  "Countries": ["..."],
  "ZipFormat": "postal code format with {Prefix} and {Suffix:D2} placeholders",
  "AddressFormat": "format string e.g. {Number} {Street} {StreetType} or {Street} {Number}",
  "StateLabel": "what regions are called in this culture"
}
"@
		}
		'PhoneFormat' {
			@"
{
  "PhoneFormat": {
    "AreaCodes": ["... real area/mobile codes"],
    "Formats": {
      "Standard": "local format template e.g. ({Area}) {Exchange}-{Subscriber}",
      "International": "intl format with country code e.g. +1-{Area}-{Exchange}-{Subscriber}",
      "Simple": "digits only e.g. {Area}{Exchange}{Subscriber}"
    },
    "ExchangeMin": 100,
    "ExchangeMax": 999,
    "SubscriberMin": 1000,
    "SubscriberMax": 9999
  }
}
"@
		}
		'Companies' {
			@"
{
  "CompanyPrefixes": ["... $Count company name prefixes in native language"],
  "CompanyCores": ["... $Count company core name parts"],
  "CompanySuffixes": ["... legal entity forms e.g. Inc, s.r.o., GmbH"],
  "Departments": ["... $Count department names in native language"],
  "JobTitles": ["... $Count job titles in native language"],
  "Industries": ["... $Count industry names in native language"]
}
"@
		}
		'Identifiers' {
			@"
{
  "NationalIdFormat": "format string matching national ID e.g. {Area:D3}-{Group:D2}-{Serial:D4}",
  "TaxIdFormat": "format string for tax ID e.g. {Part1:D2}-{Part2:D7}",
  "IBANCountries": ["ISO country codes"],
  "Currencies": ["... primary + common trading currencies"]
}
"@
		}
		'Email' {
			@"
{
  "EmailDomains": ["... $Count popular email domains in this country + generic ones"]
}
"@
		}
		'Text' {
			@"
{
  "Statuses": ["... workflow statuses in native language"],
  "Genders": ["... gender options in native language"],
  "Categories": ["... generic categories in native language"]
}
"@
		}
	}

	$systemPrompt = Resolve-SldgPromptTemplate -Purpose 'locale-category' -Variables @{
		Language       = $Language
		Category       = $Category
		CategorySchema = $categorySchema
	}

	if (-not $systemPrompt) {
		Stop-PSFFunction -String 'Locale.CategoryPromptResolveFailed' -StringValues $Language, $Category -EnableException $true
	}

	if ($CustomInstructions) {
		# Sanitize: limit length and strip control characters to mitigate prompt injection
		$sanitized = ($CustomInstructions -replace '[\x00-\x1F\x7F]', ' ')
		if ($sanitized.Length -gt 500) { $sanitized = $sanitized.Substring(0, 500) }
		$systemPrompt += "`n`nAdditional instructions: $sanitized"
	}

	$userMessage = "Generate $Category data for language/culture: $Language. Return ONLY the JSON object."

	$response = Invoke-SldgAIRequest -SystemPrompt $systemPrompt -UserMessage $userMessage -Purpose 'locale-category'

	if (-not $response) {
		Stop-PSFFunction -Message ($script:strings.'Locale.AICategoryFailed' -f $Category, $Language) -EnableException $true
	}

	# Extract JSON
	$jsonText = $response
	if ($jsonText -match '```(?:json)?\s*\n([\s\S]*?)\n```') {
		$jsonText = $Matches[1]
	}
	elseif ($jsonText -match '(\{[\s\S]*\})') {
		$jsonText = $Matches[1]
	}

	try {
		$parsed = $jsonText | ConvertFrom-Json -ErrorAction Stop
	}
	catch {
		Stop-PSFFunction -Message ($script:strings.'Locale.AIParseFailed' -f "$Language/$Category", $_) -EnableException $true
	}

	# Convert to hashtable
	$result = @{}
	foreach ($prop in $parsed.PSObject.Properties) {
		if ($prop.Value -is [System.Array] -or $prop.Value -is [object[]]) {
			$result[$prop.Name] = @($prop.Value)
		}
		elseif ($prop.Value -is [PSCustomObject]) {
			# Nested object (e.g., PhoneFormat)
			$nested = @{}
			foreach ($nprop in $prop.Value.PSObject.Properties) {
				if ($nprop.Value -is [PSCustomObject]) {
					$innerHash = @{}
					foreach ($ip in $nprop.Value.PSObject.Properties) {
						$innerHash[$ip.Name] = $ip.Value
					}
					$nested[$nprop.Name] = $innerHash
				}
				elseif ($nprop.Value -is [System.Array] -or $nprop.Value -is [object[]]) {
					$nested[$nprop.Name] = @($nprop.Value)
				}
				else {
					$nested[$nprop.Name] = $nprop.Value
				}
			}
			$result[$prop.Name] = $nested
		}
		else {
			$result[$prop.Name] = $prop.Value
		}
	}

	# Cache
	Invoke-SldgCacheEviction -Cache $script:SldgState.AILocaleCategoryCache -CacheName 'AILocaleCategoryCache'
	$script:SldgState.AILocaleCategoryCache[$cacheKey] = $result
	$script:SldgState.CacheTimestamps["AILocaleCategoryCache|$cacheKey"] = [datetime]::UtcNow
	Write-PSFMessage -Level Verbose -Message ($script:strings.'Locale.AICategoryGenerated' -f $Category, $Language)

	$result
}
