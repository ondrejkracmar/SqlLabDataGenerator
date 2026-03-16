function New-SldgPersonName {
	<#
	.SYNOPSIS
		Generates realistic person names using locale-specific data.
	#>
	[CmdletBinding()]
	param (
		[ValidateSet('First', 'Last', 'Middle', 'Full')]
		[string]$Type = 'First',

		[ValidateSet('Male', 'Female', 'Any')]
		[string]$Gender = 'Any',

		[string]$Locale,

		[int]$Count = 1
	)

	$localeData = Get-SldgLocaleData -Locale $Locale
	$maleNames = $localeData.MaleNames
	$femaleNames = $localeData.FemaleNames
	$lastNames = $localeData.LastNames

	for ($i = 0; $i -lt $Count; $i++) {
		$g = if ($Gender -eq 'Any') { @('Male', 'Female') | Get-Random } else { $Gender }
		$first = if ($g -eq 'Male') { $maleNames | Get-Random } else { $femaleNames | Get-Random }
		$last = $lastNames | Get-Random

		switch ($Type) {
			'First' { $first }
			'Last' { $last }
			'Middle' { (($maleNames + $femaleNames) | Get-Random).Substring(0, 1) + '.' }
			'Full' { "$first $last" }
		}
	}
}
