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

	# Build a cache key from column signatures
	$colSignatures = foreach ($col in $Columns) {
		$semanticType = if ($col.SemanticType) { $col.SemanticType } else { $col.DataType }
		"$($col.ColumnName):$semanticType"
	}
	$cacheKey = "$TableName|$($colSignatures -join '|')|$Locale"

	if (-not $Force -and $script:SldgState.AIValueCache.ContainsKey($cacheKey)) {
		$ttlMinutes = Get-PSFConfigValue -FullName 'SqlLabDataGenerator.Cache.TTLMinutes'
		$tsKey = "AIValueCache|$cacheKey"
		$isExpired = $false
		if ($ttlMinutes -gt 0 -and $script:SldgState.CacheTimestamps.ContainsKey($tsKey)) {
			$isExpired = ([datetime]::UtcNow - $script:SldgState.CacheTimestamps[$tsKey]).TotalMinutes -gt $ttlMinutes
		}
		if (-not $isExpired) {
			$cached = $script:SldgState.AIValueCache[$cacheKey]
			if ($cached.Count -ge $BatchSize) {
				return $cached
			}
		} else {
			$script:SldgState.AIValueCache.Remove($cacheKey)
			$script:SldgState.CacheTimestamps.Remove($tsKey)
		}
	}

	$aiProvider = Get-PSFConfigValue -FullName 'SqlLabDataGenerator.AI.Provider'
	if ($aiProvider -eq 'None') { return $null }

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

	$systemPrompt = @"
You are a test data generation AI. Generate exactly $BatchSize rows of realistic, consistent test data.

Table: $TableName
Locale: $Locale (generate culturally-appropriate data for this locale/language)
Columns:
$colText

Rules:
- Generate data in the native language of the locale ($Locale)
- Values must be realistic and internally consistent (e.g., Email matches the person's name)
- Respect data types and max lengths
- For cross-column dependencies, make values consistent (e.g., if there's FirstName and Email, the email should contain the first name)
- Vary the data — don't repeat the same patterns
- For Status/Category columns, use realistic business values appropriate for the table context
- For nullable columns, occasionally include null (use JSON null)
- For numeric columns, use appropriate ranges
- For date columns, use ISO format (YYYY-MM-DD or YYYY-MM-DDTHH:mm:ss)

Return ONLY a JSON array of $BatchSize objects. Each object must have exactly these keys: $($colNames -join ', ')
No markdown, no explanation, just the JSON array.

Example row format:
$jsonRow
"@

	if ($IndustryHint) {
		$systemPrompt += "`n`nIndustry context: $IndustryHint — use industry-specific terminology and realistic values."
	}

	$userMessage = "Generate $BatchSize rows of test data for table $TableName with locale $Locale. Return ONLY the JSON array."

	Write-PSFMessage -Level Verbose -Message ($script:strings.'AI.BatchGenerating' -f $TableName, $BatchSize, $Locale)

	$response = Invoke-SldgAIRequest -SystemPrompt $systemPrompt -UserMessage $userMessage

	if (-not $response) { return $null }

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
