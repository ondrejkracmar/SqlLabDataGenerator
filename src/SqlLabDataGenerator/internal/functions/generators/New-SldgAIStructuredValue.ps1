function New-SldgAIStructuredValue {
	<#
	.SYNOPSIS
		Uses AI to generate a single structured data value.
	#>
	[CmdletBinding()]
	param (
		[string]$Type,
		[string]$ColumnName,
		[string]$TableName,
		[string]$SchemaHint,
		[int]$MaxLength
	)

	$cacheKey = "StructuredData|$TableName|$ColumnName|$Type"

	# Return from template cache if we have previously generated a structure
	if ($script:SldgState.AIValueCache.ContainsKey($cacheKey)) {
		$cached = $script:SldgState.AIValueCache[$cacheKey]
		if ($cached -and $cached.Count -gt 0) {
			return ($cached | Get-Random)
		}
	}

	$format = if ($Type -eq 'Json') { 'JSON' } else { 'XML' }
	$hintText = if ($SchemaHint) { "`nSchema hint (from view definition): $SchemaHint" } else { '' }

	$systemPrompt = @"
You are a test data generator. Generate 10 different realistic $format values for a database column.

Table: $TableName
Column: $ColumnName
Format: $format
Max length: $MaxLength characters$hintText

Rules:
- Each value must be valid, well-formed $format
- Values should be realistic and varied — represent what a real application would store
- Infer the likely structure from the table name, column name, and schema hint
- For JSON: use appropriate nested objects, arrays, and data types (strings, numbers, booleans, nulls)
- For XML: include a meaningful root element, attributes where appropriate, and realistic child elements
- Keep each value under $MaxLength characters
- For JSON columns with names like 'settings', 'config', 'preferences' — generate key-value configuration data
- For JSON columns with names like 'metadata', 'properties', 'attributes' — generate descriptive metadata
- For JSON columns with names like 'payload', 'data', 'content' — generate business-relevant structured data
- For XML columns — generate well-formed XML with a root element appropriate for the context

Return ONLY a JSON array of 10 string values (each string is a valid $format document).
No markdown, no explanation, just the JSON array of strings.
"@

	$userMessage = "Generate 10 realistic $format values for column '$ColumnName' in table '$TableName'."

	Write-PSFMessage -Level Verbose -Message ($script:strings.'StructuredData.AIGenerating' -f $Type, $TableName, $ColumnName)

	try {
		$response = Invoke-SldgAIRequest -SystemPrompt $systemPrompt -UserMessage $userMessage

		if (-not $response) { return $null }

		$jsonText = $response
		if ($jsonText -match '```(?:json)?\s*\n?([\s\S]*?)\n?```') {
			$jsonText = $Matches[1]
		}
		elseif ($jsonText -match '(\[[\s\S]*?\])') {
			$jsonText = $Matches[1]
		}

		$parsed = $jsonText | ConvertFrom-Json -ErrorAction Stop

		if ($parsed -and $parsed.Count -gt 0) {
			# Validate and filter results
			$valid = @(foreach ($item in $parsed) {
				$str = if ($item -is [string]) { $item } else { $item | ConvertTo-Json -Depth 10 -Compress }
				if ($str.Length -le $MaxLength) { $str }
			})

			if ($valid.Count -gt 0) {
				# Cache for reuse
				Invoke-SldgCacheEviction -Cache $script:SldgState.AIValueCache -CacheName 'AIValueCache'
				$script:SldgState.AIValueCache[$cacheKey] = $valid
				$script:SldgState.CacheTimestamps["AIValueCache|$cacheKey"] = [datetime]::UtcNow
				Write-PSFMessage -Level Verbose -Message ($script:strings.'StructuredData.AIGenerated' -f $Type, $valid.Count, $TableName, $ColumnName)
				return ($valid | Get-Random)
			}
		}
	}
	catch {
		Write-PSFMessage -Level Warning -Message ($script:strings.'StructuredData.AIFailed' -f $Type, $TableName, $ColumnName, $_)
	}

	return $null
}
