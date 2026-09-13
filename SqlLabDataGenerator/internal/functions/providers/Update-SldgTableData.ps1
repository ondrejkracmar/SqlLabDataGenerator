function Update-SldgTableData {
	<#
	.SYNOPSIS
		Writes changed column values back to existing rows, matched by primary key.
	.DESCRIPTION
		The write path of masking mode. Rows are updated in place - one parameterised
		UPDATE per row, all inside one transaction - so primary keys, identity values and
		every foreign key pointing at the table survive untouched. Only the columns named in
		-Column are written; the key columns are used in the WHERE clause only.

		Works on every engine: the dialect quotes the names and supplies the parameter
		placeholders, values travel as DbParameters.
	.PARAMETER ConnectionInfo
		The active SqlLabDataGenerator.Connection.
	.PARAMETER SchemaName
		Schema of the table (ignored by engines without schemas).
	.PARAMETER TableName
		The table to update.
	.PARAMETER Data
		The rows, including their key columns and the new values.
	.PARAMETER KeyColumn
		Primary-key column name(s) identifying each row.
	.PARAMETER Column
		The columns to write. Key columns are never written.
	.PARAMETER Transaction
		Optional DbTransaction to enlist in. Without one a local transaction is used.
	.OUTPUTS
		System.Int32 - number of rows updated.
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

		[Parameter(Mandatory)]
		[string[]]$KeyColumn,

		[Parameter(Mandatory)]
		[string[]]$Column,

		[System.Data.Common.DbTransaction]$Transaction
	)

	# Tables PSSqlRepository imported on connect are updated through their entity type, which
	# needs complete rows (EF copies every mapped property); the masking engine reads whole rows,
	# so this holds unless a caller passed a projection - then the SQL UPDATE below runs.
	$binding = Get-SldgEntityBinding -ConnectionInfo $ConnectionInfo -SchemaName $SchemaName -TableName $TableName
	if ($binding -and $KeyColumn.Count -eq 1 -and $KeyColumn[0] -eq $binding.KeyColumn) {
		$complete = @($binding.Columns | Where-Object { -not $Data.Columns.Contains($_.Name) }).Count -eq 0
		if ($complete) {
			$entityParams = @{ ConnectionInfo = $ConnectionInfo; Binding = $binding; Data = $Data }
			if ($Transaction) { $entityParams['Transaction'] = $Transaction }
			return (Update-SldgEntityData @entityParams)
		}
	}

	$targets = @($Column | Where-Object { $_ -notin $KeyColumn -and $Data.Columns.Contains($_) })
	if ($Data.Rows.Count -eq 0 -or $targets.Count -eq 0) { return 0 }
	foreach ($key in $KeyColumn) {
		if (-not $Data.Columns.Contains($key)) { throw "Key column '$key' is not present in the data for $SchemaName.$TableName." }
	}

	$conn = $ConnectionInfo.DbConnection
	$dialect = $ConnectionInfo.GetDialect()
	$qualifiedName = $dialect.QualifiedName($SchemaName, $TableName)

	$setParts = for ($n = 0; $n -lt $targets.Count; $n++) { "$($dialect.QuoteIdentifier($targets[$n])) = $($dialect.ParameterPlaceholder("v$n"))" }
	$whereParts = for ($n = 0; $n -lt $KeyColumn.Count; $n++) { "$($dialect.QuoteIdentifier($KeyColumn[$n])) = $($dialect.ParameterPlaceholder("k$n"))" }
	$setClause = $setParts -join ', '
	$whereClause = $whereParts -join ' AND '
	$sql = "UPDATE $qualifiedName SET $setClause WHERE $whereClause"

	$localTransaction = $null
	$activeTransaction = $Transaction
	if (-not $activeTransaction) {
		$localTransaction = $conn.BeginTransaction()
		$activeTransaction = $localTransaction
	}

	$updated = 0
	try {
		foreach ($row in $Data.Rows) {
			$cmd = $conn.CreateCommand()
			try {
				$cmd.Transaction = $activeTransaction
				$cmd.CommandText = $sql
				$i = 0
				foreach ($name in $targets) {
					$p = $cmd.CreateParameter()
					$p.ParameterName = $dialect.ParameterName("v$i")
					$value = $row[$name]
					$p.Value = if ($value -is [DBNull] -or $null -eq $value) { [DBNull]::Value } else { $value }
					[void]$cmd.Parameters.Add($p)
					$i++
				}
				$i = 0
				foreach ($name in $KeyColumn) {
					$p = $cmd.CreateParameter()
					$p.ParameterName = $dialect.ParameterName("k$i")
					$p.Value = $row[$name]
					[void]$cmd.Parameters.Add($p)
					$i++
				}
				$affected = $cmd.ExecuteNonQuery()
				$updated += if ($affected -lt 0) { 1 } else { $affected }
			}
			finally { $cmd.Dispose() }
		}

		if ($localTransaction) { $localTransaction.Commit(); $localTransaction = $null }
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
	}

	Write-PSFMessage -Level Verbose -String 'Write.RowsUpdated' -StringValues $updated, $qualifiedName
	$updated
}
