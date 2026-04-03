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

		[hashtable]$ExistingUniqueValues,

		[string]$TableNotes,

		[string]$TableContext,

		[string]$ParentContext,

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
	# Normalize locale order for consistent cache keys ("en-US,cs-CZ" == "cs-CZ,en-US")
	$canonicalLocale = ($localeList | Sort-Object) -join ','
	$cacheKey = "$TableName|$($colSignatures -join '|')|$canonicalLocale"
	if ($ParentContext) { $cacheKey += "|ctx:$ParentContext" }

	if (-not $Force) {
		$cached = $null
		if ($script:SldgState.AIValueCache.TryGetValue($cacheKey, [ref]$cached)) {
			if (-not (Test-SldgCacheExpired -CacheName 'AIValueCache' -Key $cacheKey)) {
				if ($cached.Count -ge $BatchSize) {
					return $cached
				}
			} else {
				[void]$script:SldgState.AIValueCache.TryRemove($cacheKey, [ref]$null)
				[void]$script:SldgState.CacheTimestamps.TryRemove("AIValueCache$($script:CacheKeySeparator)$cacheKey", [ref]$null)
			}
		}
	}

	$aiProvider = Get-PSFConfigValue -FullName 'SqlLabDataGenerator.AI.Provider'
	if ($aiProvider -eq 'None') {
		Write-PSFMessage -Level Verbose -Message ($script:strings.'AI.BatchSkipped' -f $TableName)
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
		$nullable = if ($col.IsNullable) { " [NULLABLE]" } else { " [NOT NULL]" }
		$unique = if ($col.IsUnique -or ($col.IsPrimaryKey)) { " [UNIQUE]" } else { "" }
		$pkFlag = if ($col.IsPrimaryKey) { " [PK]" } else { "" }
		# Type size: prefer MaxLength for string types, NumericPrecision/Scale for decimal types
		$maxLen = if ($col.MaxLength -and $col.MaxLength -gt 0) {
			"($($col.MaxLength))"
		}
		elseif ($col.NumericPrecision -and $col.DataType -match '^(decimal|numeric|money|smallmoney)$') {
			$scale = if ($col.NumericScale) { $col.NumericScale } else { 0 }
			"($($col.NumericPrecision),$scale)"
		}
		else { "" }
		# Add explicit numeric range constraint for bounded types
		$rangeHint = switch ($col.DataType.ToLower()) {
			'tinyint' { " [range: 0–255]" }
			'smallint' { " [range: -32768–32767]" }
			{ $_ -in @('decimal', 'numeric') } {
				if ($col.NumericPrecision) {
					$s = if ($col.NumericScale) { [int]$col.NumericScale } else { 0 }
					$intDigits = [int]$col.NumericPrecision - $s
					if ($intDigits -gt 0 -and $intDigits -le 18) {
						$maxInt = [math]::Pow(10, $intDigits) - 1
						if ($s -gt 0) { " [range: -$maxInt.$('9' * $s)–$maxInt.$('9' * $s)]" }
						else { " [range: -$maxInt–$maxInt]" }
					} else { "" }
				} else { "" }
			}
			default { "" }
		}
		# Check constraints
		$checkStr = if ($col.CheckConstraints -and $col.CheckConstraints.Count -gt 0) {
			" [CHECK: $($col.CheckConstraints -join '; ')]"
		} else { "" }
		# Default value (skip computed defaults like getdate(), newid())
		$defaultStr = if ($col.DefaultValue -and $col.DefaultValue -notmatch '(?i)getdate|newid|newsequentialid|sysdatetime') {
			" [DEFAULT: $($col.DefaultValue)]"
		} else { "" }

		"  - $($col.ColumnName): $($col.DataType)$maxLen, semantic: $semanticType$nullable$unique$pkFlag$rangeHint$checkStr$defaultStr$hint$examples$pattern$dependency"
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
	$maxIterations = 50
	$iteration = 0

	while ($remaining -gt 0 -and $iteration -lt $maxIterations) {
		$iteration++
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
			Write-PSFMessage -Level Warning -Message ($script:strings.'Prompt.ResolveFailed' -f 'batch-generation')
			break
		}

		# Inject table relationship context (FK structure, table role) so AI understands the table's place in the schema
		if ($TableContext) {
			$escapedContext = Remove-SldgUnsafeChar -Text $TableContext -Mode General -MaxLength 1500
			$escapedContext = $escapedContext -replace '\{', '{{' -replace '\}', '}}'
			$chunkSystemPrompt += "`n`nTABLE CONTEXT (this table's position in the database schema):`n$escapedContext"
		}

		# Inject per-table generation notes from schema analysis (two-tier AI)
		# Sanitize first to prevent prompt injection, then escape braces to avoid format-string injection
		if ($TableNotes) {
			$escapedNotes = Remove-SldgUnsafeChar -Text $TableNotes -Mode General -MaxLength 2000
			$escapedNotes = $escapedNotes -replace '\{', '{{' -replace '\}', '}}'
			$chunkSystemPrompt += "`n`nTABLE GENERATION NOTES (from schema analysis — follow these instructions carefully):`n$escapedNotes"
		}

		if ($IndustryHint) {
			$sanitizedHint = Remove-SldgUnsafeChar -Text $IndustryHint -Mode Strict -MaxLength 200
			$chunkSystemPrompt += "`n`n" + ($script:strings.'AI.IndustryContext' -f $sanitizedHint)
		}

		# Inject FK parent context for semantic consistency (e.g., cities matching their country,
		# or junction table rows coherent with both parents)
		if ($ParentContext) {
			$sanitizedContext = Remove-SldgUnsafeChar -Text $ParentContext -Mode General -MaxLength 2000
			$chunkSystemPrompt += "`n`nPARENT ROW CONTEXT (generate values that are semantically appropriate and consistent with the parent relationships described below):`n$sanitizedContext"
		}

		# Add existing UNIQUE values that must be avoided (prevent duplicate key violations)
		if ($ExistingUniqueValues -and $ExistingUniqueValues.Count -gt 0) {
			$exclusionLines = foreach ($col in $Columns) {
				if ($ExistingUniqueValues.ContainsKey($col.ColumnName) -and ($col.IsUnique -or $col.IsPrimaryKey)) {
					$existingVals = $ExistingUniqueValues[$col.ColumnName]
					# Limit to first 200 values to avoid token overflow; sanitize to prevent prompt injection
					$sample = @($existingVals | Select-Object -First 200 | ForEach-Object { "$_" -replace '[^\p{L}\p{N}\s\.\-_,]', '' } | Where-Object { $_.Length -gt 0 })
					if ($sample.Count -gt 0) {
						"  - $($col.ColumnName): DO NOT use these existing values: $($sample -join ', ')"
					}
				}
			}
			if ($exclusionLines) {
				$chunkSystemPrompt += "`n`nEXISTING VALUES (must be avoided for UNIQUE columns — generate DIFFERENT values):`n$($exclusionLines -join "`n")"
			}
		}

		$userMessage = $script:strings.'AI.BatchUserMessage' -f $chunkSize, $TableName, $localeDisplay

		Write-PSFMessage -Level Verbose -Message ($script:strings.'AI.BatchGenerating' -f $TableName, $chunkSize, $Locale)

		$response = Invoke-SldgAIRequest -SystemPrompt $chunkSystemPrompt -UserMessage $userMessage -Purpose 'batch-generation'

		if (-not $response) {
			Write-PSFMessage -Level Warning -Message ($script:strings.'AI.BatchNoResponse' -f $TableName)
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
		# (?<!\\) lookbehind: skip the second \ in valid \\ pairs so we only fix bare invalid escapes
		$jsonText = [regex]::Replace($jsonText, '(?<!\\)\\(?!["\\\//bfnrtu])', '\\', 'None', [timespan]::FromSeconds(2))
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
				# Validate AI returned all expected columns
				$rowProps = @($row.psobject.Properties.Name)
				$missingCols = @($colNames | Where-Object { $_ -notin $rowProps })
				if ($missingCols.Count -gt 0) {
					Write-PSFMessage -Level Warning -Message ($script:strings.'AI.BatchMissingColumns' -f $TableName, ($missingCols -join ', '))
				}
				foreach ($colName in $colNames) {
					$val = $row.$colName
					$rowHash[$colName] = if ($null -eq $val -or ($val -is [string] -and $val -eq 'null')) { [DBNull]::Value } else { $val }
				}
				$allResults.Add($rowHash)
			}

			$remaining -= $parsed.Count
			# If AI returned fewer rows than requested, log a warning and stop looping
			if ($parsed.Count -lt $chunkSize) {
				Write-PSFMessage -Level Warning -Message ($script:strings.'AI.BatchRowCountMismatch' -f $TableName, $parsed.Count, $chunkSize)
				break
			}
		}
		catch {
			Write-PSFMessage -Level Warning -Message ($script:strings.'AI.BatchParseFailed' -f $TableName, $_)
			break
		}
	}

	if ($iteration -ge $maxIterations -and $remaining -gt 0) {
		Write-PSFMessage -Level Warning -Message ($script:strings.'AI.BatchMaxIterations' -f $TableName, $maxIterations, $remaining)
	}

	if ($allResults.Count -eq 0) {
		return $null
	}

	$result = @($allResults)

	# Cache the result
	Invoke-SldgCacheEviction -Cache $script:SldgState.AIValueCache -CacheName 'AIValueCache'
	$script:SldgState.AIValueCache[$cacheKey] = $result
	$script:SldgState.CacheTimestamps["AIValueCache$($script:CacheKeySeparator)$cacheKey"] = [datetime]::UtcNow
	Write-PSFMessage -Level Verbose -Message ($script:strings.'AI.BatchGenerated' -f $TableName, $result.Count)

	return $result
}
