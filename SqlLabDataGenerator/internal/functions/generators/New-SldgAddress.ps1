function New-SldgAddress {
	<#
	.SYNOPSIS
		Generates realistic address components with geographic consistency using locale-specific data.
	#>
	[CmdletBinding()]
	param (
		[ValidateSet('Street', 'City', 'State', 'ZipCode', 'Country', 'Full')]
		[string]$Type = 'Street',

		[string]$Locale,

		[int]$Count = 1
	)

	$localeData = Get-SldgLocaleData -Locale $Locale

	for ($i = 0; $i -lt $Count; $i++) {
		$loc = $localeData.Locations | Get-Random
		$streetNum = Get-Random -Minimum 1 -Maximum 9999
		$streetName = $localeData.StreetNames | Get-Random
		$streetType = $localeData.StreetTypes | Get-Random

		# Use locale address format (e.g., US: '123 Main St', CZ: 'Hlavni 123')
		$streetStr = if ($localeData.AddressFormat -eq '{Street} {Number}') {
			"$streetName $streetNum"
		} else {
			"$streetNum $streetName $streetType"
		}

		$zipSuffix = '{0:D2}' -f (Get-Random -Minimum 0 -Maximum 99)
		$zip = if ($localeData.ZipFormat -eq '{Prefix} {Suffix:D2}') {
			"$($loc.ZipPrefix) $zipSuffix"
		} else {
			"$($loc.ZipPrefix)$zipSuffix"
		}

		switch ($Type) {
			'Street' { $streetStr }
			'City' { $loc.City }
			'State' { $loc.State }
			'ZipCode' { $zip }
			'Country' { $localeData.Countries | Get-Random }
			'Full' {
				[PSCustomObject]@{
					Street  = $streetStr
					City    = $loc.City
					State   = $loc.State
					ZipCode = $zip
					Country = $localeData.Countries[0]
				}
			}
		}
	}
}
