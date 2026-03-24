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

	# Build rich schema description with full context
	$schemaSummary = foreach ($table in $SchemaModel.Tables) {
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
		"TABLE: $($table.FullName) ($($table.ColumnCount) columns)`n$($colLines -join "`n")$fkText"
	}
	$schemaText = $schemaSummary -join "`n`n"

	$systemPrompt = Resolve-SldgPromptTemplate -Purpose 'column-analysis' -Variables @{
		Locale = $Locale
	}

	if (-not $systemPrompt) {
		Write-PSFMessage -Level Warning -String 'Semantic.PromptResolveFailed'
		return $null
	}

	if ($IndustryHint) {
		$systemPrompt += "`n`nThe database is from the $IndustryHint industry. Use industry-specific terminology, common patterns, realistic value ranges, and domain knowledge for generation hints."
	}

	$userMessage = "Analyze this database schema and provide detailed semantic classification for every column:`n`n$schemaText"

	$response = Invoke-SldgAIRequest -SystemPrompt $systemPrompt -UserMessage $userMessage -Purpose 'column-analysis'

	if (-not $response) { return $null }

	try {
		$jsonContent = $response
		if ($jsonContent -match '```(?:json)?\s*([\s\S]*?)\s*```') {
			$jsonContent = $Matches[1]
		}
		elseif ($jsonContent -match '(\[[\s\S]*\])') {
			$jsonContent = $Matches[1]
		}

		# Fix invalid JSON escape sequences from AI-generated regex patterns (e.g., \d, \+, \w)
		# Valid JSON escapes: \", \\, \/, \b, \f, \n, \r, \t, \uXXXX — everything else is illegal
		$jsonContent = [regex]::Replace($jsonContent, '\\(?!["\\/bfnrtu])', '\\\\')

		$parsed = $jsonContent | ConvertFrom-Json

		foreach ($item in $parsed) {
			[SqlLabDataGenerator.ColumnClassification]@{
				ColumnName            = $item.ColumnName
				TableName             = $item.TableName
				SemanticType          = $item.SemanticType
				IsPII                 = [bool]$item.IsPII
				Confidence            = 0.95
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
		$null
	}
}
