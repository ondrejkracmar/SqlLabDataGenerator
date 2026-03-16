function ConvertTo-SldgEntraIdUser {
	<#
	.SYNOPSIS
		Transforms generated data rows into Microsoft Entra ID (Azure AD) user objects.
	.DESCRIPTION
		Maps columns from generated DataTable rows to Entra ID user properties.
		Outputs objects compatible with Microsoft Graph API user creation payload.
	#>
	[CmdletBinding()]
	param (
		[Parameter(Mandatory)]
		[System.Data.DataTable]$Data,

		[hashtable]$ColumnMapping,

		[string]$Domain = 'contoso.onmicrosoft.com',

		[string]$DefaultPassword,

		[string]$UsageLocation = 'US'
	)

	# Auto-detect columns if no mapping provided
	if (-not $ColumnMapping) {
		$ColumnMapping = @{}
		$colNames = $Data.Columns | ForEach-Object { $_.ColumnName }

		# Smart mapping by column name patterns
		foreach ($col in $colNames) {
			switch -Regex ($col) {
				'(?i)(first.?name|given.?name|jmeno)' { $ColumnMapping['givenName'] = $col }
				'(?i)(last.?name|surname|prijmeni)' { $ColumnMapping['surname'] = $col }
				'(?i)(display.?name|full.?name|cele.?jmeno)' { $ColumnMapping['displayName'] = $col }
				'(?i)(email|mail|e.?mail)' { $ColumnMapping['mail'] = $col }
				'(?i)(phone|telephone|telefon|mobile)' { $ColumnMapping['mobilePhone'] = $col }
				'(?i)(job.?title|position|pozice|funkce)' { $ColumnMapping['jobTitle'] = $col }
				'(?i)(department|oddeleni)' { $ColumnMapping['department'] = $col }
				'(?i)(company|firma|spolecnost)' { $ColumnMapping['companyName'] = $col }
				'(?i)(city|mesto)' { $ColumnMapping['city'] = $col }
				'(?i)(state|province|kraj)' { $ColumnMapping['state'] = $col }
				'(?i)(country|zeme|stat)' { $ColumnMapping['country'] = $col }
				'(?i)(zip|postal|psc)' { $ColumnMapping['postalCode'] = $col }
				'(?i)(street|address|adresa|ulice)' { $ColumnMapping['streetAddress'] = $col }
			}
		}
	}

	foreach ($row in $Data.Rows) {
		$firstName = if ($ColumnMapping['givenName']) { $row[$ColumnMapping['givenName']] } else { '' }
		$lastName = if ($ColumnMapping['surname']) { $row[$ColumnMapping['surname']] } else { '' }
		$displayName = if ($ColumnMapping['displayName']) {
			$row[$ColumnMapping['displayName']]
		} else {
			"$firstName $lastName".Trim()
		}

		# Generate UPN from first+last name
		$upnLocal = ("$firstName.$lastName" -replace '[^a-zA-Z0-9.]', '' -replace '\.+', '.').ToLower().Trim('.')
		if (-not $upnLocal) { $upnLocal = "user$(Get-Random -Minimum 1000 -Maximum 9999)" }
		$upn = "$upnLocal@$Domain"

		# Build mailNickname
		$mailNickname = ($upnLocal -replace '\.', '').ToLower()
		if (-not $mailNickname) { $mailNickname = "user$(Get-Random -Minimum 1000 -Maximum 9999)" }

		$user = [PSCustomObject]@{
			PSTypeName                = 'SqlLabDataGenerator.EntraIdUser'
			accountEnabled            = $true
			displayName               = $displayName
			givenName                 = $firstName
			surname                   = $lastName
			userPrincipalName         = $upn
			mailNickname              = $mailNickname
			usageLocation             = $UsageLocation
			passwordProfile           = @{
				forceChangePasswordNextSignIn = $true
				password                     = if ($DefaultPassword) { $DefaultPassword } else {
					# Generate a 16-char password with crypto-safe randomness (test data only)
					$bytes = [byte[]]::new(12)
					([System.Security.Cryptography.RandomNumberGenerator]::Create()).GetBytes($bytes)
					[Convert]::ToBase64String($bytes) + '!'
				}
			}
		}

		# Add optional properties from mapping
		$optionalProps = @('mail', 'mobilePhone', 'jobTitle', 'department', 'companyName', 'city', 'state', 'country', 'postalCode', 'streetAddress')
		foreach ($prop in $optionalProps) {
			if ($ColumnMapping[$prop] -and $row[$ColumnMapping[$prop]] -isnot [DBNull]) {
				$user | Add-Member -NotePropertyName $prop -NotePropertyValue $row[$ColumnMapping[$prop]]
			}
		}

		$user
	}
}
