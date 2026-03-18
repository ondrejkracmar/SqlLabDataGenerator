function Invoke-SldgStreamingGeneration {
	<#
	.SYNOPSIS
		Generates and writes data in chunks to prevent out-of-memory for large tables.
	.DESCRIPTION
		Splits row generation into fixed-size chunks. Each chunk is generated as a
		DataTable, written to the database, and immediately disposed. This keeps
		memory usage proportional to the chunk size, not the total row count.

		Uniqueness tracking is maintained across all chunks via a shared tracker
		passed to New-SldgRowSet.
	#>
	[CmdletBinding()]
	param (
		[Parameter(Mandatory)]
		$TableInfo,

		[Parameter(Mandatory)]
		[int]$TotalRowCount,

		[Parameter(Mandatory)]
		[int]$ChunkSize,

		[hashtable]$GeneratorMap,

		[hashtable]$ForeignKeyValues,

		[hashtable]$TableRules,

		$ConnectionInfo,

		$Transaction,

		$WriteFunction,

		[int]$BatchSize = 1000,

		[switch]$NoInsert,

		[switch]$PassThru
	)

	$chunkCount = [math]::Ceiling($TotalRowCount / $ChunkSize)
	$insertedTotal = 0
	$allGeneratedValues = @{}
	$allDataTables = if ($PassThru) { [System.Collections.Generic.List[System.Data.DataTable]]::new() } else { $null }

	# Build shared uniqueness tracker so chunks don't collide
	$sharedTracker = @{}
	$pkColumns = @($TableInfo.Columns | Where-Object { $_.IsPrimaryKey -and -not $_.IsIdentity -and -not $_.IsComputed })
	$hasCompositePK = $pkColumns.Count -gt 1
	foreach ($col in $TableInfo.Columns) {
		if ($col.IsIdentity -or $col.IsComputed) { continue }
		if ($col.DataType -in @('timestamp', 'rowversion')) { continue }
		if ($col.IsUnique -or ($col.IsPrimaryKey -and -not $hasCompositePK -and -not $col.IsIdentity)) {
			$sharedTracker[$col.ColumnName] = [System.Collections.Generic.HashSet[string]]::new()
		}
	}
	if ($hasCompositePK) {
		$sharedTracker['__CompositePK__'] = [System.Collections.Generic.HashSet[string]]::new()
	}

	for ($chunk = 0; $chunk -lt $chunkCount; $chunk++) {
		$rowsInChunk = [math]::Min($ChunkSize, $TotalRowCount - ($chunk * $ChunkSize))

		Write-PSFMessage -Level Verbose -Message "Streaming chunk $($chunk + 1)/${chunkCount}: generating $rowsInChunk rows for $($TableInfo.FullName)"

		$rowSet = New-SldgRowSet -TableInfo $TableInfo -RowCount $rowsInChunk `
			-GeneratorMap $GeneratorMap -ForeignKeyValues $ForeignKeyValues `
			-TableRules $TableRules -SharedUniqueTracker $sharedTracker

		# Accumulate FK values for child tables
		foreach ($key in $rowSet.GeneratedValues.Keys) {
			if (-not $allGeneratedValues.ContainsKey($key)) {
				$allGeneratedValues[$key] = [System.Collections.Generic.List[object]]::new()
			}
			$allGeneratedValues[$key].AddRange($rowSet.GeneratedValues[$key])
		}

		# Write chunk to database
		if (-not $NoInsert -and $ConnectionInfo -and $WriteFunction) {
			$writeParams = @{
				ConnectionInfo = $ConnectionInfo
				SchemaName     = $TableInfo.SchemaName
				TableName      = $TableInfo.TableName
				Data           = $rowSet.DataTable
				BatchSize      = $BatchSize
			}
			if ($Transaction) { $writeParams['Transaction'] = $Transaction }
			$insertedTotal += & $WriteFunction @writeParams
		}
		else {
			$insertedTotal += $rowSet.RowCount
		}

		if ($PassThru) {
			$allDataTables.Add($rowSet.DataTable)
		}
		else {
			# Dispose DataTable to free memory — the whole point of streaming
			$rowSet.DataTable.Dispose()
		}
	}

	# Convert accumulated value lists to arrays
	$finalValues = @{}
	foreach ($key in $allGeneratedValues.Keys) {
		$finalValues[$key] = $allGeneratedValues[$key].ToArray()
	}

	[PSCustomObject]@{
		InsertedCount   = $insertedTotal
		GeneratedValues = $finalValues
		DataTables      = $allDataTables
	}
}
