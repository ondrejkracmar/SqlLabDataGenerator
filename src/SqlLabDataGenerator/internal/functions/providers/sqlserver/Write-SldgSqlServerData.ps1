function Write-SldgSqlServerData {
	<#
	.SYNOPSIS
		Writes generated data to a SQL Server table using SqlBulkCopy.
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

		[switch]$IdentityInsert,

		[Microsoft.Data.SqlClient.SqlTransaction]$Transaction
	)

	$conn = $ConnectionInfo.DbConnection
	$qualifiedName = Get-SldgSafeSqlName -SchemaName $SchemaName -TableName $TableName
	$bulkCopy = $null

	try {
		if ($IdentityInsert) {
			$cmd = $conn.CreateCommand()
			if ($Transaction) { $cmd.Transaction = $Transaction }
			$cmd.CommandText = "SET IDENTITY_INSERT $qualifiedName ON"
			try { [void]$cmd.ExecuteNonQuery() } finally { $cmd.Dispose() }
		}

		$bulkCopyOptions = [Microsoft.Data.SqlClient.SqlBulkCopyOptions]::Default
		if ($Transaction) {
			$bulkCopy = New-Object Microsoft.Data.SqlClient.SqlBulkCopy($conn, $bulkCopyOptions, $Transaction)
		}
		else {
			$bulkCopy = New-Object Microsoft.Data.SqlClient.SqlBulkCopy($conn)
		}
		$bulkCopy.DestinationTableName = $qualifiedName
		$bulkCopy.BatchSize = $BatchSize
		$bulkCopy.BulkCopyTimeout = Get-PSFConfigValue -FullName 'SqlLabDataGenerator.Database.BulkCopyTimeout'

		foreach ($col in $Data.Columns) {
			[void]$bulkCopy.ColumnMappings.Add($col.ColumnName, $col.ColumnName)
		}

		$bulkCopy.WriteToServer($Data)
		$bulkCopy.Dispose()
		$bulkCopy = $null

		if ($IdentityInsert) {
			$cmd = $conn.CreateCommand()
			if ($Transaction) { $cmd.Transaction = $Transaction }
			$cmd.CommandText = "SET IDENTITY_INSERT $qualifiedName OFF"
			try { [void]$cmd.ExecuteNonQuery() } finally { $cmd.Dispose() }
		}

		Write-PSFMessage -Level Verbose -Message ($script:strings.'Schema.SqlServer.Inserted' -f $Data.Rows.Count, $qualifiedName)
		$Data.Rows.Count
	}
	catch {
		# Ensure bulk copy resources are released on failure
		if ($bulkCopy) {
			try { $bulkCopy.Dispose() } catch { Write-PSFMessage -Level Verbose -Message ($script:strings.'Write.BulkCopyDisposeFailed' -f $_) }
			$bulkCopy = $null
		}

		# Row-by-row fallback: if BulkCopy failed (e.g. unique constraint), insert rows individually and skip failures
		Write-PSFMessage -Level Warning -Message ($script:strings.'Generation.BulkCopyFallback' -f $qualifiedName, $_)
		$insertedCount = 0
		$skippedCount = 0
		$safeColNames = ($Data.Columns | ForEach-Object { Get-SldgSafeSqlName -ColumnName $_.ColumnName })
		$colList = $safeColNames -join ', '
		$colIndex = 0
		$paramList = ($Data.Columns | ForEach-Object { "@p_$($colIndex)"; $colIndex++ }) -join ', '

		foreach ($row in $Data.Rows) {
			$cmd = $null
			try {
				$cmd = $conn.CreateCommand()
				if ($Transaction) { $cmd.Transaction = $Transaction }
				$cmd.CommandText = "INSERT INTO $qualifiedName ($colList) VALUES ($paramList)"
				$ci = 0
				foreach ($col in $Data.Columns) {
					$val = $row[$col.ColumnName]
					$p = $cmd.CreateParameter()
					$p.ParameterName = "@p_$ci"
					$p.Value = if ($val -is [DBNull] -or $null -eq $val) { [DBNull]::Value } else { $val }
					[void]$cmd.Parameters.Add($p)
					$ci++
				}
				[void]$cmd.ExecuteNonQuery()
				$insertedCount++
			}
			catch {
				$skippedCount++
			}
			finally {
				if ($cmd) { try { $cmd.Dispose() } catch { $null = $_ } }
			}
		}

		if ($skippedCount -gt 0) {
			Write-PSFMessage -Level Warning -Message ($script:strings.'Generation.RowsSkipped' -f $skippedCount, $qualifiedName)
		}

		# Ensure IDENTITY_INSERT is turned off even after fallback
		if ($IdentityInsert) {
			$cmd = $null
			try {
				$cmd = $conn.CreateCommand()
				if ($Transaction) { $cmd.Transaction = $Transaction }
				$cmd.CommandText = "SET IDENTITY_INSERT $qualifiedName OFF"
				[void]$cmd.ExecuteNonQuery()
			}
			catch { Write-PSFMessage -Level Verbose -Message ($script:strings.'Write.IdentityInsertOffFailed' -f $_) }
			finally { if ($cmd) { try { $cmd.Dispose() } catch { $null = $_ } } }
		}

		Write-PSFMessage -Level Verbose -Message ($script:strings.'Schema.SqlServer.Inserted' -f $insertedCount, $qualifiedName)
		$insertedCount
	}
}
