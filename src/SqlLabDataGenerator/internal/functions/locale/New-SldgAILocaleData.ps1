function New-SldgAILocaleData {
	<#
	.SYNOPSIS
		Uses AI to generate a complete locale data pack for any culture.
	.DESCRIPTION
		Sends a structured prompt to the configured AI provider requesting
		culturally-appropriate data pools. The AI generates names, addresses,
		phone formats, company data, etc. for the specified culture.
		Results are cached in $script:SldgState.AILocaleCache.
	#>
	[CmdletBinding()]
	param (
		[Parameter(Mandatory)]
		[string]$Locale,

		[int]$PoolSize = 30,

		[switch]$Force
	)

	# Return cached AI locale if already generated (check TTL)
	if (-not $Force -and $script:SldgState.AILocaleCache.ContainsKey($Locale)) {
		if (-not (Test-SldgCacheExpired -CacheName 'AILocaleCache' -Key $Locale)) {
			Write-PSFMessage -Level Verbose -Message ($script:strings.'Locale.AICacheHit' -f $Locale)
			return $script:SldgState.AILocaleCache[$Locale]
		}
		# Expired — remove and regenerate
		$script:SldgState.AILocaleCache.Remove($Locale)
		$script:SldgState.CacheTimestamps.Remove("AILocaleCache|$Locale")
	}

	$aiProvider = Get-PSFConfigValue -FullName 'SqlLabDataGenerator.AI.Provider'
	if ($aiProvider -eq 'None') {
		Stop-PSFFunction -Message ($script:strings.'Locale.AINotConfigured' -f $Locale) -EnableException $true
	}

	Write-PSFMessage -Level Host -Message ($script:strings.'Locale.AIGenerating' -f $Locale, $aiProvider)

	$systemPrompt = @"
You are a data generation assistant. Generate culturally authentic test data for the locale "$Locale".
Return ONLY valid JSON (no markdown, no comments, no explanation).
All string arrays must contain exactly $PoolSize items. All items must be culturally appropriate for $Locale.
Use the native language and naming conventions of this culture.

Required JSON structure:
{
  "MaleNames": ["..."],
  "FemaleNames": ["..."],
  "LastNames": ["..."],
  "StreetNames": ["..."],
  "StreetTypes": ["..."],
  "Locations": [{"City":"...","State":"...","ZipPrefix":"..."}],
  "Countries": ["..."],
  "ZipFormat": "{Prefix}{Suffix:D2}",
  "AddressFormat": "{Number} {Street} {StreetType}",
  "StateLabel": "...",
  "EmailDomains": ["..."],
  "PhoneFormat": {
    "AreaCodes": ["..."],
    "Formats": {
      "Standard": "...",
      "International": "...",
      "Simple": "..."
    },
    "ExchangeMin": 100,
    "ExchangeMax": 999,
    "SubscriberMin": 1000,
    "SubscriberMax": 9999
  },
  "CompanyPrefixes": ["..."],
  "CompanyCores": ["..."],
  "CompanySuffixes": ["..."],
  "Departments": ["..."],
  "JobTitles": ["..."],
  "Industries": ["..."],
  "NationalIdFormat": "...",
  "TaxIdFormat": "...",
  "IBANCountries": ["..."],
  "Currencies": ["..."],
  "Statuses": ["..."],
  "Genders": ["..."],
  "Categories": ["..."]
}

Rules:
- MaleNames: Common male first names in this culture
- FemaleNames: Common female first names in this culture
- LastNames: Common surnames in this culture
- StreetNames: Realistic street names in native language
- StreetTypes: Street type abbreviations (St, Ave, ul., nám., Str., etc.)
- Locations: Real cities in this country with region/state and postal code prefix
- Countries: Country name variants (native name, ISO code, English name)
- ZipFormat: Postal code format using {Prefix} and {Suffix:D2} placeholders. Use space if needed.
- AddressFormat: How addresses are formatted ({Number} {Street} {StreetType} or {Street} {Number}, etc.)
- StateLabel: What regions are called (State, Region, Kraj, Bundesland, etc.)
- EmailDomains: Popular email providers in this country + generic ones
- PhoneFormat.AreaCodes: Real phone area/mobile codes for this country
- PhoneFormat.Formats: Standard (local), International (with country code), Simple (digits only)
- CompanyPrefixes/Cores/Suffixes: Business name parts in native language
- Departments/JobTitles: In native language
- Industries: In native language
- NationalIdFormat/TaxIdFormat: Format strings matching the country's national ID and tax ID patterns
- IBANCountries: ISO country codes for this region
- Currencies: Primary currency + common trading currencies
- Statuses: Workflow statuses in native language
- Genders: Gender options in native language
- Categories: Generic categories in native language
"@

	$userMessage = "Generate culturally authentic test data for locale: $Locale. Return ONLY the JSON object, nothing else."

	$response = Invoke-SldgAIRequest -SystemPrompt $systemPrompt -UserMessage $userMessage

	if (-not $response) {
		Stop-PSFFunction -Message ($script:strings.'Locale.AIFailed' -f $Locale) -EnableException $true
	}

	# Extract JSON from response (handle markdown code blocks or extra text)
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
		Stop-PSFFunction -Message ($script:strings.'Locale.AIParseFailed' -f $Locale, $_) -EnableException $true
	}

	# Validate basic structure - must be an object with at least MaleNames
	if (-not $parsed.MaleNames) {
		Stop-PSFFunction -Message ($script:strings.'Locale.AIParseFailed' -f $Locale, 'AI response missing required property "MaleNames"') -EnableException $true
	}

	# Convert PSObject to hashtable structure
	$localeData = @{}

	# Simple string arrays
	$arrayKeys = @('MaleNames', 'FemaleNames', 'LastNames', 'StreetNames', 'StreetTypes',
		'Countries', 'EmailDomains', 'CompanyPrefixes', 'CompanyCores', 'CompanySuffixes',
		'Departments', 'JobTitles', 'Industries', 'IBANCountries', 'Currencies',
		'Statuses', 'Genders', 'Categories')

	foreach ($key in $arrayKeys) {
		if ($parsed.$key) {
			$localeData[$key] = @($parsed.$key)
		}
		else {
			Write-PSFMessage -Level Warning -Message ($script:strings.'Locale.AIMissingKey' -f $Locale, $key)
			$localeData[$key] = @()
		}
	}

	# Simple string values
	$stringKeys = @('ZipFormat', 'AddressFormat', 'StateLabel', 'NationalIdFormat', 'TaxIdFormat')
	foreach ($key in $stringKeys) {
		if ($parsed.$key) {
			$localeData[$key] = [string]$parsed.$key
		}
		else {
			# Sensible defaults
			$defaults = @{
				ZipFormat        = '{Prefix}{Suffix:D2}'
				AddressFormat    = '{Number} {Street} {StreetType}'
				StateLabel       = 'Region'
				NationalIdFormat = '{Part1:D4}-{Part2:D4}'
				TaxIdFormat      = '{Part1:D3}-{Part2:D6}'
			}
			$localeData[$key] = $defaults[$key]
		}
	}

	# Locations - array of hashtables
	if ($parsed.Locations) {
		$localeData['Locations'] = @(foreach ($loc in $parsed.Locations) {
				@{
					City      = [string]$loc.City
					State     = [string]$loc.State
					ZipPrefix = [string]$loc.ZipPrefix
				}
			})
	}
	else {
		$localeData['Locations'] = @(@{ City = 'Unknown'; State = 'Unknown'; ZipPrefix = '000' })
	}

	# PhoneFormat - nested hashtable
	if ($parsed.PhoneFormat) {
		$pf = $parsed.PhoneFormat
		$formats = @{}
		if ($pf.Formats) {
			foreach ($prop in $pf.Formats.PSObject.Properties) {
				$formats[$prop.Name] = [string]$prop.Value
			}
		}
		if (-not $formats.Count) {
			$formats = @{
				Standard      = '{Area}{Exchange}{Subscriber}'
				International = '+{Area}{Exchange}{Subscriber}'
				Simple        = '{Area}{Exchange}{Subscriber}'
			}
		}
		$localeData['PhoneFormat'] = @{
			AreaCodes     = @(if ($pf.AreaCodes) { $pf.AreaCodes } else { @('000') })
			Formats       = $formats
			ExchangeMin   = if ($pf.ExchangeMin) { [int]$pf.ExchangeMin } else { 100 }
			ExchangeMax   = if ($pf.ExchangeMax) { [int]$pf.ExchangeMax } else { 999 }
			SubscriberMin = if ($pf.SubscriberMin) { [int]$pf.SubscriberMin } else { 1000 }
			SubscriberMax = if ($pf.SubscriberMax) { [int]$pf.SubscriberMax } else { 9999 }
		}
	}
	else {
		$localeData['PhoneFormat'] = @{
			AreaCodes     = @('000')
			Formats       = @{ Standard = '{Area}{Exchange}{Subscriber}'; International = '+{Area}{Exchange}{Subscriber}'; Simple = '{Area}{Exchange}{Subscriber}' }
			ExchangeMin   = 100
			ExchangeMax   = 999
			SubscriberMin = 1000
			SubscriberMax = 9999
		}
	}

	# Cache the generated locale
	Invoke-SldgCacheEviction -Cache $script:SldgState.AILocaleCache -CacheName 'AILocaleCache'
	$script:SldgState.AILocaleCache[$Locale] = $localeData
	$script:SldgState.CacheTimestamps["AILocaleCache|$Locale"] = [datetime]::UtcNow
	Write-PSFMessage -Level Verbose -Message ($script:strings.'Locale.AIGenerated' -f $Locale)

	$localeData
}
