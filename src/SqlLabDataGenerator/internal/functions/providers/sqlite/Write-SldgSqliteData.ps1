function Write-SldgSqliteData {
	<#
	.SYNOPSIS
		Writes generated data to a SQLite table.
	#>
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

		[int]$BatchSize = 1000,

		$Transaction
	)

	$conn = $ConnectionInfo.Connection
	$insertedCount = 0

	if ($Data.Rows.Count -eq 0) { return 0 }

	# Build column list (excluding auto-increment)
	$columnNames = @()
	foreach ($col in $Data.Columns) {
		$columnNames += $col.ColumnName
	}

	if ($columnNames.Count -eq 0) { return 0 }

	$colList = ($columnNames | ForEach-Object { "[$_]" }) -join ', '
	$paramList = ($columnNames | ForEach-Object { "@p_$_" }) -join ', '
	$insertSql = "INSERT INTO [$TableName] ($colList) VALUES ($paramList)"

	# Use external transaction if provided, otherwise create a local one
	$localTransaction = $null
	$activeTransaction = $Transaction
	if (-not $activeTransaction) {
		$localTransaction = $conn.BeginTransaction()
		$activeTransaction = $localTransaction
	}

	try {
		foreach ($row in $Data.Rows) {
			$cmd = $conn.CreateCommand()
			$cmd.Transaction = $activeTransaction
			$cmd.CommandText = $insertSql

			foreach ($colName in $columnNames) {
				$value = $row[$colName]
				$param = $cmd.CreateParameter()
				$param.ParameterName = "@p_$colName"
				$param.Value = if ($value -is [DBNull] -or $null -eq $value) { [DBNull]::Value } else { $value }
				[void]$cmd.Parameters.Add($param)
			}

			[void]$cmd.ExecuteNonQuery()
			$cmd.Dispose()
			$insertedCount++
		}

		if ($localTransaction) { $localTransaction.Commit() }
	}
	catch {
		if ($localTransaction) { $localTransaction.Rollback() }
		throw
	}

	$insertedCount
}
