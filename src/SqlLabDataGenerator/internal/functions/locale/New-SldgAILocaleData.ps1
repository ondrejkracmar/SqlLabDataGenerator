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
		[ValidatePattern('^[a-zA-Z]{2}(-[a-zA-Z]{2,})?$')]
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

	$systemPrompt = Resolve-SldgPromptTemplate -Purpose 'locale-data' -Variables @{
		Locale   = $Locale
		PoolSize = $PoolSize
	}

	if (-not $systemPrompt) {
		Stop-PSFFunction -String 'Locale.PromptResolveFailed' -StringValues $Locale -EnableException $true
	}

	$userMessage = "Generate culturally authentic test data for locale: $Locale. Return ONLY the JSON object, nothing else."

	$response = Invoke-SldgAIRequest -SystemPrompt $systemPrompt -UserMessage $userMessage -Purpose 'locale-data'

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
