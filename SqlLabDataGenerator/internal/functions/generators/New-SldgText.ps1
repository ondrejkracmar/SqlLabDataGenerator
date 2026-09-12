function New-SldgText {
	<#
	.SYNOPSIS
		Generates various text content: descriptions, statuses, categories, URLs, etc.
	#>
	[CmdletBinding()]
	param (
		[ValidateSet('Text', 'ShortString', 'MediumString', 'LongString', 'Status', 'Category', 'Gender', 'Url', 'IpAddress', 'Password')]
		[string]$Type = 'Text',

		[int]$MaxLength = 200,

		[string[]]$ValueList,

		[string]$Locale,

		[int]$Count = 1
	)

	$localeData = Get-SldgLocaleData -Locale $Locale
	$statuses = if ($localeData.Statuses) { $localeData.Statuses } else { @('Active', 'Inactive', 'Pending', 'Approved', 'Rejected', 'Cancelled', 'Completed', 'In Progress', 'On Hold', 'Draft', 'Archived', 'Closed', 'Open', 'New', 'Processing') }
	$genders = if ($localeData.Genders) { $localeData.Genders } else { @('Male', 'Female', 'Non-binary', 'Other', 'Prefer not to say') }
	$loremWords = @('lorem', 'ipsum', 'dolor', 'sit', 'amet', 'consectetur', 'adipiscing', 'elit', 'sed', 'do', 'eiusmod', 'tempor', 'incididunt', 'ut', 'labore', 'et', 'dolore', 'magna', 'aliqua', 'enim', 'ad', 'minim', 'veniam', 'quis', 'nostrud', 'exercitation', 'ullamco', 'laboris', 'nisi', 'aliquip', 'ex', 'ea', 'commodo', 'consequat', 'duis', 'aute', 'irure', 'in', 'reprehenderit', 'voluptate', 'velit', 'esse', 'cillum', 'fugiat', 'nulla', 'pariatur', 'excepteur', 'sint', 'occaecat', 'cupidatat', 'non', 'proident', 'sunt', 'culpa', 'qui', 'officia', 'deserunt', 'mollit', 'anim', 'id', 'est', 'laborum')

	for ($i = 0; $i -lt $Count; $i++) {
		if ($ValueList) {
			$ValueList | Get-Random
			continue
		}

		switch ($Type) {
			'Status' { $statuses | Get-Random }
			'Gender' { $genders | Get-Random }
			'Category' {
				$categories = if ($localeData.Categories) { $localeData.Categories } else { @('Type A', 'Type B', 'Type C', 'Standard', 'Premium', 'Basic', 'Advanced', 'Professional', 'Enterprise', 'Starter') }
				$categories | Get-Random
			}
			'Url' {
				$tlds = @('com', 'org', 'net', 'io', 'co', 'dev')
				$words = @('example', 'test', 'demo', 'sample', 'app', 'site', 'web', 'portal', 'platform', 'service')
				"https://www.$($words | Get-Random).$($tlds | Get-Random)"
			}
			'IpAddress' {
				$o1 = Get-Random -Minimum 10 -Maximum 200
				$o2 = Get-Random -Minimum 0 -Maximum 256
				$o3 = Get-Random -Minimum 0 -Maximum 256
				$o4 = Get-Random -Minimum 1 -Maximum 255
				"$o1.$o2.$o3.$o4"
			}
			'Password' {
				# Generate a hashed placeholder, not a real password
				$bytes = [byte[]](1..32 | ForEach-Object { Get-Random -Minimum 0 -Maximum 256 })
				$hash = [System.BitConverter]::ToString($bytes) -replace '-', ''
				$hash.Substring(0, [Math]::Min(64, $MaxLength)).ToLower()
			}
			'ShortString' {
				$wordCount = Get-Random -Minimum 1 -Maximum 4
				$text = ($loremWords | Get-Random -Count $wordCount) -join ' '
				$text.Substring(0, [Math]::Min($text.Length, [Math]::Min($MaxLength, 50)))
			}
			'MediumString' {
				$wordCount = Get-Random -Minimum 3 -Maximum 10
				$text = ($loremWords | Get-Random -Count $wordCount) -join ' '
				$text.Substring(0, [Math]::Min($text.Length, [Math]::Min($MaxLength, 200)))
			}
			default {
				# LongString / Text
				$wordCount = Get-Random -Minimum 5 -Maximum 25
				$text = ($loremWords | Get-Random -Count $wordCount) -join ' '
				# Capitalize first letter
				$text = $text.Substring(0, 1).ToUpper() + $text.Substring(1) + '.'
				$text.Substring(0, [Math]::Min($text.Length, $MaxLength))
			}
		}
	}
}
