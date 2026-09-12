function Enable-SldgCircularFKConstraint {
	<#
	.SYNOPSIS
		Re-enables FK constraints that were disabled for circular dependencies.
	.DESCRIPTION
		Must be called after data insertion to restore FK constraint checking. Mirrors
		Disable-SldgCircularFKConstraint: session-wide toggles are switched back on,
		per-constraint toggles are re-enabled one by one.
		Returns a list of constraints that failed to re-enable (requires manual intervention).
	#>
	[CmdletBinding()]
	param (
		[Parameter(Mandatory)]
		[SqlLabDataGenerator.DisabledForeignKeySet]$DisabledInfo,

		[Parameter(Mandatory)]
		[SqlLabDataGenerator.Connection]$ConnectionInfo,

		[System.Data.Common.DbTransaction]$Transaction
	)

	$failures = [System.Collections.Generic.List[string]]::new()

	if ($DisabledInfo.DisabledTables.Count -eq 0) { return $failures }

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

	$sessionWide = $DisabledInfo.SessionWide -or ($DisabledInfo.DisabledConstraintNames.Count -eq 0 -and $dialect.EnableAllForeignKeysStatement)
	if ($sessionWide -and $dialect.EnableAllForeignKeysStatement) {
		try {
			& $runStatement -Sql $dialect.EnableAllForeignKeysStatement -ActiveTransaction $Transaction
			Write-PSFMessage -Level Verbose -String 'Generation.FKReenabledPragma'
		}
		catch {
			Write-PSFMessage -Level Warning -String 'Generation.FKReenablePragmaFailed' -StringValues $_.Exception.Message
			$failures.Add("$($dialect.Name) session-wide foreign keys: $($_.Exception.Message)")
		}
		return $failures
	}

	foreach ($entry in $DisabledInfo.DisabledConstraintNames) {
		$parts = $entry -split '\|', 2
		$tblFullName = $parts[0]
		$fkName = $parts[1]
		$ct = $DisabledInfo.DisabledTables | Where-Object { $_.FullName -eq $tblFullName } | Select-Object -First 1
		if (-not $ct) { continue }
		try {
			$safeName = $dialect.QualifiedName($ct.SchemaName, $ct.TableName)
			$safeFKName = $dialect.QuoteIdentifier($fkName)
			& $runStatement -Sql $dialect.EnableForeignKeyStatement($safeName, $safeFKName) -ActiveTransaction $Transaction
			Write-PSFMessage -Level Verbose -String 'Generation.FKReenabledTable' -StringValues "$tblFullName.$fkName"
		}
		catch {
			Write-PSFMessage -Level Warning -String 'Generation.FKReenableTableFailed' -StringValues "$tblFullName.$fkName", $_.Exception.Message
			$failures.Add("$tblFullName.$fkName")
		}
	}

	$failures
}
