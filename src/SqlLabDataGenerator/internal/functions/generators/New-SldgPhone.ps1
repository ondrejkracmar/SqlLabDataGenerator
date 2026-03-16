function New-SldgPhone {
	<#
	.SYNOPSIS
		Generates realistic phone numbers using locale-specific formats.
	#>
	[CmdletBinding()]
	param (
		[ValidateSet('Standard', 'International', 'Simple')]
		[string]$Format = 'Standard',

		[string]$Locale,

		[int]$Count = 1
	)

	$localeData = Get-SldgLocaleData -Locale $Locale
	$phoneData = $localeData.PhoneFormat

	for ($i = 0; $i -lt $Count; $i++) {
		$area = $phoneData.AreaCodes | Get-Random
		$exchange = Get-Random -Minimum $phoneData.ExchangeMin -Maximum ($phoneData.ExchangeMax + 1)
		$subscriber = Get-Random -Minimum $phoneData.SubscriberMin -Maximum ($phoneData.SubscriberMax + 1)

		$template = $phoneData.Formats[$Format]
		$template -replace '\{Area\}', $area -replace '\{Exchange\}', $exchange -replace '\{Subscriber\}', $subscriber
	}
}
