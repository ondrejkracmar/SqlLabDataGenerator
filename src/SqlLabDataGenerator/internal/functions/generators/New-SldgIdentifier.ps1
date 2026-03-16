function New-SldgIdentifier {
	<#
	.SYNOPSIS
		Generates various types of identifiers: GUIDs, business numbers, SSNs, IBANs, etc.
	#>
	[CmdletBinding()]
	param (
		[ValidateSet('Guid', 'BusinessNumber', 'SSN', 'NationalId', 'TaxId', 'IBAN', 'CreditCard', 'BankAccount', 'LicenseNumber', 'PassportNumber', 'Code', 'Username')]
		[string]$Type = 'Guid',

		[string]$Prefix = '',

		[string]$Locale,

		[int]$Count = 1
	)

	for ($i = 0; $i -lt $Count; $i++) {
		switch ($Type) {
			'Guid' {
				[guid]::NewGuid().ToString()
			}
			'BusinessNumber' {
				$prefixStr = if ($Prefix) { $Prefix } else { @('INV', 'ORD', 'PO', 'SO', 'RFQ', 'WO', 'TKT') | Get-Random }
				$num = Get-Random -Minimum 100000 -Maximum 999999
				"$prefixStr-$num"
			}
			'SSN' {
				# Generate fake SSN format (not real SSNs - area 900+ is reserved/invalid)
				$area = Get-Random -Minimum 900 -Maximum 999
				$group = Get-Random -Minimum 10 -Maximum 99
				$serial = Get-Random -Minimum 1000 -Maximum 9999
				"$area-$group-$serial"
			}
			'NationalId' {
				$part1 = Get-Random -Minimum 100000 -Maximum 999999
				$part2 = Get-Random -Minimum 1000 -Maximum 9999
				"$part1/$part2"
			}
			'TaxId' {
				$part1 = Get-Random -Minimum 10 -Maximum 99
				$part2 = Get-Random -Minimum 1000000 -Maximum 9999999
				"$part1-$part2"
			}
			'IBAN' {
				# Fake IBAN-like format using locale IBAN countries
				$localeData = Get-SldgLocaleData -Locale $Locale
				$ibanCountries = if ($localeData.IBANCountries) { $localeData.IBANCountries + @('DE', 'FR', 'GB', 'AT', 'NL') } else { @('DE', 'FR', 'GB', 'CZ', 'AT', 'NL', 'BE', 'ES', 'IT', 'PL') }
				$countryCode = $ibanCountries | Get-Random
				$check = Get-Random -Minimum 10 -Maximum 99
				$bban = -join (1..16 | ForEach-Object { Get-Random -Minimum 0 -Maximum 10 })
				"$countryCode$check$bban"
			}
			'CreditCard' {
				# Fake credit card (starts with test prefix 9999)
				$ccPrefix = '9999'
				$middle = -join (1..8 | ForEach-Object { Get-Random -Minimum 0 -Maximum 10 })
				$last = -join (1..4 | ForEach-Object { Get-Random -Minimum 0 -Maximum 10 })
				"$ccPrefix-$middle-$last"
			}
			'BankAccount' {
				$routing = Get-Random -Minimum 100000000 -Maximum 999999999
				$account = Get-Random -Minimum 10000000 -Maximum 99999999
				"$routing-$account"
			}
			'LicenseNumber' {
				$letter = [char](Get-Random -Minimum 65 -Maximum 91)
				$num = Get-Random -Minimum 1000000 -Maximum 9999999
				"$letter$num"
			}
			'PassportNumber' {
				$letters = -join (1..2 | ForEach-Object { [char](Get-Random -Minimum 65 -Maximum 91) })
				$num = Get-Random -Minimum 100000 -Maximum 999999
				"$letters$num"
			}
			'Code' {
				if ($Prefix) {
					$num = Get-Random -Minimum 1000 -Maximum 9999
					"$Prefix$num"
				}
				else {
					$letters = -join (1..3 | ForEach-Object { [char](Get-Random -Minimum 65 -Maximum 91) })
					$num = Get-Random -Minimum 100 -Maximum 999
					"$letters$num"
				}
			}
			'Username' {
				$first = (New-SldgPersonName -Type First -Locale $Locale).ToLower()
				$last = (New-SldgPersonName -Type Last -Locale $Locale).ToLower()
				$num = Get-Random -Minimum 1 -Maximum 99
				$pattern = Get-Random -Minimum 0 -Maximum 3
				switch ($pattern) {
					0 { "$first.$last" }
					1 { "$($first[0])$last$num" }
					2 { "$first$num" }
				}
			}
		}
	}
}
