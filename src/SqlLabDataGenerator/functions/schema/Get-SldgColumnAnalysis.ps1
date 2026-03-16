function Get-SldgColumnAnalysis {
	<#
	.SYNOPSIS
		Performs semantic analysis on database columns.

	.DESCRIPTION
		Classifies each column in the schema using pattern matching and optionally AI analysis.
		Returns the schema model enriched with semantic types, PII flags, and recommended
		generation strategies.

		When AI is enabled, the analysis is significantly richer — AI understands column
		names in any language (Czech, German, etc.), recognizes business context from
		table/column relationships, and provides specific generation instructions with
		example values and cross-column dependencies.

	.PARAMETER Schema
		The schema model from Get-SldgDatabaseSchema.

	.PARAMETER UseAI
		If specified, uses the configured AI provider for deeper semantic analysis.
		AI recognizes columns like DisplayName, Jmeno, Prijmeni, Telefon, etc.
		Requires AI.Provider to be configured (+ AI.ApiKey for OpenAI/AzureOpenAI).

	.PARAMETER IndustryHint
		Optional hint about the industry domain (e.g., 'Healthcare', 'Finance', 'Retail').
		Improves AI classification accuracy with domain-specific context.

	.PARAMETER Locale
		Target locale for AI-generated value examples (e.g., 'cs-CZ', 'de-DE').

	.EXAMPLE
		PS C:\> $schema = Get-SldgDatabaseSchema
		PS C:\> $analyzed = Get-SldgColumnAnalysis -Schema $schema

		Analyzes columns using pattern matching.

	.EXAMPLE
		PS C:\> $analyzed = Get-SldgColumnAnalysis -Schema $schema -UseAI -IndustryHint 'Healthcare'

		Uses AI for deeper healthcare-specific analysis.

	.EXAMPLE
		PS C:\> $analyzed = Get-SldgColumnAnalysis -Schema $schema -UseAI -Locale 'cs-CZ'

		AI generates Czech-specific value examples and recognizes Czech column names.
	#>
	[CmdletBinding()]
	param (
		[Parameter(Mandatory)]
		$Schema,

		[switch]$UseAI,

		[string]$IndustryHint,

		[string]$Locale
	)

	$totalColumns = ($Schema.Tables | Measure-Object -Property ColumnCount -Sum).Sum
	Write-PSFMessage -Level Host -Message ($script:strings.'Semantic.Analyzing' -f $totalColumns, $Schema.TableCount)

	# First pass: pattern-based classification
	foreach ($table in $Schema.Tables) {
		foreach ($col in $table.Columns) {
			$classification = Get-SldgColumnClassification -Column $col -TableName $table.FullName
			$col.Classification = $classification
			$col.SemanticType = $classification.SemanticType

			if ($classification.IsPII) {
				Write-PSFMessage -Level Verbose -Message ($script:strings.'Semantic.PIIDetected' -f $table.FullName, $col.ColumnName, $classification.SemanticType)
			}
		}
	}

	# Second pass: AI enrichment (if enabled)
	if ($UseAI) {
		Write-PSFMessage -Level Host -Message ($script:strings.'Semantic.AIAnalysis' -f $Schema.TableCount)
		$aiResults = Get-SldgAIColumnAnalysis -SchemaModel $Schema -IndustryHint $IndustryHint -Locale $Locale

		if ($aiResults) {
			foreach ($aiItem in $aiResults) {
				$table = $Schema.Tables | Where-Object { $_.FullName -eq $aiItem.TableName } | Select-Object -First 1
				if (-not $table) { continue }

				$col = $table.Columns | Where-Object { $_.ColumnName -eq $aiItem.ColumnName } | Select-Object -First 1
				if (-not $col) { continue }

				# AI overrides pattern match if higher confidence
				if ($aiItem.Confidence -gt $col.Classification.Confidence) {
					$col.Classification = $aiItem
					$col.SemanticType = $aiItem.SemanticType
				}

				# Store AI enrichment data for generation engine
				if ($aiItem.ValueExamples -and $aiItem.ValueExamples.Count -gt 0) {
					$col | Add-Member -NotePropertyName AIValueExamples -NotePropertyValue $aiItem.ValueExamples -Force
				}
				if ($aiItem.ValuePattern) {
					$col | Add-Member -NotePropertyName AIValuePattern -NotePropertyValue $aiItem.ValuePattern -Force
				}
				if ($aiItem.CrossColumnDependency) {
					$col | Add-Member -NotePropertyName AICrossColumnDependency -NotePropertyValue $aiItem.CrossColumnDependency -Force
				}
				if ($aiItem.MatchedRule) {
					$col | Add-Member -NotePropertyName AIGenerationHint -NotePropertyValue $aiItem.MatchedRule -Force
				}
			}
		}
	}

	$Schema
}
