function New-SldgNumber {
	<#
	.SYNOPSIS
		Generates numbers based on semantic type and SQL data type constraints.
	#>
	[CmdletBinding()]
	param (
		[ValidateSet('Integer', 'Decimal', 'Money', 'Quantity', 'Percentage', 'Age', 'Boolean')]
		[string]$Type = 'Integer',

		$Minimum,
		$Maximum,

		[int]$Precision = 18,
		[int]$Scale = 2,

		[int]$Count = 1
	)

	for ($i = 0; $i -lt $Count; $i++) {
		switch ($Type) {
			'Integer' {
				$min = if ($null -ne $Minimum) { [int]$Minimum } else { 1 }
				$max = if ($null -ne $Maximum) { [int]$Maximum } else { 10000 }
				Get-Random -Minimum $min -Maximum ($max + 1)
			}
			'Decimal' {
				$min = if ($null -ne $Minimum) { [double]$Minimum } else { 0.0 }
				$max = if ($null -ne $Maximum) { [double]$Maximum } else { 10000.0 }
				[Math]::Round($min + (Get-Random -Minimum 0 -Maximum 10000) / 10000.0 * ($max - $min), $Scale)
			}
			'Money' {
				$min = if ($null -ne $Minimum) { [decimal]$Minimum } else { 0.01 }
				$max = if ($null -ne $Maximum) { [decimal]$Maximum } else { 50000.00 }
				[Math]::Round([decimal]$min + (Get-Random -Minimum 0 -Maximum 10000) / 10000.0 * ($max - $min), 2)
			}
			'Quantity' {
				$min = if ($null -ne $Minimum) { [int]$Minimum } else { 1 }
				$max = if ($null -ne $Maximum) { [int]$Maximum } else { 500 }
				Get-Random -Minimum $min -Maximum ($max + 1)
			}
			'Percentage' {
				$min = if ($null -ne $Minimum) { [double]$Minimum } else { 0.0 }
				$max = if ($null -ne $Maximum) { [double]$Maximum } else { 100.0 }
				[Math]::Round($min + (Get-Random -Minimum 0 -Maximum 10000) / 10000.0 * ($max - $min), 2)
			}
			'Age' {
				$min = if ($null -ne $Minimum) { [int]$Minimum } else { 18 }
				$max = if ($null -ne $Maximum) { [int]$Maximum } else { 80 }
				Get-Random -Minimum $min -Maximum ($max + 1)
			}
			'Boolean' {
				[bool](Get-Random -Minimum 0 -Maximum 2)
			}
		}
	}
}
