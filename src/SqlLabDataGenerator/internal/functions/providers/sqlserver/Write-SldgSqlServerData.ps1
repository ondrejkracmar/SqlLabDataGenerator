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

		[System.Data.SqlClient.SqlTransaction]$Transaction
	)

	$conn = $ConnectionInfo.DbConnection
	$qualifiedName = Get-SldgSafeSqlName -SchemaName $SchemaName -TableName $TableName

	try {
		if ($IdentityInsert) {
			$cmd = $conn.CreateCommand()
			if ($Transaction) { $cmd.Transaction = $Transaction }
			$cmd.CommandText = "SET IDENTITY_INSERT $qualifiedName ON"
			try { [void]$cmd.ExecuteNonQuery() } finally { $cmd.Dispose() }
		}

		$bulkCopyOptions = [System.Data.SqlClient.SqlBulkCopyOptions]::Default
		if ($Transaction) {
			$bulkCopy = New-Object System.Data.SqlClient.SqlBulkCopy($conn, $bulkCopyOptions, $Transaction)
		}
		else {
			$bulkCopy = New-Object System.Data.SqlClient.SqlBulkCopy($conn)
		}
		$bulkCopy.DestinationTableName = $qualifiedName
		$bulkCopy.BatchSize = $BatchSize
		$bulkCopy.BulkCopyTimeout = 600

		foreach ($col in $Data.Columns) {
			[void]$bulkCopy.ColumnMappings.Add($col.ColumnName, $col.ColumnName)
		}

		$bulkCopy.WriteToServer($Data)
		$bulkCopy.Close()

		if ($IdentityInsert) {
			$cmd = $conn.CreateCommand()
			if ($Transaction) { $cmd.Transaction = $Transaction }
			$cmd.CommandText = "SET IDENTITY_INSERT $qualifiedName OFF"
			try { [void]$cmd.ExecuteNonQuery() } finally { $cmd.Dispose() }
		}

		Write-PSFMessage -Level Verbose -String 'Schema.SqlServer.Inserted' -StringValues $Data.Rows.Count, $qualifiedName
		$Data.Rows.Count
	}
	catch {
		# Ensure bulk copy resources are released on failure
		if ($bulkCopy) {
			try { $bulkCopy.Close() } catch { $null = $_ }
		}
		if ($IdentityInsert) {
			try {
				$cmd = $conn.CreateCommand()
				if ($Transaction) { $cmd.Transaction = $Transaction }
				$cmd.CommandText = "SET IDENTITY_INSERT $qualifiedName OFF"
				[void]$cmd.ExecuteNonQuery()
				$cmd.Dispose()
			}
			catch { $null = $_ }
		}
		Stop-PSFFunction -Message ($script:strings.'Generation.Failed' -f $SchemaName, $TableName, $_) -EnableException $true -ErrorRecord $_
	}
}
