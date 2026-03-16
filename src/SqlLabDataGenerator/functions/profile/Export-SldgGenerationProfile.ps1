function Export-SldgGenerationProfile {
	<#
	.SYNOPSIS
		Exports the current generation plan and rules to a JSON profile file.

	.DESCRIPTION
		Saves the generation plan configuration including table row counts,
		column semantic types, PII flags, and custom rules to a JSON file.
		This profile can be imported later for consistent data generation.

	.PARAMETER Plan
		The generation plan to export.

	.PARAMETER Path
		The file path to save the JSON profile.

	.PARAMETER IncludeSemanticAnalysis
		If specified, includes the full semantic analysis (types, PII flags) in the export.

	.EXAMPLE
		PS C:\> Export-SldgGenerationProfile -Plan $plan -Path 'C:\profiles\mydb.json'

		Exports the plan to a JSON file.
	#>
	[CmdletBinding()]
	param (
		[Parameter(Mandatory)]
		$Plan,

		[Parameter(Mandatory)]
		[string]$Path,

		[switch]$IncludeSemanticAnalysis
	)

	# Validate path is not traversing outside intended location
	$resolvedPath = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($Path)
	if ($resolvedPath -ne [System.IO.Path]::GetFullPath($resolvedPath)) {
		Stop-PSFFunction -Message "Invalid export path: $Path" -EnableException $true
	}

	Write-PSFMessage -Level Host -Message ($script:strings.'Profile.Exporting' -f $Path)

	$export = @{
		database  = $Plan.Database
		mode      = $Plan.Mode
		createdAt = (Get-Date -Format 'o')
		tables    = @{}
	}

	foreach ($tablePlan in $Plan.Tables) {
		$tableExport = @{
			rowCount = $tablePlan.RowCount
			order    = $tablePlan.Order
			columns  = @{}
		}

		foreach ($colPlan in $tablePlan.Columns) {
			if ($colPlan.Skip) { continue }

			$colExport = @{
				dataType     = $colPlan.DataType
				semanticType = $colPlan.SemanticType
				generator    = $colPlan.Generator
			}

			if ($IncludeSemanticAnalysis) {
				$colExport['isPII'] = $colPlan.IsPII
			}

			if ($colPlan.ForeignKey) {
				$colExport['foreignKey'] = @{
					referencedTable  = "$($colPlan.ForeignKey.ReferencedSchema).$($colPlan.ForeignKey.ReferencedTable)"
					referencedColumn = $colPlan.ForeignKey.ReferencedColumn
				}
			}

			# Include custom rules
			if ($colPlan.CustomRule) {
				if ($colPlan.CustomRule.ContainsKey('ValueList')) {
					$colExport['valueList'] = $colPlan.CustomRule.ValueList
				}
				if ($colPlan.CustomRule.ContainsKey('StaticValue')) {
					$colExport['staticValue'] = $colPlan.CustomRule.StaticValue
				}
				if ($colPlan.CustomRule.ContainsKey('Generator')) {
					$colExport['generator'] = $colPlan.CustomRule.Generator
				}
			}

			$tableExport.columns[$colPlan.ColumnName] = $colExport
		}

		$export.tables[$tablePlan.FullName] = $tableExport
	}

	$parentDir = Split-Path -Path $Path -Parent
	if ($parentDir -and -not (Test-Path $parentDir)) {
		$null = New-Item -Path $parentDir -ItemType Directory -Force
	}

	$export | ConvertTo-Json -Depth 10 | Set-Content -Path $Path -Encoding UTF8

	Write-PSFMessage -Level Host -Message "Profile exported to: $Path"
}
