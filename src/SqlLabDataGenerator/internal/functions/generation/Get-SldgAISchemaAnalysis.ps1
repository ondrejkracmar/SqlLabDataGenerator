function Get-SldgAISchemaAnalysis {
	<#
	.SYNOPSIS
		Uses a smart AI model to deeply analyze the schema and sample data,
		producing per-table generation notes for the batch-generation model.
	.DESCRIPTION
		Sends the full schema context together with sample data rows (queried
		from the database) to the 'schema-analysis' AI purpose. The response
		contains detailed, actionable per-table generation instructions that
		are later injected into the batch-generation prompt so that even a
		small local model can produce realistic, relationship-aware data.

		This is the "smart tier" in the two-tier AI architecture:
		  1. schema-analysis (smart cloud model) → produces notes
		  2. batch-generation (local model)       → uses notes to generate rows
	#>
	[CmdletBinding()]
	param (
		[Parameter(Mandatory)]
		$SchemaModel,

		[int]$BaseRowCount = 100,

		[string]$Locale,

		## Active connection info — used to query sample data
		$ConnectionInfo,

		## Database provider object (has FunctionMap.ReadData)
		$Provider,

		[int]$SampleRows = 5
	)

	$aiProvider = Get-PSFConfigValue -FullName 'SqlLabDataGenerator.AI.Provider'
	if ($aiProvider -eq 'None') {
		Write-PSFMessage -Level Verbose -String 'AI.SchemaAnalysisSkipped'
		return $null
	}

	if (-not $Locale) {
		$Locale = Get-PSFConfigValue -FullName 'SqlLabDataGenerator.Generation.Locale'
	}

	# ── Build schema description with sample data ──
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

		$tableText = "TABLE: $($table.FullName) ($($table.ColumnCount) columns)`n$($colLines -join "`n")"

		# Query sample data if connection is available
		if ($ConnectionInfo -and $Provider -and $Provider.FunctionMap.ReadData) {
			try {
				$sampleData = & $Provider.FunctionMap.ReadData -ConnectionInfo $ConnectionInfo `
					-SchemaName $table.SchemaName -TableName $table.TableName -TopN $SampleRows

				if ($sampleData -and $sampleData.Rows.Count -gt 0) {
					$sampleLines = foreach ($row in $sampleData.Rows) {
						$vals = foreach ($dtCol in $sampleData.Columns) {
							$v = $row[$dtCol.ColumnName]
							if ($v -is [DBNull]) { "$($dtCol.ColumnName)=NULL" }
							else {
								# Sanitize sample values to prevent prompt injection from DB content
								$sanitized = "$v" -replace '[\r\n]+', ' '
								$sanitized = $sanitized -replace '[^\p{L}\p{N}\s\.\-,;:()\[\]_/''"=<>+#&@]', ''
								if ($sanitized.Length -gt 100) { $sanitized = $sanitized.Substring(0, 100) + '...' }
								"$($dtCol.ColumnName)=$sanitized"
							}
						}
						"    { $($vals -join ', ') }"
					}
					$tableText += "`n  Sample data ($($sampleData.Rows.Count) rows):`n$($sampleLines -join "`n")"
				}
				else {
					$tableText += "`n  Sample data: (empty table)"
				}
			}
			catch {
				Write-PSFMessage -Level Verbose -String 'AI.SchemaAnalysisSampleFailed' -StringValues $table.FullName, $_
				$tableText += "`n  Sample data: (query failed)"
			}
		}

		$tableText
	}
	$schemaText = $schemaSummary -join "`n`n"

	$systemPrompt = Resolve-SldgPromptTemplate -Purpose 'schema-analysis' -Variables @{
		BaseRowCount = $BaseRowCount
		Locale       = $Locale
	}

	if (-not $systemPrompt) {
		Write-PSFMessage -Level Warning -String 'Prompt.ResolveFailed' -StringValues 'schema-analysis'
		return $null
	}

	$userMessage = "Analyze this schema with sample data and produce per-table generation notes:`n`n$schemaText"

	Write-PSFMessage -Level Verbose -Message ($script:strings.'AI.SchemaAnalysisRequesting' -f $SchemaModel.TableCount)

	$response = Invoke-SldgAIRequest -SystemPrompt $systemPrompt -UserMessage $userMessage -Purpose 'schema-analysis'

	if (-not $response) {
		Write-PSFMessage -Level Warning -String 'AI.SchemaAnalysisNoResponse'
		return $null
	}

	# Parse JSON response
	$jsonText = $response
	if ($jsonText -match '```(?:json)?\s*\n?([\s\S]*?)\n?```') {
		$jsonText = $Matches[1]
	}
	elseif ($jsonText -match '(\{[\s\S]*\})') {
		$jsonText = $Matches[1]
	}

	# Sanitize common AI JSON issues
	$jsonText = $jsonText -replace ',\s*"\.{2,}"', ''
	$jsonText = $jsonText -replace '"\.{2,}"\s*,?', ''
	$jsonText = $jsonText -replace '(?<=[\]\}]),\s*(?=[\]\}])', ''

	try {
		$parsed = $jsonText | ConvertFrom-Json -ErrorAction Stop

		if (-not $parsed.tableNotes) {
			Write-PSFMessage -Level Warning -Message ($script:strings.'AI.SchemaAnalysisFailed' -f 'AI response missing required "tableNotes" property')
			return $null
		}

		$notes = @{}
		foreach ($prop in $parsed.tableNotes.PSObject.Properties) {
			$notes[$prop.Name] = [string]$prop.Value
		}

		Write-PSFMessage -Level Verbose -Message ($script:strings.'AI.SchemaAnalysisReceived' -f $notes.Count)
		$notes
	}
	catch {
		Write-PSFMessage -Level Warning -Message ($script:strings.'AI.SchemaAnalysisFailed' -f $_)
		$null
	}
}
