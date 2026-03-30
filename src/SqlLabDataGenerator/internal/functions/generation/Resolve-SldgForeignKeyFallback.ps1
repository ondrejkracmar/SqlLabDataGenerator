function Resolve-SldgForeignKeyFallback {
	<#
	.SYNOPSIS
		Batch-loads missing FK parent values from the database.
	.DESCRIPTION
		For each FK column in a table plan where parent values are not yet in
		$FkValues, queries the database for distinct parent PK values. Groups
		queries by parent table to minimize round-trips.
	#>
	[CmdletBinding()]
	param (
		[Parameter(Mandatory)]
		$TablePlan,

		[Parameter(Mandatory)]
		[hashtable]$FkValues,

		[Parameter(Mandatory)]
		$ConnectionInfo,

		$Transaction,

		[int]$FkQueryLimit = 1000,

		[int]$CommandTimeout = 30
	)

	if (-not $TablePlan.ForeignKeys -or $TablePlan.ForeignKeys.Count -eq 0) { return }

	# Group FK columns by parent table to minimize database round-trips
	$fkByParent = @{}
	foreach ($fk in $TablePlan.ForeignKeys) {
		$refKey = "$($fk.ReferencedSchema).$($fk.ReferencedTable).$($fk.ReferencedColumn)"
		if (-not $FkValues.ContainsKey($refKey) -or $FkValues[$refKey].Count -eq 0) {
			$parentKey = "$($fk.ReferencedSchema).$($fk.ReferencedTable)"
			if (-not $fkByParent.ContainsKey($parentKey)) { $fkByParent[$parentKey] = @() }
			$fkByParent[$parentKey] += $fk
		}
	}

	foreach ($parentKey in $fkByParent.Keys) {
		$parentFks = $fkByParent[$parentKey]
		$firstFk = $parentFks[0]
		$safeRef = Get-SldgSafeSqlName -SchemaName $firstFk.ReferencedSchema -TableName $firstFk.ReferencedTable
		try {
			$safeCols = @($parentFks | ForEach-Object { Get-SldgSafeSqlName -ColumnName $_.ReferencedColumn } | Select-Object -Unique)
			$cmd = $ConnectionInfo.DbConnection.CreateCommand()
			if ($Transaction) { $cmd.Transaction = $Transaction }
			$cmd.CommandText = "SELECT DISTINCT TOP ($FkQueryLimit) $($safeCols -join ', ') FROM $safeRef ORDER BY $($safeCols -join ', ')"
			$cmd.CommandTimeout = $CommandTimeout
			$reader = $cmd.ExecuteReader()

			$colLists = @{}
			foreach ($fk in $parentFks) { $colLists[$fk.ReferencedColumn] = [System.Collections.Generic.List[object]]::new() }

			while ($reader.Read()) {
				foreach ($fk in $parentFks) {
					$ordinal = $reader.GetOrdinal($fk.ReferencedColumn)
					if (-not $reader.IsDBNull($ordinal)) {
						$colLists[$fk.ReferencedColumn].Add($reader.GetValue($ordinal))
					}
				}
			}
			$reader.Close()
			$reader.Dispose()
			$cmd.Dispose()

			foreach ($fk in $parentFks) {
				$refKey = "$($fk.ReferencedSchema).$($fk.ReferencedTable).$($fk.ReferencedColumn)"
				if ($colLists[$fk.ReferencedColumn].Count -gt 0) {
					$FkValues[$refKey] = $colLists[$fk.ReferencedColumn].ToArray()
					Write-PSFMessage -Level Verbose -Message ($script:strings.'Generation.FKFallbackLoaded' -f $refKey, $colLists[$fk.ReferencedColumn].Count)
				}
			}
		}
		catch {
			foreach ($fk in $parentFks) {
				$refKey = "$($fk.ReferencedSchema).$($fk.ReferencedTable).$($fk.ReferencedColumn)"
				Write-PSFMessage -Level Warning -Message ($script:strings.'Generation.FKFallbackFailed' -f $refKey, $_)
			}
		}
	}
}
