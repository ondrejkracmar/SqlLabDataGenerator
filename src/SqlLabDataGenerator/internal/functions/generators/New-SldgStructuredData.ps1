function New-SldgStructuredData {
	<#
	.SYNOPSIS
		Generates JSON or XML structured data for columns.
	.DESCRIPTION
		When AI is configured and enabled, sends the column context (table name, column name,
		optional schema hint from views) to AI to infer the expected structure and generate
		realistic content. Falls back to static templates when AI is unavailable.

		Schema hints can come from:
		- View definitions that reference the underlying column (AI can infer structure)
		- Column/table naming conventions
		- Explicit AIGenerationHint on the column

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

		[int]$Count = 1
	)

	$aiProvider = Get-PSFConfigValue -FullName 'SqlLabDataGenerator.AI.Provider'
	$useAI = Get-PSFConfigValue -FullName 'SqlLabDataGenerator.Generation.AIGeneration'

	for ($i = 0; $i -lt $Count; $i++) {
		$result = $null

		# Try AI generation when configured
		if ($useAI -and $aiProvider -ne 'None') {
			$result = New-SldgAIStructuredValue -Type $Type -ColumnName $ColumnName -TableName $TableName -SchemaHint $SchemaHint -MaxLength $MaxLength
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
