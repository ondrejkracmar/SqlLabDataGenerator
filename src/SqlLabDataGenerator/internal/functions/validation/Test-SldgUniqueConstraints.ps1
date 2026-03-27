function Test-SldgUniqueConstraints {
	<#
	.SYNOPSIS
		Validates unique constraints and primary key uniqueness in generated data.
	#>
	[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseSingularNouns', '', Justification = 'Name describes multiple constraints being tested')]
	[CmdletBinding()]
	param (
		[Parameter(Mandatory)]
		$ConnectionInfo,

		[Parameter(Mandatory)]
		$SchemaModel
	)

	$results = [System.Collections.Generic.List[object]]::new()
	$conn = $ConnectionInfo.DbConnection

	foreach ($table in $SchemaModel.Tables) {
		$uniqueCols = $table.Columns | Where-Object { $_.IsUnique -or $_.IsPrimaryKey }

		foreach ($col in $uniqueCols) {
			Write-PSFMessage -Level Verbose -Message ($script:strings.'Validation.UniqueCheck' -f $table.SchemaName, $table.TableName)

			$safeName = Get-SldgSafeSqlName -SchemaName $table.SchemaName -TableName $table.TableName
			$safeCol = Get-SldgSafeSqlName -ColumnName $col.ColumnName

			$query = @"
SELECT $safeCol, COUNT(*) AS DuplicateCount
FROM $safeName
WHERE $safeCol IS NOT NULL
GROUP BY $safeCol
HAVING COUNT(*) > 1
"@

			$cmd = $conn.CreateCommand()
			$cmd.CommandText = $query
			$cmd.CommandTimeout = Get-PSFConfigValue -FullName 'SqlLabDataGenerator.Database.SchemaTimeout'
			$dt = New-Object System.Data.DataTable
			try {
				$reader = $cmd.ExecuteReader()
				$dt.Load($reader)
			}
			finally {
				if ($reader) { $reader.Close(); $reader.Dispose() }
				$cmd.Dispose()
			}

			$passed = $dt.Rows.Count -eq 0
			$duplicateCount = ($dt.Rows | Measure-Object -Property DuplicateCount -Sum).Sum

			$results.Add([SqlLabDataGenerator.ValidationResult]@{
				CheckType      = if ($col.IsPrimaryKey) { 'PrimaryKey' } else { 'UniqueConstraint' }
				TableName      = $table.FullName
				ConstraintName = "$($col.ColumnName)_Unique"
				Column         = $col.ColumnName
				ReferencedTable  = $null
				ReferencedColumn = $null
				Passed         = $passed
				Severity       = if ($passed) { 'OK' } else { 'Error' }
				Details        = if ($passed) { 'All values unique' } else { "$duplicateCount duplicate values across $($dt.Rows.Count) distinct values" }
			})

			if (-not $passed) {
				Write-PSFMessage -Level Warning -Message ($script:strings.'Validation.UniqueViolation' -f $table.SchemaName, $table.TableName, $col.ColumnName, $duplicateCount)
			}
		}
	}

	$results
}
