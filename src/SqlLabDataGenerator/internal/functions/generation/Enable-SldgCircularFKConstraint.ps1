function Enable-SldgCircularFKConstraint {
	<#
	.SYNOPSIS
		Re-enables FK constraints that were disabled for circular dependencies.
	.DESCRIPTION
		Must be called after data insertion to restore FK constraint checking.
		Returns a list of constraints that failed to re-enable (requires manual intervention).
	#>
	[CmdletBinding()]
	param (
		[Parameter(Mandatory)]
		$DisabledInfo,

		[Parameter(Mandatory)]
		$ConnectionInfo,

		$Transaction
	)

	$failures = [System.Collections.Generic.List[string]]::new()

	if ($DisabledInfo.DisabledTables.Count -eq 0) { return $failures }

	if ($ConnectionInfo.Provider -eq 'SQLite') {
		try {
			$fkCmd = $ConnectionInfo.DbConnection.CreateCommand()
			if ($Transaction) { $fkCmd.Transaction = $Transaction }
			$fkCmd.CommandText = "PRAGMA foreign_keys = ON"
			try { [void]$fkCmd.ExecuteNonQuery() } finally { $fkCmd.Dispose() }
			Write-PSFMessage -Level Verbose -Message ($script:strings.'Generation.FKReenabledPragma')
		}
		catch {
			Write-PSFMessage -Level Warning -Message ($script:strings.'Generation.FKReenablePragmaFailed' -f $_)
			$failures.Add("SQLite PRAGMA: $_")
		}
	}
	else {
		foreach ($entry in $DisabledInfo.DisabledConstraintNames) {
			$parts = $entry -split '\|', 2
			$tblFullName = $parts[0]
			$fkName = $parts[1]
			$ct = $DisabledInfo.DisabledTables | Where-Object { $_.FullName -eq $tblFullName } | Select-Object -First 1
			if (-not $ct) { continue }
			try {
				$fkCmd = $ConnectionInfo.DbConnection.CreateCommand()
				if ($Transaction) { $fkCmd.Transaction = $Transaction }
				$safeName = Get-SldgSafeSqlName -SchemaName $ct.SchemaName -TableName $ct.TableName
				$safeFKName = "[$($fkName -replace '\]', ']]')]"
				$fkCmd.CommandText = "ALTER TABLE $safeName WITH CHECK CHECK CONSTRAINT $safeFKName"
				try { [void]$fkCmd.ExecuteNonQuery() } finally { $fkCmd.Dispose() }
				Write-PSFMessage -Level Verbose -Message ($script:strings.'Generation.FKReenabledTable' -f "$tblFullName.$fkName")
			}
			catch {
				Write-PSFMessage -Level Warning -Message ($script:strings.'Generation.FKReenableTableFailed' -f "$tblFullName.$fkName", $_)
				$failures.Add("$tblFullName.$fkName")
			}
		}
	}

	$failures
}
