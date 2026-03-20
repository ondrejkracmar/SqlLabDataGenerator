function New-SldgStructuredData {
	<#
	.SYNOPSIS
		Generates JSON or XML structured data for columns.
	.DESCRIPTION
		When AI is configured and enabled, sends the column context (table name, column name,
		optional schema hint from views) to AI to infer the expected structure and generate
		realistic content. Falls back to static templates when AI is unavailable.

		Supports context-dependent generation: when ContextColumn and ContextValue are
		provided (e.g., ReportType = 'MailboxUsage'), AI generates structures that match
		the context, producing varied schemas per context value.

		For JSON: returns a valid JSON string.
		For XML: returns a valid XML string with a root element.
	#>
	[CmdletBinding()]
	param (
		[ValidateSet('Json', 'Xml')]
		[string]$Type = 'Json',

		[string]$ColumnName,

		[string]$TableName,

		[string]$SchemaHint,

		[int]$MaxLength = 4000,

		[int]$Count = 1,

		[string]$AIGenerationHint,

		[string]$ContextColumn,

		[string]$ContextValue,

		[string[]]$ValueExamples
	)

	$aiProvider = Get-PSFConfigValue -FullName 'SqlLabDataGenerator.AI.Provider'
	$useAI = Get-PSFConfigValue -FullName 'SqlLabDataGenerator.Generation.AIGeneration'

	for ($i = 0; $i -lt $Count; $i++) {
		$result = $null

		# Try AI generation when configured
		if ($useAI -and $aiProvider -ne 'None') {
			$aiParams = @{
				Type       = $Type
				ColumnName = $ColumnName
				TableName  = $TableName
				SchemaHint = $SchemaHint
				MaxLength  = $MaxLength
			}
			if ($AIGenerationHint) { $aiParams['AIGenerationHint'] = $AIGenerationHint }
			if ($ContextColumn) { $aiParams['ContextColumn'] = $ContextColumn }
			if ($ContextValue) { $aiParams['ContextValue'] = $ContextValue }
			if ($ValueExamples) { $aiParams['ValueExamples'] = $ValueExamples }
			$result = New-SldgAIStructuredValue @aiParams
		}

		# Static fallback
		if (-not $result) {
			$result = switch ($Type) {
				'Json' { New-SldgStaticJson -ColumnName $ColumnName -TableName $TableName -MaxLength $MaxLength }
				'Xml'  { New-SldgStaticXml -ColumnName $ColumnName -TableName $TableName -MaxLength $MaxLength }
			}
		}

		$result
	}
}
