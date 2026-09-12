function Get-SldgExistingUniqueValue {
	<#
	.SYNOPSIS
		Queries existing unique/PK values from a table to prevent duplicate generation.
	.DESCRIPTION
		For all unique and non-identity PK columns in a table, queries existing values
		from the database in a single batched query. Returns a hashtable of column→values
		arrays, or $null if no unique columns or no values found.
	#>
	[CmdletBinding()]
	param (
		[Parameter(Mandatory)]
		[SqlLabDataGenerator.TableInfo]$TableInfo,

		[Parameter(Mandatory)]
		[SqlLabDataGenerator.TablePlan]$TablePlan,

		[Parameter(Mandatory)]
		[SqlLabDataGenerator.Connection]$ConnectionInfo,

		[System.Data.Common.DbTransaction]$Transaction,

		[int]$UniqueQueryLimit = 5000,

		[int]$CommandTimeout = 30
	)

	$uniqueCols = @($TableInfo.Columns | Where-Object {
		($_.IsUnique -or ($_.IsPrimaryKey -and -not $_.IsIdentity -and -not $_.IsComputed)) -and
		-not $_.IsIdentity -and -not $_.IsComputed
	})

	if ($uniqueCols.Count -eq 0) { return $null }

	$existingUnique = @{}
	$dialect = $ConnectionInfo.GetDialect()
	$safeTbl = $dialect.QualifiedName($TablePlan.SchemaName, $TablePlan.TableName)
	$safeCols = @($uniqueCols | ForEach-Object { $dialect.QuoteIdentifier($_.ColumnName) })

	try {
		$uqCmd = $ConnectionInfo.DbConnection.CreateCommand()
		if ($Transaction) { $uqCmd.Transaction = $Transaction }
		$uqCmd.CommandText = $dialect.SelectLimited(($safeCols -join ', '), $safeTbl, $UniqueQueryLimit)
		$uqCmd.CommandTimeout = $CommandTimeout
		$uqReader = $uqCmd.ExecuteReader()

		$uqLists = @{}
		foreach ($col in $uniqueCols) { $uqLists[$col.ColumnName] = [System.Collections.Generic.List[object]]::new() }

		while ($uqReader.Read()) {
			foreach ($col in $uniqueCols) {
				$ordinal = $uqReader.GetOrdinal($col.ColumnName)
				if (-not $uqReader.IsDBNull($ordinal)) {
					$uqLists[$col.ColumnName].Add($uqReader.GetValue($ordinal))
				}
			}
		}
		$uqReader.Close()
		$uqReader.Dispose()
		$uqCmd.Dispose()

		foreach ($col in $uniqueCols) {
			if ($uqLists[$col.ColumnName].Count -gt 0) {
				$existingUnique[$col.ColumnName] = $uqLists[$col.ColumnName].ToArray()
			}
		}
	}
	catch {
		Write-PSFMessage -Level Verbose -Message ($script:strings.'Generation.UniqueQueryFailed' -f $TablePlan.FullName, $_)
	}

	if ($existingUnique.Count -eq 0) { return $null }
	$existingUnique
}
