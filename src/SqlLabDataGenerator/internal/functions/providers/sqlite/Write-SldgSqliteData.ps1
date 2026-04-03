function Write-SldgSqliteData {
	<#
	.SYNOPSIS
		Writes generated data to a SQLite table using batched INSERT statements.
	.DESCRIPTION
		Uses a prepared statement with parameter reuse and multi-row INSERT batches
		to achieve high throughput. Handles 100K+ rows efficiently by avoiding
		per-row command creation overhead.
	#>
	[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSReviewUnusedParameter', 'SchemaName', Justification = 'Provider interface parameter')]
	[CmdletBinding()]
	param (
		[Parameter(Mandatory)]
		$ConnectionInfo,

		[Parameter(Mandatory)]
		[string]$SchemaName,

		[Parameter(Mandatory)]
		[string]$TableName,

		[Parameter(Mandatory)]
		[System.Data.DataTable]$Data,

		[int]$BatchSize = 500,

		$Transaction
	)

	$conn = $ConnectionInfo.DbConnection
	$insertedCount = 0

	if ($Data.Rows.Count -eq 0) { return 0 }

	# Build column list (excluding auto-increment)
	$columnNames = @()
	foreach ($col in $Data.Columns) {
		$columnNames += $col.ColumnName
	}

	if ($columnNames.Count -eq 0) { return 0 }

	$safeTableName = Get-SldgSafeSqlName -TableName $TableName -SQLite
	$safeColList = ($columnNames | ForEach-Object { Get-SldgSafeSqlName -ColumnName $_ }) -join ', '

	# SQLite has a limit of SQLITE_MAX_VARIABLE_NUMBER (default 999) parameters per statement.
	# This value can be higher in custom SQLite builds compiled with SQLITE_MAX_VARIABLE_NUMBER.
	$SQLITE_MAX_VARIABLES = 999
	$maxBatchRows = [math]::Max(1, [math]::Floor($SQLITE_MAX_VARIABLES / [math]::Max($columnNames.Count, 1)))
	$effectiveBatchSize = [math]::Min($BatchSize, $maxBatchRows)

	# Use external transaction if provided, otherwise create a local one
	$localTransaction = $null
	$activeTransaction = $Transaction
	if (-not $activeTransaction) {
		$localTransaction = $conn.BeginTransaction()
		$activeTransaction = $localTransaction
	}

	try {
		$totalRows = $Data.Rows.Count
		$rowIndex = 0

		while ($rowIndex -lt $totalRows) {
			$currentBatchSize = [math]::Min($effectiveBatchSize, $totalRows - $rowIndex)

			# Build multi-row INSERT: INSERT INTO [T] (cols) VALUES (row1), (row2), ...
			$valueClauses = [System.Collections.Generic.List[string]]::new()
			for ($b = 0; $b -lt $currentBatchSize; $b++) {
				$ci = 0
				$paramNames = ($columnNames | ForEach-Object { "@p${b}_$($ci)"; $ci++ }) -join ', '
				$valueClauses.Add("($paramNames)")
			}

			$cmd = $conn.CreateCommand()
			$cmd.Transaction = $activeTransaction
			$cmd.CommandText = "INSERT OR IGNORE INTO $safeTableName ($safeColList) VALUES $($valueClauses -join ', ')"

			# Bind parameters for all rows in this batch
			for ($b = 0; $b -lt $currentBatchSize; $b++) {
				$row = $Data.Rows[$rowIndex + $b]
				$ci = 0
				foreach ($colName in $columnNames) {
					$value = $row[$colName]
					$param = $cmd.CreateParameter()
					$param.ParameterName = "@p${b}_$($ci)"
					$ci++
					$param.Value = if ($value -is [DBNull] -or $null -eq $value) { [DBNull]::Value } else { $value }
					[void]$cmd.Parameters.Add($param)
				}
			}

			try {
				$affected = $cmd.ExecuteNonQuery()
			}
			finally {
				$cmd.Dispose()
			}
			# Handle drivers that return -1 (unknown) for affected rows
			if ($affected -lt 0) {
				$affected = $currentBatchSize  # assume all rows succeeded when driver can't report
			}
			# Detect silently ignored rows and warn the user
			$skippedRows = $currentBatchSize - $affected
			if ($skippedRows -gt 0) {
				Write-PSFMessage -Level Warning -Message ($script:strings.'Write.SQLiteConstraintViolations' -f $skippedRows, $currentBatchSize, $TableName)
			}
			$insertedCount += $affected
			$rowIndex += $currentBatchSize
		}

		if ($localTransaction) { $localTransaction.Commit() }
	}
	catch {
		if ($localTransaction) {
			try { $localTransaction.Rollback() } catch {
				Write-PSFMessage -Level Warning -Message ($script:strings.'Connect.SQLite.RollbackFailed' -f $_)
			}
		}
		throw
	}

	$insertedCount
}
