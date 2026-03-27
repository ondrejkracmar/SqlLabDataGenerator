function Get-SldgAIColumnAnalysis {
	<#
	.SYNOPSIS
		Uses an AI provider for deep semantic analysis of database columns.
	.DESCRIPTION
		Sends full schema context (tables, columns, types, FKs, constraints) to AI
		for intelligent classification. AI recognizes column purposes from names,
		relationships, data types, and domain context — including non-English names
		like DisplayName, Jmeno, Prijmeni, Telefon, Oddeleni, etc.

		Returns enriched classifications with AI-generated value examples and
		specific generation instructions per column.
	#>
	[CmdletBinding()]
	param (
		[Parameter(Mandatory)]
		$SchemaModel,

		[string]$IndustryHint,

		[string]$Locale
	)

	$aiProvider = Get-PSFConfigValue -FullName 'SqlLabDataGenerator.AI.Provider'
	if ($aiProvider -eq 'None') {
		Write-PSFMessage -Level Verbose -Message $script:strings.'Semantic.AINotConfigured'
		return $null
	}

	if (-not $Locale) {
		$Locale = Get-PSFConfigValue -FullName 'SqlLabDataGenerator.Generation.Locale'
	}

	# Build per-table schema descriptions for batching
	$tableDescriptions = foreach ($table in $SchemaModel.Tables) {
		$colLines = foreach ($col in $table.Columns) {
			$fk = if ($col.ForeignKey) { " -> $($col.ForeignKey.ReferencedTable).$($col.ForeignKey.ReferencedColumn)" } else { "" }
			$flags = @()
			if ($col.IsPrimaryKey) { $flags += 'PK' }
			if ($col.IsIdentity) { $flags += 'IDENTITY' }
			if ($col.IsNullable) { $flags += 'NULL' }
			if ($col.IsUnique) { $flags += 'UNIQUE' }
			$flagStr = if ($flags) { " [$($flags -join ',')]" } else { "" }
			$lenStr = if ($col.MaxLength -and $col.MaxLength -gt 0) { "($($col.MaxLength))" } else { "" }
			$checkStr = if ($col.CheckConstraint) { " CHECK($($col.CheckConstraint))" } else { "" }
			"  - $($col.ColumnName) $($col.DataType)$lenStr$flagStr$fk$checkStr"
		}
		$fkSummary = foreach ($fk in $table.ForeignKeys) {
			"  FK: $($fk.ColumnName) -> $($fk.ReferencedTable).$($fk.ReferencedColumn)"
		}
		$fkText = if ($fkSummary) { "`n$($fkSummary -join "`n")" } else { "" }
		@{
			Table       = $table
			Description = "TABLE: $($table.FullName) ($($table.ColumnCount) columns)`n$($colLines -join "`n")$fkText"
		}
	}

	$systemPrompt = Resolve-SldgPromptTemplate -Purpose 'column-analysis' -Variables @{
		Locale = $Locale
	}

	if (-not $systemPrompt) {
		Write-PSFMessage -Level Warning -String 'Semantic.PromptResolveFailed'
		return $null
	}

	if ($IndustryHint) {
		$systemPrompt += "`n`n" + ($script:strings.'AI.IndustryAnalysisContext' -f $IndustryHint)
	}

	# Split tables into batches to avoid AI output truncation
	# Target ~100 columns per batch (AI reliably handles this size)
	$maxColumnsPerBatch = 100
	$batches = [System.Collections.Generic.List[object]]::new()
	$currentBatch = [System.Collections.Generic.List[object]]::new()
	$currentColCount = 0

	foreach ($td in $tableDescriptions) {
		$tableColCount = $td.Table.ColumnCount
		if ($currentBatch.Count -gt 0 -and ($currentColCount + $tableColCount) -gt $maxColumnsPerBatch) {
			$batches.Add($currentBatch.ToArray())
			$currentBatch = [System.Collections.Generic.List[object]]::new()
			$currentColCount = 0
		}
		$currentBatch.Add($td)
		$currentColCount += $tableColCount
	}
	if ($currentBatch.Count -gt 0) { $batches.Add($currentBatch.ToArray()) }

	$batchIndex = 0
	foreach ($batch in $batches) {
		$batchIndex++
		$schemaText = ($batch | ForEach-Object { $_.Description }) -join "`n`n"
		$batchTables = ($batch | ForEach-Object { $_.Table.FullName }) -join ', '

		if ($batches.Count -gt 1) {
			Write-PSFMessage -Level Verbose -Message ($script:strings.'AI.AnalysisBatch' -f $batchIndex, $batches.Count, $batchTables)
		}

		$userMessage = ($script:strings.'AI.AnalysisUserMessage') + "`n`n$schemaText"

		$response = Invoke-SldgAIRequest -SystemPrompt $systemPrompt -UserMessage $userMessage -Purpose 'column-analysis'

		if (-not $response) { continue }

		try {
			$jsonContent = $response
			if ($jsonContent -match '```(?:json)?\s*([\s\S]*?)\s*```') {
				$jsonContent = $Matches[1]
			}
			elseif ($jsonContent -match '(\[[\s\S]*?\])') {
				$jsonContent = $Matches[1]
			}

			# Fix invalid JSON escape sequences from AI-generated regex patterns (e.g., \d, \+, \w)
			# Valid JSON escapes: \", \\, \/, \b, \f, \n, \r, \t, \uXXXX — everything else is illegal
			# (?<!\\) lookbehind: skip the second \ in valid \\ pairs so we only fix bare invalid escapes
			# Only apply the regex fix if initial parse fails — avoids corrupting valid regex patterns in values
			$parseError = $null
			try { $null = $jsonContent | ConvertFrom-Json -ErrorAction Stop } catch { $parseError = $_ }
			if ($parseError) {
				$jsonContent = [regex]::Replace($jsonContent, '(?<!\\)\\(?!["\\\/bfnrtu])', '\\')
			}

			# Remove AI truncation artifacts: trailing "..." or ", ..." before closing bracket
			$jsonContent = $jsonContent -replace ',?\s*\.{3,}\s*\]', ']'

			$parsed = $jsonContent | ConvertFrom-Json

			foreach ($item in $parsed) {
				[SqlLabDataGenerator.ColumnClassification]@{
					ColumnName            = $item.ColumnName
					TableName             = $item.TableName
					SemanticType          = $item.SemanticType
					IsPII                 = [bool]$item.IsPII
					Confidence            = if ($item.PSObject.Properties.Name -contains 'Confidence' -and $item.Confidence) { [Math]::Min([double]$item.Confidence, 1.0) } else { 0.95 }
					Source                = 'AI'
					MatchedRule           = $item.GenerationHint
					ValueExamples         = @(if ($item.ValueExamples) { $item.ValueExamples } else { @() })
					ValuePattern          = if ($item.ValuePattern) { [string]$item.ValuePattern } else { $null }
					CrossColumnDependency = if ($item.CrossColumnDependency) { [string]$item.CrossColumnDependency } else { $null }
				}
			}
		}
		catch {
			Write-PSFMessage -Level Warning -Message ($script:strings.'AI.ParseFailed' -f $_)
		}
	}
}
