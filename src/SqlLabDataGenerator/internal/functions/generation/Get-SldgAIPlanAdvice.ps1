function Get-SldgAIPlanAdvice {
	<#
	.SYNOPSIS
		Uses AI to analyze the schema and suggest optimal generation parameters.
	.DESCRIPTION
		Sends the full schema context to AI which then suggests:
		- Recommended row counts per table (respecting parent:child ratios)
		- Business pattern analysis (1:N, M:N relationships, lookup tables)
		- Custom generation rules for domain-specific columns
		- Cross-table consistency requirements
	#>
	[CmdletBinding()]
	param (
		[Parameter(Mandatory)]
		$SchemaModel,

		[int]$BaseRowCount = 100,

		[string]$IndustryHint,

		[string]$Locale
	)

	$aiProvider = Get-PSFConfigValue -FullName 'SqlLabDataGenerator.AI.Provider'
	if ($aiProvider -eq 'None') {
		Write-PSFMessage -Level Verbose -String 'AI.PlanAdviceSkipped'
		return $null
	}

	if (-not $Locale) {
		$Locale = Get-PSFConfigValue -FullName 'SqlLabDataGenerator.Generation.Locale'
	}

	# Build schema description
	$schemaSummary = foreach ($table in $SchemaModel.Tables) {
		$colLines = foreach ($col in $table.Columns) {
			$fk = if ($col.ForeignKey) { " -> $($col.ForeignKey.ReferencedTable).$($col.ForeignKey.ReferencedColumn)" } else { "" }
			$flags = @()
			if ($col.IsPrimaryKey) { $flags += 'PK' }
			if ($col.IsIdentity) { $flags += 'IDENTITY' }
			if ($col.IsNullable) { $flags += 'NULL' }
			if ($col.IsUnique) { $flags += 'UNIQUE' }
			$flagStr = if ($flags) { " [$($flags -join ',')]" } else { "" }
			$semanticStr = if ($col.SemanticType) { " (semantic: $($col.SemanticType))" } else { "" }
			"  - $($col.ColumnName) $($col.DataType)$flagStr$fk$semanticStr"
		}
		"TABLE: $($table.FullName) ($($table.ColumnCount) columns)`n$($colLines -join "`n")"
	}
	$schemaText = $schemaSummary -join "`n`n"

	$systemPrompt = Resolve-SldgPromptTemplate -Purpose 'plan-advice' -Variables @{
		BaseRowCount = $BaseRowCount
		Locale       = $Locale
	}

	if (-not $systemPrompt) {
		Write-PSFMessage -Level Warning -String 'Prompt.ResolveFailed' -StringValues 'plan-advice'
		return $null
	}

	if ($IndustryHint) {
		$systemPrompt += "`n`nIndustry: $IndustryHint. Use domain knowledge for realistic ratios and business patterns."
	}

	$userMessage = "Analyze this schema and suggest generation parameters:`n`n$schemaText"

	Write-PSFMessage -Level Verbose -Message ($script:strings.'AI.PlanAdviceRequesting' -f $SchemaModel.TableCount)

	$response = Invoke-SldgAIRequest -SystemPrompt $systemPrompt -UserMessage $userMessage -Purpose 'plan-advice'

	if (-not $response) {
		Write-PSFMessage -Level Warning -String 'AI.PlanAdviceNoResponse'
		return $null
	}

	$jsonText = $response
	if ($jsonText -match '```(?:json)?\s*\n?([\s\S]*?)\n?```') {
		$jsonText = $Matches[1]
	}
	elseif ($jsonText -match '(\{[\s\S]*\})') {
		$jsonText = $Matches[1]
	}

	# Sanitize common AI JSON issues: trailing "..." placeholders, trailing commas
	$jsonText = $jsonText -replace ',\s*"\.{2,}"', ''          # remove "..." entries after comma
	$jsonText = $jsonText -replace '"\.{2,}"\s*,?', ''         # remove standalone "..." entries
	$jsonText = $jsonText -replace '(?<=[\]\}]),\s*(?=[\]\}])', '' # remove trailing commas

	try {
		$parsed = $jsonText | ConvertFrom-Json -ErrorAction Stop

		# Validate expected structure
		if (-not $parsed.tables) {
			Write-PSFMessage -Level Warning -Message ($script:strings.'AI.PlanAdviceFailed' -f 'AI response missing required "tables" property')
			return $null
		}

		# Convert table suggestions to hashtable
		$tableSuggestions = @{}
		if ($parsed.tables) {
			foreach ($prop in $parsed.tables.PSObject.Properties) {
				$tableSuggestions[$prop.Name] = @{
					RowCount  = [int]$prop.Value.rowCount
					TableType = [string]$prop.Value.tableType
					Notes     = [string]$prop.Value.notes
				}
			}
		}

		# Convert custom rules
		$customRules = @(if ($parsed.customRules) {
				foreach ($rule in $parsed.customRules) {
					@{
						TableName  = [string]$rule.tableName
						ColumnName = [string]$rule.columnName
						RuleType   = [string]$rule.ruleType
						Values     = @(if ($rule.values) { $rule.values } else { @() })
						Hint       = if ($rule.hint) { [string]$rule.hint } else { $null }
					}
				}
			})

		# Convert cross-table rules
		$crossTableRules = @(if ($parsed.crossTableRules) {
				foreach ($rule in $parsed.crossTableRules) {
					@{
						Description = [string]$rule.description
						Tables      = @(if ($rule.tables) { $rule.tables } else { @() })
						Columns     = @(if ($rule.columns) { $rule.columns } else { @() })
					}
				}
			})

		Write-PSFMessage -Level Verbose -Message ($script:strings.'AI.PlanAdviceReceived' -f $tableSuggestions.Count, $customRules.Count)

		[SqlLabDataGenerator.AIPlanAdvice]@{
			Tables          = $tableSuggestions
			CustomRules     = $customRules
			CrossTableRules = $crossTableRules
			Source          = $aiProvider
			GeneratedAt     = Get-Date
		}
	}
	catch {
		Write-PSFMessage -Level Warning -Message ($script:strings.'AI.PlanAdviceFailed' -f $_)
		$null
	}
}
