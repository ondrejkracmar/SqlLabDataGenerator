function Register-SldgLocaleInternal {
	<#
	.SYNOPSIS
		Registers a locale data pack for data generation.
	#>
	[CmdletBinding()]
	param (
		[Parameter(Mandatory)]
		[string]$Name,

		[Parameter(Mandatory)]
		[hashtable]$Data
	)

	# Validate required data keys
	$requiredKeys = @('MaleNames', 'FemaleNames', 'LastNames', 'StreetNames', 'StreetTypes', 'Locations', 'Countries', 'EmailDomains', 'PhoneFormat', 'CompanyPrefixes', 'CompanyCores', 'CompanySuffixes', 'Departments', 'JobTitles', 'Industries')
	foreach ($key in $requiredKeys) {
		if (-not $Data.ContainsKey($key)) {
			Stop-PSFFunction -Message ($script:strings.'Locale.MissingKey' -f $Name, $key) -EnableException $true
		}
		$val = $Data[$key]
		if ($null -eq $val) {
			Stop-PSFFunction -Message "Locale '$Name': key '$key' has a `$null value. Each required key must contain a non-empty array or string." -EnableException $true
		}
		if ($val -is [System.Array] -and $val.Count -eq 0) {
			Stop-PSFFunction -Message "Locale '$Name': key '$key' is an empty array. At least one value is required." -EnableException $true
		}
	}

	$script:SldgState.Locales[$Name] = $Data
	Write-PSFMessage -Level Verbose -Message ($script:strings.'Locale.Register' -f $Name)
}
