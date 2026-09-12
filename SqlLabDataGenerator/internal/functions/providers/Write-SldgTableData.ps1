function Write-SldgTableData {
	<#
	.SYNOPSIS
		Inserts a DataTable of generated rows into a table on any supported engine.
	.DESCRIPTION
		Two strategies, chosen by the connection's dialect:

		- SQL Server: SqlBulkCopy over the session's SqlConnection - the fastest path, and
		  the one the module always used there. The type is resolved at run time from the
		  driver PSSqlRepository loaded, so this module still references no driver.
		- Everything else (SQLite, DuckDB, PostgreSQL, ...): multi-row parameterised INSERT
		  batches inside a transaction, sized so the parameter count stays under the
		  dialect's per-command limit.

		When a batch fails (typically a unique or check constraint) the rows of that batch are
		retried one by one and the violating rows are skipped with a warning, so one bad row
		never loses the whole table. Identity insert is switched on around the write when the
		caller asks for it and the dialect supports it.
	.PARAMETER ConnectionInfo
		The active SqlLabDataGenerator.Connection.
	.PARAMETER SchemaName
		Schema of the table (ignored by engines without schemas).
	.PARAMETER TableName
		The target table.
	.PARAMETER Data
		Rows to insert. Column names must match the table's columns.
	.PARAMETER BatchSize
		Rows per batch (bulk copy batch size, or rows per multi-row INSERT before the
		parameter cap applies).
	.PARAMETER IdentityInsert
		Write explicit values into identity/auto-increment columns where the engine allows it.
	.PARAMETER Transaction
		Optional DbTransaction to enlist in. Without one, non-bulk writes run in a local
		transaction that is committed at the end.
	.OUTPUTS
		System.Int32 - number of rows inserted.
	#>
	[OutputType([int])]
	[CmdletBinding()]
	param (
		[Parameter(Mandatory)]
		[SqlLabDataGenerator.Connection]$ConnectionInfo,

		[Parameter(Mandatory)]
		[string]$SchemaName,

		[Parameter(Mandatory)]
		[string]$TableName,

		[Parameter(Mandatory)]
		[System.Data.DataTable]$Data,

		[int]$BatchSize = 1000,

		[switch]$IdentityInsert,

		[System.Data.Common.DbTransaction]$Transaction
	)

	if ($Data.Rows.Count -eq 0 -or $Data.Columns.Count -eq 0) { return 0 }

	$conn = $ConnectionInfo.DbConnection
	$dialect = $ConnectionInfo.GetDialect()
	$qualifiedName = $dialect.QualifiedName($SchemaName, $TableName)
	$columnNames = @($Data.Columns | ForEach-Object { $_.ColumnName })
	$safeColumnList = ($columnNames | ForEach-Object { $dialect.QuoteIdentifier($_) }) -join ', '

	# Runs a statement outside the batch loop (identity insert toggles).
	$executeStatement = {
		param([string]$Sql)
		$cmd = $conn.CreateCommand()
		try {
			if ($Transaction) { $cmd.Transaction = $Transaction }
			$cmd.CommandText = $Sql
			[void]$cmd.ExecuteNonQuery()
		}
		finally { $cmd.Dispose() }
	}

	# Inserts a single row; returns $true when it went in, $false when the engine rejected it.
	$insertSingleRow = {
		param([System.Data.DataRow]$Row, [System.Data.Common.DbTransaction]$ActiveTransaction)
		$cmd = $conn.CreateCommand()
		try {
			if ($ActiveTransaction) { $cmd.Transaction = $ActiveTransaction }
			$ci = 0
			$paramNames = foreach ($colName in $columnNames) {
				$p = $cmd.CreateParameter()
				$p.ParameterName = $dialect.ParameterName("p_$ci")
				$value = $Row[$colName]
				$p.Value = if ($value -is [DBNull] -or $null -eq $value) { [DBNull]::Value } else { $value }
				[void]$cmd.Parameters.Add($p)
				$dialect.ParameterPlaceholder("p_$ci")
				$ci++
			}
			$cmd.CommandText = "INSERT INTO $qualifiedName ($safeColumnList) VALUES ($($paramNames -join ', '))"
			[void]$cmd.ExecuteNonQuery()
			$true
		}
		catch {
			Write-PSFMessage -Level Debug -String 'Write.RowRejected' -StringValues $qualifiedName, $_.Exception.Message
			$false
		}
		finally { $cmd.Dispose() }
	}

	$identityOn = $IdentityInsert -and $dialect.SupportsIdentityInsert
	if ($IdentityInsert -and -not $dialect.SupportsIdentityInsert) {
		Write-PSFMessage -Level Verbose -String 'Write.IdentityInsertUnsupported' -StringValues $dialect.Name, $qualifiedName
	}

	$insertedCount = 0
	$skippedCount = 0
	$localTransaction = $null

	try {
		if ($identityOn) { & $executeStatement -Sql $dialect.IdentityInsertStatement($qualifiedName, $true) }

		#region SQL Server bulk copy
		$bulkCopyType = if ($dialect.SupportsBulkCopy) { $conn.GetType().Assembly.GetType('Microsoft.Data.SqlClient.SqlBulkCopy', $false) } else { $null }
		if ($bulkCopyType) {
			$bulkCopy = $null
			try {
				# SqlBulkCopy ignores source values for identity columns unless KeepIdentity is
				# set - SET IDENTITY_INSERT alone does not reach the bulk path. Without it a
				# masking round (delete + re-insert) renumbers every key and orphans the children.
				$optionsType = $conn.GetType().Assembly.GetType('Microsoft.Data.SqlClient.SqlBulkCopyOptions', $true)
				$optionValue = if ($identityOn) { [int][System.Enum]::Parse($optionsType, 'KeepIdentity') } else { 0 }
				$options = [System.Enum]::ToObject($optionsType, $optionValue)
				$bulkCopy = if ($Transaction) {
					[System.Activator]::CreateInstance($bulkCopyType, @($conn, $options, $Transaction))
				}
				else {
					[System.Activator]::CreateInstance($bulkCopyType, @($conn, $options, $null))
				}
				$bulkCopy.DestinationTableName = $qualifiedName
				$bulkCopy.BatchSize = $BatchSize
				$bulkCopy.BulkCopyTimeout = Get-PSFConfigValue -FullName 'SqlLabDataGenerator.Database.BulkCopyTimeout' -Fallback 600
				foreach ($colName in $columnNames) { [void]$bulkCopy.ColumnMappings.Add($colName, $colName) }
				$bulkCopy.WriteToServer($Data)
				$insertedCount = $Data.Rows.Count
				Write-PSFMessage -Level Verbose -String 'Schema.SqlServer.Inserted' -StringValues $insertedCount, $qualifiedName
				return $insertedCount
			}
			catch {
				# Row-by-row fallback: a single bad row (unique/check violation) must not lose the table.
				Write-PSFMessage -Level Warning -String 'Generation.BulkCopyFallback' -StringValues $qualifiedName, $_.Exception.Message
				foreach ($row in $Data.Rows) {
					if (& $insertSingleRow -Row $row -ActiveTransaction $Transaction) { $insertedCount++ } else { $skippedCount++ }
				}
				if ($skippedCount -gt 0) { Write-PSFMessage -Level Warning -String 'Generation.RowsSkipped' -StringValues $skippedCount, $qualifiedName }
				Write-PSFMessage -Level Verbose -String 'Schema.SqlServer.Inserted' -StringValues $insertedCount, $qualifiedName
				return $insertedCount
			}
			finally {
				if ($bulkCopy) { try { $bulkCopy.Dispose() } catch { Write-PSFMessage -Level Verbose -String 'Write.BulkCopyDisposeFailed' -StringValues $_.Exception.Message } }
			}
		}
		#endregion SQL Server bulk copy

		#region Multi-row parameterised INSERT
		$activeTransaction = $Transaction
		if (-not $activeTransaction) {
			$localTransaction = $conn.BeginTransaction()
			$activeTransaction = $localTransaction
		}

		$maxRowsPerBatch = [math]::Max(1, [math]::Floor($dialect.MaxParametersPerCommand / [math]::Max($columnNames.Count, 1)))
		$effectiveBatchSize = [math]::Max(1, [math]::Min($BatchSize, $maxRowsPerBatch))
		$totalRows = $Data.Rows.Count
		$rowIndex = 0

		while ($rowIndex -lt $totalRows) {
			$currentBatchSize = [math]::Min($effectiveBatchSize, $totalRows - $rowIndex)
			$cmd = $conn.CreateCommand()
			try {
				$cmd.Transaction = $activeTransaction
				$valueClauses = [System.Collections.Generic.List[string]]::new()
				for ($b = 0; $b -lt $currentBatchSize; $b++) {
					$row = $Data.Rows[$rowIndex + $b]
					$ci = 0
					$paramNames = foreach ($colName in $columnNames) {
						$p = $cmd.CreateParameter()
						$p.ParameterName = $dialect.ParameterName("p${b}_$ci")
						$value = $row[$colName]
						$p.Value = if ($value -is [DBNull] -or $null -eq $value) { [DBNull]::Value } else { $value }
						[void]$cmd.Parameters.Add($p)
						$dialect.ParameterPlaceholder("p${b}_$ci")
						$ci++
					}
					$valueClauses.Add("($($paramNames -join ', '))")
				}
				$cmd.CommandText = "INSERT INTO $qualifiedName ($safeColumnList) VALUES $($valueClauses -join ', ')"

				$affected = $cmd.ExecuteNonQuery()
				if ($affected -lt 0) { $affected = $currentBatchSize }   # drivers that cannot report the count
				$insertedCount += $affected
			}
			catch {
				# The whole batch was rejected; retry its rows individually so only the
				# offending ones are lost. A failed statement leaves SQLite/DuckDB transactions
				# usable; SQL Server never reaches this branch (bulk copy above).
				Write-PSFMessage -Level Warning -String 'Write.BatchFallback' -StringValues $qualifiedName, $currentBatchSize, $_.Exception.Message
				for ($b = 0; $b -lt $currentBatchSize; $b++) {
					if (& $insertSingleRow -Row $Data.Rows[$rowIndex + $b] -ActiveTransaction $activeTransaction) { $insertedCount++ } else { $skippedCount++ }
				}
			}
			finally { $cmd.Dispose() }
			$rowIndex += $currentBatchSize
		}

		if ($localTransaction) { $localTransaction.Commit(); $localTransaction = $null }
		#endregion Multi-row parameterised INSERT

		if ($skippedCount -gt 0) { Write-PSFMessage -Level Warning -String 'Generation.RowsSkipped' -StringValues $skippedCount, $qualifiedName }
		Write-PSFMessage -Level Verbose -String 'Schema.SqlServer.Inserted' -StringValues $insertedCount, $qualifiedName
		$insertedCount
	}
	catch {
		if ($localTransaction) {
			try { $localTransaction.Rollback() } catch { Write-PSFMessage -Level Warning -String 'Write.RollbackFailed' -StringValues $_.Exception.Message }
		}
		Stop-PSFFunction -Message $_.Exception.Message -ErrorRecord $_ -EnableException $true
		return
	}
	finally {
		if ($localTransaction) { try { $localTransaction.Dispose() } catch { $null = $_ } }
		if ($identityOn) {
			try { & $executeStatement -Sql $dialect.IdentityInsertStatement($qualifiedName, $false) }
			catch { Write-PSFMessage -Level Verbose -String 'Write.IdentityInsertOffFailed' -StringValues $_.Exception.Message }
		}
	}
}
