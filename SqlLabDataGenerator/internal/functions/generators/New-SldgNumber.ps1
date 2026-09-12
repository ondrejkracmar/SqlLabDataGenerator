function New-SldgNumber {
	<#
	.SYNOPSIS
		Generates numbers based on semantic type and SQL data type constraints.
	#>
	[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSReviewUnusedParameter', 'Precision', Justification = 'Used to define decimal range')]
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
				if ($min -gt $max) { $min, $max = $max, $min }
				[int](Get-Random -Minimum ([long]$min) -Maximum ([long]$max + 1))
			}
			'Decimal' {
				$min = if ($null -ne $Minimum) { [double]$Minimum } else { 0.0 }
				$max = if ($null -ne $Maximum) { [double]$Maximum } else { 10000.0 }
				if ($min -gt $max) { $min, $max = $max, $min }
				# Constrain range to Precision: DECIMAL(P,S) allows max magnitude 10^(P-S)-1
				if ($Precision -gt 0 -and $Precision -gt $Scale) {
					$maxMagnitude = [math]::Pow(10, $Precision - $Scale) - 1
					$min = [math]::Max($min, -$maxMagnitude)
					$max = [math]::Min($max, $maxMagnitude)
				}
				[Math]::Round($min + (Get-Random -Minimum 0 -Maximum 10000) / 10000.0 * ($max - $min), $Scale)
			}
			'Money' {
				$min = if ($null -ne $Minimum) { [decimal]$Minimum } else { 0.01 }
				$max = if ($null -ne $Maximum) { [decimal]$Maximum } else { 50000.00 }
				if ($min -gt $max) { $min, $max = $max, $min }
				[Math]::Round([decimal]$min + (Get-Random -Minimum 0 -Maximum 10000) / 10000.0 * ($max - $min), 2)
			}
			'Quantity' {
				$min = if ($null -ne $Minimum) { [int]$Minimum } else { 1 }
				$max = if ($null -ne $Maximum) { [int]$Maximum } else { 500 }
				if ($min -gt $max) { $min, $max = $max, $min }
				[int](Get-Random -Minimum ([long]$min) -Maximum ([long]$max + 1))
			}
			'Percentage' {
				$min = if ($null -ne $Minimum) { [double]$Minimum } else { 0.0 }
				$max = if ($null -ne $Maximum) { [double]$Maximum } else { 100.0 }
				if ($min -gt $max) { $min, $max = $max, $min }
				[Math]::Round($min + (Get-Random -Minimum 0 -Maximum 10000) / 10000.0 * ($max - $min), 2)
			}
			'Age' {
				$min = if ($null -ne $Minimum) { [int]$Minimum } else { 18 }
				$max = if ($null -ne $Maximum) { [int]$Maximum } else { 80 }
				if ($min -gt $max) { $min, $max = $max, $min }
				[int](Get-Random -Minimum ([long]$min) -Maximum ([long]$max + 1))
			}
			'Boolean' {
				[bool](Get-Random -Minimum 0 -Maximum 2)
			}
		}
	}
}
