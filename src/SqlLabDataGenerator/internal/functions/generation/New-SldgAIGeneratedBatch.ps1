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
		$localeInstruction = $script:strings.'AI.LocaleMultiple' -f $localeDisplay
	} else {
		$localeDisplay = $localeList[0]
		$localeInstruction = $script:strings.'AI.LocaleSingle' -f $localeDisplay
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

	# Read configurable chunk size — increase for fast local models (Ollama)
	$maxAIBatch = Get-PSFConfigValue -FullName 'SqlLabDataGenerator.Generation.MaxAIBatchSize'
	if (-not $maxAIBatch -or $maxAIBatch -lt 1) { $maxAIBatch = 50 }

	$allResults = [System.Collections.Generic.List[hashtable]]::new()
	$remaining = $BatchSize

	while ($remaining -gt 0) {
		$chunkSize = [Math]::Min($remaining, $maxAIBatch)

		$chunkSystemPrompt = Resolve-SldgPromptTemplate -Purpose 'batch-generation' -Variables @{
			BatchSize          = $chunkSize
			TableName          = $TableName
			Locale             = $localeDisplay
			LocaleInstruction  = $localeInstruction
			ColumnDescriptions = $colText
			ColumnNames        = ($colNames -join ', ')
			JsonExample        = $jsonRow
		}
		if (-not $chunkSystemPrompt) {
			Write-PSFMessage -Level Warning -String 'Prompt.ResolveFailed' -StringValues 'batch-generation'
			break
		}
		if ($IndustryHint) {
			$sanitizedHint = ($IndustryHint -replace '[\x00-\x1F\x7F]', ' ')
			if ($sanitizedHint.Length -gt 200) { $sanitizedHint = $sanitizedHint.Substring(0, 200) }
			$chunkSystemPrompt += "`n`n" + ($script:strings.'AI.IndustryContext' -f $sanitizedHint)
		}

		$userMessage = $script:strings.'AI.BatchUserMessage' -f $chunkSize, $TableName, $localeDisplay

		Write-PSFMessage -Level Verbose -Message ($script:strings.'AI.BatchGenerating' -f $TableName, $chunkSize, $Locale)

		$response = Invoke-SldgAIRequest -SystemPrompt $chunkSystemPrompt -UserMessage $userMessage -Purpose 'batch-generation'

		if (-not $response) {
			Write-PSFMessage -Level Warning -String 'AI.BatchNoResponse' -StringValues $TableName
			break
		}

		# Parse JSON response
		$jsonText = $response
		if ($jsonText -match '```(?:json)?\s*\n?([\s\S]*?)\n?```') {
			$jsonText = $Matches[1]
		}
		elseif ($jsonText -match '(\[[\s\S]*?\])') {
			$jsonText = $Matches[1]
		}

		# Fix invalid JSON escape sequences (e.g. \+ from regex patterns)
		$jsonText = [regex]::Replace($jsonText, '\\(?!["\\/bfnrtu])', '\\\\')
		# Remove truncation artifacts (e.g. trailing "..." in arrays)
		$jsonText = $jsonText -replace ',?\s*"\.{3,}"\s*\]', ']'
		$jsonText = $jsonText -replace ',?\s*\.{3,}\s*\]', ']'
		# Fix truncated JSON: unclosed array
		if ($jsonText -match '^\s*\[' -and $jsonText -notmatch '\]\s*$') {
			$jsonText = $jsonText -replace ',?\s*\{[^}]*$', ''
			$jsonText = $jsonText.TrimEnd() + ']'
		}

		try {
			$parsed = $jsonText | ConvertFrom-Json -ErrorAction Stop

			if ($parsed -isnot [System.Array] -and $parsed -isnot [System.Collections.IEnumerable]) {
				Write-PSFMessage -Level Warning -Message ($script:strings.'AI.BatchParseFailed' -f $TableName, $script:strings.'AI.BatchNotArray')
				break
			}

			foreach ($row in $parsed) {
				$rowHash = @{}
				foreach ($colName in $colNames) {
					$val = $row.$colName
					$rowHash[$colName] = if ($null -eq $val) { [DBNull]::Value } else { $val }
				}
				$allResults.Add($rowHash)
			}

			$remaining -= $parsed.Count
			# If AI returned fewer rows than requested, it hit its output limit — stop looping
			if ($parsed.Count -lt $chunkSize) { break }
		}
		catch {
			Write-PSFMessage -Level Warning -Message ($script:strings.'AI.BatchParseFailed' -f $TableName, $_)
			break
		}
	}

	if ($allResults.Count -eq 0) {
		return $null
	}

	$result = @($allResults)

	# Cache the result
	Invoke-SldgCacheEviction -Cache $script:SldgState.AIValueCache -CacheName 'AIValueCache'
	$script:SldgState.AIValueCache[$cacheKey] = $result
	$script:SldgState.CacheTimestamps["AIValueCache|$cacheKey"] = [datetime]::UtcNow
	Write-PSFMessage -Level Verbose -Message ($script:strings.'AI.BatchGenerated' -f $TableName, $result.Count)

	return $result
}
