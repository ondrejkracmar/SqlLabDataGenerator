function New-SldgAIGeneratedBatch {
	<#
	.SYNOPSIS
		Uses AI to generate a batch of realistic values for one or more columns.
	.DESCRIPTION
		Sends column context (semantic type, table name, data type, constraints,
		AI hints, cross-column dependencies) to AI and requests a batch of
		realistic values. AI understands the business context and generates
		consistent, culturally-appropriate data.

		Results are cached per column signature so repeated requests for the
		same column type are served from cache.
	#>
	[CmdletBinding()]
	param (
		[Parameter(Mandatory)]
		$Columns,

		[string]$TableName,

		[int]$BatchSize = 50,

		[string]$Locale,

		[string]$IndustryHint,

		[switch]$Force
	)

	if (-not $Locale) {
		$Locale = Get-PSFConfigValue -FullName 'SqlLabDataGenerator.Generation.Locale'
	}

	# Parse multi-locale: detect comma/semicolon-separated locale lists
	$localeList = @($Locale -split '[,;]' | ForEach-Object { $_.Trim() } | Where-Object { $_ })
	if ($localeList.Count -gt 1) {
		$localeDisplay = $localeList -join ', '
		$localeInstruction = "Multiple locales specified: $localeDisplay. Distribute rows roughly evenly across these locales. Each row must be culturally consistent within its locale — a person from one culture must have names, addresses, phone numbers, and other values matching that same culture. Do NOT mix languages within a single row."
	} else {
		$localeDisplay = $localeList[0]
		$localeInstruction = "Generate all data in the native language and cultural conventions of $localeDisplay."
	}

	# Build a cache key from column signatures
	$colSignatures = foreach ($col in $Columns) {
		$semanticType = if ($col.SemanticType) { $col.SemanticType } else { $col.DataType }
		"$($col.ColumnName):$semanticType"
	}
	$cacheKey = "$TableName|$($colSignatures -join '|')|$Locale"

	if (-not $Force -and $script:SldgState.AIValueCache.ContainsKey($cacheKey)) {
		if (-not (Test-SldgCacheExpired -CacheName 'AIValueCache' -Key $cacheKey)) {
			$cached = $script:SldgState.AIValueCache[$cacheKey]
			if ($cached.Count -ge $BatchSize) {
				return $cached
			}
		} else {
			$script:SldgState.AIValueCache.Remove($cacheKey)
			$script:SldgState.CacheTimestamps.Remove("AIValueCache|$cacheKey")
		}
	}

	$aiProvider = Get-PSFConfigValue -FullName 'SqlLabDataGenerator.AI.Provider'
	if ($aiProvider -eq 'None') {
		Write-PSFMessage -Level Verbose -String 'AI.BatchSkipped' -StringValues $TableName
		return $null
	}

	# Build column descriptions for the prompt
	$colDescriptions = foreach ($col in $Columns) {
		$semanticType = if ($col.SemanticType) { $col.SemanticType } else { 'Unknown' }
		$hint = if ($col.AIGenerationHint) { " — AI hint: $($col.AIGenerationHint)" } else { "" }
		$examples = if ($col.AIValueExamples -and $col.AIValueExamples.Count -gt 0) {
			" — examples: $($col.AIValueExamples -join ', ')"
		}
		else { "" }
		$pattern = if ($col.AIValuePattern) { " — pattern: $($col.AIValuePattern)" } else { "" }
		$dependency = if ($col.AICrossColumnDependency) { " — depends on: $($col.AICrossColumnDependency)" } else { "" }
		$nullable = if ($col.IsNullable) { " [NULLABLE]" } else { "" }
		$maxLen = if ($col.MaxLength -and $col.MaxLength -gt 0) { "($($col.MaxLength))" } else { "" }

		"  - $($col.ColumnName): $($col.DataType)$maxLen, semantic: $semanticType$nullable$hint$examples$pattern$dependency"
	}
	$colText = $colDescriptions -join "`n"

	# Build column name list for JSON structure
	$colNames = $Columns | ForEach-Object { $_.ColumnName }
	$jsonExample = $colNames | ForEach-Object { "`"$_`": `"value`"" }
	$jsonRow = "{ $($jsonExample -join ', ') }"

	$systemPrompt = Resolve-SldgPromptTemplate -Purpose 'batch-generation' -Variables @{
		BatchSize          = $BatchSize
		TableName          = $TableName
		Locale             = $localeDisplay
		LocaleInstruction  = $localeInstruction
		ColumnDescriptions = $colText
		ColumnNames        = ($colNames -join ', ')
		JsonExample        = $jsonRow
	}

	if (-not $systemPrompt) {
		Write-PSFMessage -Level Warning -String 'Prompt.ResolveFailed' -StringValues 'batch-generation'
		return $null
	}

	if ($IndustryHint) {
		# Sanitize: limit length and strip control characters to mitigate prompt injection
		$sanitizedHint = ($IndustryHint -replace '[\x00-\x1F\x7F]', ' ')
		if ($sanitizedHint.Length -gt 200) { $sanitizedHint = $sanitizedHint.Substring(0, 200) }
		$systemPrompt += "`n`nIndustry context: $sanitizedHint — use industry-specific terminology and realistic values."
	}

	$userMessage = "Generate $BatchSize rows of test data for table $TableName with locale $localeDisplay. Return ONLY the JSON array."

	Write-PSFMessage -Level Verbose -Message ($script:strings.'AI.BatchGenerating' -f $TableName, $BatchSize, $Locale)

	$response = Invoke-SldgAIRequest -SystemPrompt $systemPrompt -UserMessage $userMessage -Purpose 'batch-generation'

	if (-not $response) {
		Write-PSFMessage -Level Warning -String 'AI.BatchNoResponse' -StringValues $TableName
		return $null
	}

	# Parse JSON response
	$jsonText = $response
	if ($jsonText -match '```(?:json)?\s*\n?([\s\S]*?)\n?```') {
		$jsonText = $Matches[1]
	}
	elseif ($jsonText -match '(\[[\s\S]*?\])') {
		$jsonText = $Matches[1]
	}

	try {
		$parsed = $jsonText | ConvertFrom-Json -ErrorAction Stop

		# Validate response is an array
		if ($parsed -isnot [System.Array] -and $parsed -isnot [System.Collections.IEnumerable]) {
			Write-PSFMessage -Level Warning -Message ($script:strings.'AI.BatchParseFailed' -f $TableName, 'AI response is not an array')
			return $null
		}

		# Convert to array of hashtables for easy consumption
		$result = @(foreach ($row in $parsed) {
				$rowHash = @{}
				foreach ($colName in $colNames) {
					$val = $row.$colName
					$rowHash[$colName] = if ($null -eq $val) { [DBNull]::Value } else { $val }
				}
				$rowHash
			})

		# Cache the result
		Invoke-SldgCacheEviction -Cache $script:SldgState.AIValueCache -CacheName 'AIValueCache'
		$script:SldgState.AIValueCache[$cacheKey] = $result
		$script:SldgState.CacheTimestamps["AIValueCache|$cacheKey"] = [datetime]::UtcNow
		Write-PSFMessage -Level Verbose -Message ($script:strings.'AI.BatchGenerated' -f $TableName, $result.Count)

		return $result
	}
	catch {
		Write-PSFMessage -Level Warning -Message ($script:strings.'AI.BatchParseFailed' -f $TableName, $_)
		return $null
	}
}
