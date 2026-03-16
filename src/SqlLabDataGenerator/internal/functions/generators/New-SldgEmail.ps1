function New-SldgEmail {
	<#
	.SYNOPSIS
		Generates realistic email addresses using locale-specific domains.
	#>
	[CmdletBinding()]
	param (
		[string]$FirstName,
		[string]$LastName,
		[string]$Locale,
		[int]$Count = 1
	)

	# ASCII transliteration map for common diacritics
	$diacriticMap = @{
		'á'='a'; 'à'='a'; 'â'='a'; 'ä'='a'; 'ã'='a'; 'å'='a'
		'č'='c'; 'ć'='c'; 'ç'='c'
		'ď'='d'; 'đ'='d'
		'é'='e'; 'è'='e'; 'ê'='e'; 'ë'='e'; 'ě'='e'
		'í'='i'; 'ì'='i'; 'î'='i'; 'ï'='i'
		'ľ'='l'; 'ĺ'='l'; 'ł'='l'
		'ñ'='n'; 'ň'='n'; 'ń'='n'
		'ó'='o'; 'ò'='o'; 'ô'='o'; 'ö'='o'; 'õ'='o'; 'ø'='o'
		'ř'='r'; 'ŕ'='r'
		'š'='s'; 'ś'='s'; 'ş'='s'
		'ť'='t'; 'ţ'='t'
		'ú'='u'; 'ù'='u'; 'û'='u'; 'ü'='u'; 'ů'='u'
		'ý'='y'; 'ÿ'='y'
		'ž'='z'; 'ź'='z'; 'ż'='z'
		'ß'='ss'; 'æ'='ae'; 'œ'='oe'; 'þ'='th'; 'ð'='d'
	}

	$transliterate = {
		param([string]$Text)
		$result = $Text.ToLower()
		foreach ($key in $diacriticMap.Keys) {
			$result = $result.Replace($key, $diacriticMap[$key])
		}
		# Remove any remaining non-ASCII characters
		$result -replace '[^a-z0-9._-]', ''
	}

	$localeData = Get-SldgLocaleData -Locale $Locale
	$domains = $localeData.EmailDomains
	$separators = @('.', '_', '')

	for ($i = 0; $i -lt $Count; $i++) {
		$fn = if ($FirstName) { & $transliterate $FirstName } else { & $transliterate (New-SldgPersonName -Type First -Locale $Locale) }
		$ln = if ($LastName) { & $transliterate $LastName } else { & $transliterate (New-SldgPersonName -Type Last -Locale $Locale) }
		$domain = $domains | Get-Random
		$sep = $separators | Get-Random
		$suffix = if ((Get-Random -Minimum 0 -Maximum 3) -eq 0) { Get-Random -Minimum 1 -Maximum 99 } else { '' }

		# Varied patterns
		$pattern = Get-Random -Minimum 0 -Maximum 4
		$local = switch ($pattern) {
			0 { "$fn$sep$ln$suffix" }
			1 { "$($fn[0])$sep$ln$suffix" }
			2 { "$fn$sep$($ln[0])$suffix" }
			3 { "$ln$sep$fn$suffix" }
		}

		"$local@$domain"
	}
}
