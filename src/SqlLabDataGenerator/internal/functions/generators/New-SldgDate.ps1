function New-SldgDate {
	<#
	.SYNOPSIS
		Generates realistic dates based on semantic type.
	#>
	[CmdletBinding()]
	param (
		[ValidateSet('BirthDate', 'PastDate', 'FutureDate', 'Timestamp', 'Date', 'DateTime', 'Time', 'RecentDate')]
		[string]$Type = 'Date',

		[datetime]$MinDate,
		[datetime]$MaxDate,

		[switch]$IncludeTime,

		[int]$Count = 1
	)

	$now = Get-Date

	for ($i = 0; $i -lt $Count; $i++) {
		$result = switch ($Type) {
			'BirthDate' {
				$min = if ($MinDate) { $MinDate } else { $now.AddYears(-80) }
				$max = if ($MaxDate) { $MaxDate } else { $now.AddYears(-18) }
				$range = ($max - $min).TotalDays
				$min.AddDays((Get-Random -Minimum 0 -Maximum ([int]$range)))
			}
			'PastDate' {
				$min = if ($MinDate) { $MinDate } else { $now.AddYears(-5) }
				$max = if ($MaxDate) { $MaxDate } else { $now }
				$range = ($max - $min).TotalDays
				$min.AddDays((Get-Random -Minimum 0 -Maximum ([int][Math]::Max(1, $range))))
			}
			'FutureDate' {
				$min = if ($MinDate) { $MinDate } else { $now }
				$max = if ($MaxDate) { $MaxDate } else { $now.AddYears(3) }
				$range = ($max - $min).TotalDays
				$min.AddDays((Get-Random -Minimum 0 -Maximum ([int][Math]::Max(1, $range))))
			}
			'Timestamp' {
				$min = if ($MinDate) { $MinDate } else { $now.AddYears(-2) }
				$max = if ($MaxDate) { $MaxDate } else { $now }
				$range = ($max - $min).TotalSeconds
				$min.AddSeconds((Get-Random -Minimum 0 -Maximum ([int][Math]::Max(1, $range))))
			}
			'RecentDate' {
				$min = if ($MinDate) { $MinDate } else { $now.AddDays(-30) }
				$max = if ($MaxDate) { $MaxDate } else { $now }
				$range = ($max - $min).TotalDays
				$min.AddDays((Get-Random -Minimum 0 -Maximum ([int][Math]::Max(1, $range))))
			}
			'Time' {
				$hours = Get-Random -Minimum 0 -Maximum 24
				$minutes = Get-Random -Minimum 0 -Maximum 60
				$seconds = Get-Random -Minimum 0 -Maximum 60
				[timespan]::new($hours, $minutes, $seconds)
			}
			default {
				# Generic date
				$min = if ($MinDate) { $MinDate } else { $now.AddYears(-3) }
				$max = if ($MaxDate) { $MaxDate } else { $now.AddYears(1) }
				$range = ($max - $min).TotalDays
				$min.AddDays((Get-Random -Minimum 0 -Maximum ([int][Math]::Max(1, $range))))
			}
		}

		if ($result -is [datetime] -and -not $IncludeTime -and $Type -notin @('Timestamp', 'DateTime', 'Time')) {
			$result.Date.ToString('yyyy-MM-dd')
		}
		elseif ($result -is [datetime]) {
			$result.ToString('yyyy-MM-ddTHH:mm:ss')
		}
		else {
			$result
		}
	}
}
