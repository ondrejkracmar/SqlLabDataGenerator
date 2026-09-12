function New-SldgFinancial {
	<#
	.SYNOPSIS
		Generates financial data: currency codes, amounts, account references.
	#>
	[CmdletBinding()]
	param (
		[ValidateSet('Currency', 'Amount', 'InvoiceNumber', 'AccountNumber')]
		[string]$Type = 'Amount',

		[decimal]$Minimum = 0.01,
		[decimal]$Maximum = 50000.00,

		[string]$Locale,

		[int]$Count = 1
	)

	$localeData = Get-SldgLocaleData -Locale $Locale
	$currencies = if ($localeData.Currencies) { $localeData.Currencies } else { @('USD', 'EUR', 'GBP', 'CZK', 'CHF', 'JPY', 'CAD', 'AUD', 'SEK', 'NOK', 'DKK', 'PLN') }

	for ($i = 0; $i -lt $Count; $i++) {
		switch ($Type) {
			'Currency' { $currencies | Get-Random }
			'Amount' {
				[Math]::Round([decimal]$Minimum + (Get-Random -Minimum 0 -Maximum 10000) / 10000.0 * ($Maximum - $Minimum), 2)
			}
			'InvoiceNumber' {
				$year = (Get-Date).Year
				$seq = Get-Random -Minimum 10000 -Maximum 99999
				"INV-$year-$seq"
			}
			'AccountNumber' {
				$prefix = Get-Random -Minimum 1000 -Maximum 9999
				$suffix = Get-Random -Minimum 100000 -Maximum 999999
				"$prefix-$suffix"
			}
		}
	}
}
