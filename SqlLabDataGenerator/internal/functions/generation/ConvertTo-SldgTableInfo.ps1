function ConvertTo-SldgTableInfo {
	<#
	.SYNOPSIS
		Converts a TablePlan back into the TableInfo shape the generation engine works on.
	.DESCRIPTION
		Builds a SqlLabDataGenerator.TableInfo from a generation plan's TablePlan, including
		column-level ForeignKey references cross-referenced from the table-level ForeignKeys
		when the plan column carries none. The result is what New-SldgRowSet, the FK
		resolvers and the post-insert validators expect, so a plan can be executed and
		validated without the original SchemaModel.
	.PARAMETER TablePlan
		The plan table to convert.
	#>
	[OutputType([SqlLabDataGenerator.TableInfo])]
	[CmdletBinding()]
	param (
		[Parameter(Mandatory)]
		[SqlLabDataGenerator.TablePlan]$TablePlan
	)

	$columns = foreach ($cp in $TablePlan.Columns) {
		# Cross-reference table-level ForeignKeys to ensure column-level ForeignKey is set
		$colFK = $cp.ForeignKey
		if (-not $colFK -and $TablePlan.ForeignKeys) {
			$matchedFK = $TablePlan.ForeignKeys | Where-Object { $_.ParentColumn -eq $cp.ColumnName } | Select-Object -First 1
			if ($matchedFK) {
				$colFK = [SqlLabDataGenerator.ForeignKeyRef]@{
					ForeignKeyName   = $matchedFK.ForeignKeyName
					ReferencedSchema = $matchedFK.ReferencedSchema
					ReferencedTable  = $matchedFK.ReferencedTable
					ReferencedColumn = $matchedFK.ReferencedColumn
				}
			}
		}
		[SqlLabDataGenerator.ColumnInfo]@{
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
			CheckConstraints = @($cp.CheckConstraints)
			Classification = [SqlLabDataGenerator.ColumnClassification]@{ ColumnName = $cp.ColumnName; TableName = $TablePlan.FullName; SemanticType = $cp.SemanticType; IsPII = [bool]$cp.IsPII }
			GenerationRule = $cp.CustomRule
		}
	}

	$foreignKeys = foreach ($fk in @($TablePlan.ForeignKeys)) {
		if ($null -eq $fk) { continue }
		if ($fk -is [SqlLabDataGenerator.ForeignKeyInfo]) { $fk; continue }
		[SqlLabDataGenerator.ForeignKeyInfo]@{
			ForeignKeyName   = $fk.ForeignKeyName
			ParentSchema     = if ($fk.PSObject.Properties['ParentSchema']) { $fk.ParentSchema } else { $TablePlan.SchemaName }
			ParentTable      = if ($fk.PSObject.Properties['ParentTable']) { $fk.ParentTable } else { $TablePlan.TableName }
			ParentColumn     = $fk.ParentColumn
			ReferencedSchema = $fk.ReferencedSchema
			ReferencedTable  = $fk.ReferencedTable
			ReferencedColumn = $fk.ReferencedColumn
		}
	}

	[SqlLabDataGenerator.TableInfo]@{
		SchemaName  = $TablePlan.SchemaName
		TableName   = $TablePlan.TableName
		FullName    = $TablePlan.FullName
		Columns     = @($columns)
		ForeignKeys = @($foreignKeys)
		ColumnCount = @($columns).Count
	}
}
