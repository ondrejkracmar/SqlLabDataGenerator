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
		$TableInfo,

		[Parameter(Mandatory)]
		$TablePlan,

		[Parameter(Mandatory)]
		$ConnectionInfo,

		$Transaction,

		[int]$UniqueQueryLimit = 5000,

		[int]$CommandTimeout = 30
	)

	$uniqueCols = @($TableInfo.Columns | Where-Object {
		($_.IsUnique -or ($_.IsPrimaryKey -and -not $_.IsIdentity -and -not $_.IsComputed)) -and
		-not $_.IsIdentity -and -not $_.IsComputed
	})

	if ($uniqueCols.Count -eq 0) { return $null }

	$existingUnique = @{}
	$isSQLite = $ConnectionInfo.Provider -eq 'SQLite'
	$safeTbl = Get-SldgSafeSqlName -SchemaName $TablePlan.SchemaName -TableName $TablePlan.TableName -SQLite:$isSQLite
	$safeCols = @($uniqueCols | ForEach-Object { Get-SldgSafeSqlName -ColumnName $_.ColumnName -SQLite:$isSQLite })

	try {
		$uqCmd = $ConnectionInfo.DbConnection.CreateCommand()
		if ($Transaction) { $uqCmd.Transaction = $Transaction }
		if ($isSQLite) {
			$uqCmd.CommandText = "SELECT $($safeCols -join ', ') FROM $safeTbl LIMIT $UniqueQueryLimit"
		} else {
			$uqCmd.CommandText = "SELECT TOP ($UniqueQueryLimit) $($safeCols -join ', ') FROM $safeTbl"
		}
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
