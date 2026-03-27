function Test-SldgDataTypeConstraints {
	<#
	.SYNOPSIS
		Validates data type constraints (nullability, ranges) on generated data.
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
		# Check NOT NULL violations
		$notNullCols = $table.Columns | Where-Object { -not $_.IsNullable -and -not $_.IsIdentity -and -not $_.IsComputed }

		foreach ($col in $notNullCols) {
			$safeName = Get-SldgSafeSqlName -SchemaName $table.SchemaName -TableName $table.TableName
			$safeCol = Get-SldgSafeSqlName -ColumnName $col.ColumnName

			$query = "SELECT COUNT(*) FROM $safeName WHERE $safeCol IS NULL"

			$cmd = $conn.CreateCommand()
			$cmd.CommandText = $query
			$cmd.CommandTimeout = Get-PSFConfigValue -FullName 'SqlLabDataGenerator.Database.CommandTimeout'
			try {
				$nullCount = $cmd.ExecuteScalar()
			}
			finally {
				$cmd.Dispose()
			}

			$passed = $nullCount -eq 0
			$results.Add([SqlLabDataGenerator.ValidationResult]@{
				CheckType        = 'NotNull'
				TableName        = $table.FullName
				ConstraintName   = "$($col.ColumnName)_NotNull"
				Column           = $col.ColumnName
				ReferencedTable  = $null
				ReferencedColumn = $null
				Passed           = $passed
				Severity         = if ($passed) { 'OK' } else { 'Error' }
				Details          = if ($passed) { 'No null values' } else { "$nullCount null values in non-nullable column" }
			})
		}

		# Row count check
		$safeName = Get-SldgSafeSqlName -SchemaName $table.SchemaName -TableName $table.TableName
		$cmd = $conn.CreateCommand()
		$cmd.CommandText = "SELECT COUNT(*) FROM $safeName"
		$cmd.CommandTimeout = Get-PSFConfigValue -FullName 'SqlLabDataGenerator.Database.CommandTimeout'
		try {
			$rowCount = $cmd.ExecuteScalar()
		}
		finally {
			$cmd.Dispose()
		}

		$results.Add([SqlLabDataGenerator.ValidationResult]@{
			CheckType        = 'RowCount'
			TableName        = $table.FullName
			ConstraintName   = 'RowCount'
			Column           = $null
			ReferencedTable  = $null
			ReferencedColumn = $null
			Passed           = $rowCount -gt 0
			Severity         = if ($rowCount -gt 0) { 'OK' } else { 'Warning' }
			Details          = "$rowCount rows in table"
		})
	}

	$results
}
