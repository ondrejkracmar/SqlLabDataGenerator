function New-SldgAIStructuredValue {
	<#
	.SYNOPSIS
		Uses AI to generate a single structured data value.
	.DESCRIPTION
		When ContextColumn/ContextValue are provided, generates structure-varied data
		keyed by the context value (e.g., different JSON schemas per report type).
		Results are cached per (table, column, type, context) for reuse.
	#>
	[CmdletBinding()]
	param (
		[string]$Type,
		[string]$ColumnName,
		[string]$TableName,
		[string]$SchemaHint,
		[int]$MaxLength = 4000,
		[string]$AIGenerationHint,
		[string]$ContextColumn,
		[string]$ContextValue,
		[string[]]$ValueExamples
	)

	# Build cache key — include context value when present for per-variant caching
	# Escape pipe characters in components to prevent key collision across different table/column combinations
	$safeTable = $TableName.Replace('|', '||')
	$safeColumn = $ColumnName.Replace('|', '||')
	$safeType = $Type.Replace('|', '||')
	$contextSuffix = if ($ContextColumn -and $ContextValue) { "|ctx:$($ContextValue.Replace('|', '||'))" } else { '' }
	$cacheKey = "StructuredData|$safeTable|$safeColumn|$safeType$contextSuffix"

	# Return from template cache if we have previously generated values
	if ($script:SldgState.AIValueCache.ContainsKey($cacheKey)) {
		$cached = $script:SldgState.AIValueCache[$cacheKey]
		if ($cached -and $cached.Count -gt 0) {
			return ($cached | Get-Random)
		}
	}

	$format = if ($Type -eq 'Json') { 'JSON' } else { 'XML' }
	$hintText = if ($SchemaHint) { "`nSchema hint (from view definition): $SchemaHint" } else { '' }
	$aiHintText = if ($AIGenerationHint) { "`nGeneration context: $AIGenerationHint" } else { '' }
	$contextText = if ($ContextColumn -and $ContextValue) {
		# Sanitize ContextValue to mitigate prompt injection from DB data
		$safeContextValue = ($ContextValue -replace '[^\p{L}\p{N}\s\.\-,;:()\[\]_/''"=<>+#&]', '')
		if ($safeContextValue.Length -gt 500) { $safeContextValue = $safeContextValue.Substring(0, 500) }
		"`nContext: The column '$ContextColumn' for this row has the value '$safeContextValue'. Generate $format content that is appropriate for this specific $ContextColumn value. The structure and fields should reflect what '$safeContextValue' means in business terms."
	} else { '' }
	$examplesText = if ($ValueExamples -and $ValueExamples.Count -gt 0) {
		$exList = ($ValueExamples | ForEach-Object { "  - $_" }) -join "`n"
		"`nExample values (use as structure reference):`n$exList"
	} else { '' }

	# Use contextual prompt when we have context, standard otherwise
	$promptPurpose = if ($ContextColumn -and $ContextValue) { 'structured-value-contextual' } else { 'structured-value' }

	$promptVars = @{
		Format     = $format
		TableName  = $TableName
		ColumnName = $ColumnName
		MaxLength  = $MaxLength
		SchemaHint = $hintText
	}
	# Contextual prompt uses additional variables
	if ($ContextColumn -and $ContextValue) {
		$promptVars['AIGenerationHint'] = $aiHintText
		$promptVars['ContextColumn'] = $ContextColumn
		$promptVars['ContextValue'] = $ContextValue
		$promptVars['ContextText'] = $contextText
		$promptVars['ExamplesText'] = $examplesText
	}

	$systemPrompt = Resolve-SldgPromptTemplate -Purpose $promptPurpose -Variables $promptVars

	# Fall back to standard prompt if contextual template not found
	if (-not $systemPrompt -and $promptPurpose -eq 'structured-value-contextual') {
		$systemPrompt = Resolve-SldgPromptTemplate -Purpose 'structured-value' -Variables $promptVars
	}

	if (-not $systemPrompt) {
		Write-PSFMessage -Level Warning -String 'Prompt.ResolveFailed' -StringValues $promptPurpose
		return $null
	}

	# Append AI hint and context to the standard prompt when not using contextual template
	if ($promptPurpose -eq 'structured-value') {
		$systemPrompt += $aiHintText + $contextText + $examplesText
	}

	$safeTableName = ($TableName -replace '[^\p{L}\p{N}\s\.\-_\[\]]', '')
	$safeColumnName = ($ColumnName -replace '[^\p{L}\p{N}\s\.\-_\[\]]', '')
	$contextLabel = if ($ContextValue) { " (context: $ContextColumn=$ContextValue)" } else { '' }
	$userMessage = "Generate 10 realistic $format values for column '$safeColumnName' in table '$safeTableName'$contextLabel."

	Write-PSFMessage -Level Verbose -Message ($script:strings.'StructuredData.AIGenerating' -f $Type, $TableName, $ColumnName)

	try {
		$response = Invoke-SldgAIRequest -SystemPrompt $systemPrompt -UserMessage $userMessage -Purpose $promptPurpose

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
				# Cache for reuse (keyed by context for variant caching)
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

	# Return type-appropriate fallback instead of $null to avoid NOT NULL constraint violations
	$fallback = if ($Type -eq 'Xml') { '<root />' } else { '{}' }
	return $fallback
}
