function Test-SldgForeignKeyIntegrity {
	<#
	.SYNOPSIS
		Validates foreign key referential integrity in generated data.
	#>
	[CmdletBinding()]
	param (
		[Parameter(Mandatory)]
		$ConnectionInfo,

		[Parameter(Mandatory)]
		$SchemaModel
	)

	$results = [System.Collections.Generic.List[object]]::new()

	foreach ($table in $SchemaModel.Tables) {
		foreach ($fk in $table.ForeignKeys) {
			Write-PSFMessage -Level Verbose -Message ($script:strings.'Validation.FKCheck' -f $table.SchemaName, $table.TableName)

			$parentName = Get-SldgSafeSqlName -SchemaName $table.SchemaName -TableName $table.TableName
			$parentCol = Get-SldgSafeSqlName -ColumnName $fk.ParentColumn
			$refName = Get-SldgSafeSqlName -SchemaName $fk.ReferencedSchema -TableName $fk.ReferencedTable
			$refCol = Get-SldgSafeSqlName -ColumnName $fk.ReferencedColumn

			$query = @"
SELECT COUNT(*) AS OrphanCount
FROM $parentName child
WHERE child.$parentCol IS NOT NULL
  AND NOT EXISTS (
    SELECT 1 FROM $refName parent
    WHERE parent.$refCol = child.$parentCol
  )
"@

			$conn = $ConnectionInfo.DbConnection
			$cmd = $conn.CreateCommand()
			$cmd.CommandText = $query
			$cmd.CommandTimeout = 120
			try {
				$orphanCount = $cmd.ExecuteScalar()
			}
			finally {
				$cmd.Dispose()
			}

			$passed = $orphanCount -eq 0
			$results.Add([SqlLabDataGenerator.ValidationResult]@{
				CheckType        = 'ForeignKey'
				TableName        = $table.FullName
				ConstraintName   = $fk.ForeignKeyName
				Column           = $fk.ParentColumn
				ReferencedTable  = "$($fk.ReferencedSchema).$($fk.ReferencedTable)"
				ReferencedColumn = $fk.ReferencedColumn
				Passed           = $passed
				Severity         = if ($passed) { 'OK' } else { 'Error' }
				Details          = if ($passed) { 'All references valid' } else { "$orphanCount orphaned rows found" }
			})

			if (-not $passed) {
				Write-PSFMessage -Level Warning -Message ($script:strings.'Validation.FKViolation' -f $table.SchemaName, $table.TableName, $fk.ParentColumn, $fk.ReferencedSchema, $fk.ReferencedTable, $fk.ReferencedColumn, $orphanCount)
			}
		}
	}

	$results
}
