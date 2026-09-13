function ConvertFrom-SldgStoreTypeFacet {
	<#
	.SYNOPSIS
		Splits a store type such as nvarchar(50) or decimal(10,2) into its length / precision / scale.
	.DESCRIPTION
		The catalogue reader hands back the store type as one string. Generators clamp string
		lengths and numeric ranges, so the facets are pulled out here: a single number after a
		character or binary type is the maximum length (-1 and MAX mean unbounded), a pair after a
		numeric type is precision and scale, a single number after a numeric type is precision.
	.PARAMETER StoreType
		The store type as reported by the catalogue.
	.OUTPUTS
		PSCustomObject with MaxLength, Precision and Scale (each $null when not declared).
	#>
	[OutputType([PSCustomObject])]
	[CmdletBinding()]
	param (
		[AllowEmptyString()]
		[AllowNull()]
		[string]$StoreType
	)

	$result = [PSCustomObject]@{ MaxLength = $null; Precision = $null; Scale = $null }
	if (-not $StoreType -or $StoreType -notmatch '^\s*([^(]+?)\s*\(\s*([^)]*)\s*\)') { return $result }

	$baseName = $Matches[1].Trim().ToLowerInvariant()
	$facets = @($Matches[2] -split ',' | ForEach-Object { $_.Trim() } | Where-Object { $_ })
	if ($facets.Count -eq 0) { return $result }

	$isNumeric = $baseName -match '^(decimal|numeric|dec|number|money|smallmoney|float|double|double precision|real|time|datetime2|datetimeoffset|timestamp.*)$'
	if ($isNumeric) {
		if ($facets[0] -match '^\d+$') { $result.Precision = [int]$facets[0] }
		if ($facets.Count -gt 1 -and $facets[1] -match '^\d+$') { $result.Scale = [int]$facets[1] }
		return $result
	}

	if ($facets[0] -match '^(max|-1)$') { $result.MaxLength = -1 }
	elseif ($facets[0] -match '^\d+$') { $result.MaxLength = [int]$facets[0] }
	$result
}
