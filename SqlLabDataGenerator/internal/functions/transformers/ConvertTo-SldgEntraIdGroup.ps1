function ConvertTo-SldgEntraIdGroup {
	<#
	.SYNOPSIS
		Transforms generated data rows into Microsoft Entra ID group objects.
	.DESCRIPTION
		Maps columns from generated DataTable rows to Entra ID group properties.
		Outputs objects compatible with Microsoft Graph API group creation payload.
	#>
	[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSReviewUnusedParameter', 'MailDomain', Justification = 'Reserved for future mail address generation')]
	[CmdletBinding()]
	param (
		[Parameter(Mandatory)]
		[System.Data.DataTable]$Data,

		[hashtable]$ColumnMapping,

		[ValidateSet('Security', 'Microsoft365', 'DistributionList')]
		[string]$GroupType = 'Security',

		[string]$MailDomain = 'contoso.onmicrosoft.com'
	)

	# Auto-detect columns if no mapping provided
	if (-not $ColumnMapping) {
		$ColumnMapping = @{}
		$colNames = $Data.Columns | ForEach-Object { $_.ColumnName }

		foreach ($col in $colNames) {
			switch -Regex ($col) {
				'(?i)(name|group.?name|nazev|jmeno)' { if (-not $ColumnMapping['displayName']) { $ColumnMapping['displayName'] = $col } }
				'(?i)(description|popis)' { $ColumnMapping['description'] = $col }
				'(?i)(mail|email)' { $ColumnMapping['mail'] = $col }
				'(?i)(department|oddeleni)' { $ColumnMapping['department'] = $col }
			}
		}
	}

	foreach ($row in $Data.Rows) {
		$displayName = if ($ColumnMapping['displayName']) { $row[$ColumnMapping['displayName']] } else { "Group-$(Get-Random -Minimum 1000 -Maximum 9999)" }
		$description = if ($ColumnMapping['description'] -and $row[$ColumnMapping['description']] -isnot [DBNull]) {
			$row[$ColumnMapping['description']]
		} else { $null }

		$mailNickname = ($displayName -replace '[^a-zA-Z0-9]', '' -replace '\s+', '').ToLower()
		if ($mailNickname.Length -gt 64) { $mailNickname = $mailNickname.Substring(0, 64) }
		if (-not $mailNickname) { $mailNickname = "grp$(Get-Random -Minimum 1000 -Maximum 9999)" }

		$group = [SqlLabDataGenerator.EntraIdGroup]@{
			displayName   = $displayName
			mailNickname  = $mailNickname
			mailEnabled   = $GroupType -eq 'Microsoft365' -or $GroupType -eq 'DistributionList'
			securityEnabled = $GroupType -eq 'Security' -or $GroupType -eq 'Microsoft365'
			groupTypes    = switch ($GroupType) {
				'Microsoft365' { @('Unified') }
				default { @() }
			}
		}

		if ($description) {
			$group.Description = $description
		}

		# Add department tag if available
		if ($ColumnMapping['department'] -and $row[$ColumnMapping['department']] -isnot [DBNull]) {
			$group.Department = $row[$ColumnMapping['department']]
		}

		$group
	}
}
