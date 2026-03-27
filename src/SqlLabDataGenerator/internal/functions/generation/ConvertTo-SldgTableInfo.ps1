function ConvertTo-SldgTableInfo {
	<#
	.SYNOPSIS
		Converts a TablePlan object into a TableInfo PSCustomObject for the generation engine.
	.DESCRIPTION
		Builds the standardized TableInfo structure from a generation plan's TablePlan,
		cross-referencing table-level ForeignKeys to ensure column-level ForeignKey is set.
		Centralizes the table info construction that was previously duplicated across
		Invoke-SldgDataGeneration, Invoke-SldgParallelTableGeneration, and streaming paths.
	#>
	[CmdletBinding()]
	param (
		[Parameter(Mandatory)]
		$TablePlan
	)

	[PSCustomObject]@{
		SchemaName  = $TablePlan.SchemaName
		TableName   = $TablePlan.TableName
		FullName    = $TablePlan.FullName
		Columns     = foreach ($cp in $TablePlan.Columns) {
			# Cross-reference table-level ForeignKeys to ensure column-level ForeignKey is set
			$colFK = $cp.ForeignKey
			if (-not $colFK -and $TablePlan.ForeignKeys) {
				$matchedFK = $TablePlan.ForeignKeys | Where-Object { $_.ParentColumn -eq $cp.ColumnName } | Select-Object -First 1
				if ($matchedFK) {
					$colFK = [PSCustomObject]@{
						ReferencedSchema = $matchedFK.ReferencedSchema
						ReferencedTable  = $matchedFK.ReferencedTable
						ReferencedColumn = $matchedFK.ReferencedColumn
					}
				}
			}
			[PSCustomObject]@{
				ColumnName     = $cp.ColumnName
				DataType       = $cp.DataType
				SemanticType   = $cp.SemanticType
				IsIdentity     = [bool]$cp.IsIdentity
				IsComputed     = [bool]$cp.IsComputed
				IsPrimaryKey   = [bool]$cp.IsPrimaryKey
				IsUnique       = [bool]$cp.IsUnique
				IsNullable     = if ($null -ne $cp.IsNullable) { [bool]$cp.IsNullable } else { $true }
				MaxLength      = $cp.MaxLength
				ForeignKey     = $colFK
				SchemaHint     = $cp.SchemaHint
				Classification = [PSCustomObject]@{ SemanticType = $cp.SemanticType; IsPII = $cp.IsPII }
				GenerationRule = $cp.CustomRule
			}
		}
		ForeignKeys = $TablePlan.ForeignKeys
	}
}
