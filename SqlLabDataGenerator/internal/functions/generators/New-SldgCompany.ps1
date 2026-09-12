function New-SldgCompany {
	<#
	.SYNOPSIS
		Generates realistic company names, departments, and job titles using locale-specific data.
	#>
	[CmdletBinding()]
	param (
		[ValidateSet('Company', 'Department', 'JobTitle', 'Industry')]
		[string]$Type = 'Company',

		[string]$Locale,

		[int]$Count = 1
	)

	$localeData = Get-SldgLocaleData -Locale $Locale

	for ($i = 0; $i -lt $Count; $i++) {
		switch ($Type) {
			'Company' {
				$pattern = Get-Random -Minimum 0 -Maximum 3
				switch ($pattern) {
					0 { "$($localeData.CompanyPrefixes | Get-Random) $($localeData.CompanyCores | Get-Random) $($localeData.CompanySuffixes | Get-Random)" }
					1 { "$(New-SldgPersonName -Type Last -Locale $Locale) & $(New-SldgPersonName -Type Last -Locale $Locale) $($localeData.CompanySuffixes | Get-Random)" }
					2 { "$($localeData.CompanyPrefixes | Get-Random) $($localeData.CompanyCores | Get-Random)" }
				}
			}
			'Department' { $localeData.Departments | Get-Random }
			'JobTitle' { $localeData.JobTitles | Get-Random }
			'Industry' { $localeData.Industries | Get-Random }
		}
	}
}
