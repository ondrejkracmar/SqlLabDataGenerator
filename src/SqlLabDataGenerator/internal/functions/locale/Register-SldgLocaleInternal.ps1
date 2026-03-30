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
			Stop-PSFFunction -String 'Locale.KeyNullValue' -StringValues $Name, $key -EnableException $true
		}
		if ($val -is [System.Array] -and $val.Count -eq 0) {
			Stop-PSFFunction -String 'Locale.KeyEmptyArray' -StringValues $Name, $key -EnableException $true
		}
	}

	$script:SldgState.Locales[$Name] = $Data
	Write-PSFMessage -Level Verbose -Message ($script:strings.'Locale.Register' -f $Name)
}
