function Disable-SldgCircularFKConstraint {
	<#
	.SYNOPSIS
		Disables FK constraints for tables involved in circular dependencies.
	.DESCRIPTION
		Asks the connection's dialect how the engine can relax foreign keys:
		- per constraint (SQL Server: ALTER TABLE ... NOCHECK CONSTRAINT) - only the FKs
		  that form the cycle are disabled;
		- session-wide (SQLite PRAGMA foreign_keys, MySQL FOREIGN_KEY_CHECKS) - everything
		  is relaxed for the duration of the insert;
		- not at all (DuckDB, PostgreSQL through the ANSI dialect) - nothing is disabled
		  and the caller relies on insertion order; a warning says so.
		Returns tracking information needed for re-enabling after data insertion.
	#>
	[OutputType([SqlLabDataGenerator.DisabledForeignKeySet])]
	[CmdletBinding()]
	param (
		[Parameter(Mandatory)]
		[array]$CircularTables,

		[Parameter(Mandatory)]
		[SqlLabDataGenerator.Connection]$ConnectionInfo,

		[System.Data.Common.DbTransaction]$Transaction
	)

	$result = [SqlLabDataGenerator.DisabledForeignKeySet]::new()

	$dialect = $ConnectionInfo.GetDialect()

	$runStatement = {
		param([string]$Sql, [System.Data.Common.DbTransaction]$ActiveTransaction)
		$fkCmd = $ConnectionInfo.DbConnection.CreateCommand()
		try {
			if ($ActiveTransaction) { $fkCmd.Transaction = $ActiveTransaction }
			$fkCmd.CommandText = $Sql
			[void]$fkCmd.ExecuteNonQuery()
		}
		finally { $fkCmd.Dispose() }
	}

	$circularTableNames = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
	foreach ($ct in $CircularTables) { [void]$circularTableNames.Add($ct.FullName) }

	if ($dialect.DisableAllForeignKeysStatement) {
		try {
			& $runStatement -Sql $dialect.DisableAllForeignKeysStatement -ActiveTransaction $Transaction
			$result.DisabledTables.AddRange($CircularTables)
			$result.SessionWide = $true
			Write-PSFMessage -Level Verbose -String 'Generation.FKDisabledPragma' -StringValues $CircularTables.Count
		}
		catch {
			Write-PSFMessage -Level Warning -String 'Generation.FKDisablePragmaFailed' -StringValues $_.Exception.Message
		}
		return $result
	}

	if (-not $dialect.DisableForeignKeyStatement('x', 'y')) {
		Write-PSFMessage -Level Warning -String 'Generation.FKDisableUnsupported' -StringValues $dialect.Name, $CircularTables.Count
		return $result
	}

	foreach ($ct in $CircularTables) {
		$circularFKs = @($ct.ForeignKeys | Where-Object {
			$refFullName = "$($_.ReferencedSchema).$($_.ReferencedTable)"
			$circularTableNames.Contains($refFullName)
		})
		foreach ($fk in $circularFKs) {
			try {
				$safeName = $dialect.QualifiedName($ct.SchemaName, $ct.TableName)
				$safeFKName = $dialect.QuoteIdentifier($fk.ForeignKeyName)
				& $runStatement -Sql $dialect.DisableForeignKeyStatement($safeName, $safeFKName) -ActiveTransaction $Transaction
				$result.DisabledConstraintNames.Add("$($ct.FullName)|$($fk.ForeignKeyName)")
				Write-PSFMessage -Level Verbose -String 'Generation.FKDisabledTable' -StringValues "$($ct.FullName).$($fk.ForeignKeyName)"
			}
			catch {
				Write-PSFMessage -Level Warning -String 'Generation.FKDisableTableFailed' -StringValues "$($ct.FullName).$($fk.ForeignKeyName)", $_.Exception.Message
			}
		}
		if ($circularFKs.Count -gt 0) {
			$result.DisabledTables.Add($ct)
		}
	}

	$result
}
