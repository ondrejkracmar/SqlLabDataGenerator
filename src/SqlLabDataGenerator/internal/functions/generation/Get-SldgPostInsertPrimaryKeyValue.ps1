function Get-SldgPostInsertPrimaryKeyValue {
	<#
	.SYNOPSIS
		Collects post-insert PK/Unique column values so child tables can reference them.
	.DESCRIPTION
		Extracted from Invoke-SldgDataGeneration. After a parent table is inserted, identity
		columns and other DB-generated values are not in the in-memory DataTable. Child
		tables that reference them via FK need real values. This function queries the DB
		for distinct PK/Unique values and returns a hashtable of { 'schema.table.column' => values[] }
		that the caller merges into its $fkValues map.
	.OUTPUTS
		Hashtable; empty if nothing collected. Errors are logged and swallowed.
	#>
	[CmdletBinding()]
	[OutputType([hashtable])]
	param (
		[Parameter(Mandatory)]
		$TablePlan,

		[Parameter(Mandatory)]
		[hashtable]$ExistingFkValues,

		[Parameter(Mandatory)]
		$ConnectionInfo,

		[System.Data.Common.DbTransaction]$Transaction,

		[int]$FkQueryLimit = 1000,

		[int]$CommandTimeout = 30
	)

	$collected = @{}

	foreach ($col in $TablePlan.Columns) {
		if (-not $col.IsPrimaryKey -and -not $col.IsUnique) { continue }

		$colKey = "$($TablePlan.SchemaName).$($TablePlan.TableName).$($col.ColumnName)"
		# Skip if values already known from the in-memory generated row set
		if ($ExistingFkValues.ContainsKey($colKey) -and $ExistingFkValues[$colKey].Count -gt 0) { continue }

		try {
			$safeTbl = Get-SldgSafeSqlName -SchemaName $TablePlan.SchemaName -TableName $TablePlan.TableName
			$safeCol = Get-SldgSafeSqlName -ColumnName $col.ColumnName
			$pkCmd = $ConnectionInfo.DbConnection.CreateCommand()
			if ($Transaction) { $pkCmd.Transaction = $Transaction }
			$pkCmd.CommandText = "SELECT DISTINCT TOP ($FkQueryLimit) $safeCol FROM $safeTbl"
			$pkCmd.CommandTimeout = $CommandTimeout
			$pkReader = $pkCmd.ExecuteReader()
			$pkVals = [System.Collections.Generic.List[object]]::new()
			while ($pkReader.Read()) {
				$pkv = $pkReader.GetValue(0)
				if ($pkv -isnot [DBNull]) { $pkVals.Add($pkv) }
			}
			$pkReader.Close()
			$pkReader.Dispose()
			$pkCmd.Dispose()

			if ($pkVals.Count -gt 0) {
				$collected[$colKey] = $pkVals.ToArray()
				Write-PSFMessage -Level Verbose -Message ($script:strings.'Generation.PostInsertPKCollected' -f $colKey, $pkVals.Count)
			}
		}
		catch {
			Write-PSFMessage -Level Verbose -Message ($script:strings.'Generation.PostInsertPKFailed' -f $colKey, $_)
		}
	}

	$collected
}
