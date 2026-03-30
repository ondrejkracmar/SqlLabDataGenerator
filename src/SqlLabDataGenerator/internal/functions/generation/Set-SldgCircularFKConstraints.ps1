function Disable-SldgCircularFKConstraints {
	<#
	.SYNOPSIS
		Disables FK constraints for tables involved in circular dependencies.
	.DESCRIPTION
		For SQLite, disables PRAGMA foreign_keys globally.
		For SQL Server, disables only the specific FK constraints forming circular references.
		Returns tracking information needed for re-enabling after data insertion.
	#>
	[CmdletBinding()]
	param (
		[Parameter(Mandatory)]
		[array]$CircularTables,

		[Parameter(Mandatory)]
		$ConnectionInfo,

		$Transaction
	)

	$result = [PSCustomObject]@{
		DisabledTables         = [System.Collections.Generic.List[object]]::new()
		DisabledConstraintNames = [System.Collections.Generic.List[string]]::new()
	}

	$circularTableNames = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
	foreach ($ct in $CircularTables) { [void]$circularTableNames.Add($ct.FullName) }

	if ($ConnectionInfo.Provider -eq 'SQLite') {
		try {
			$fkCmd = $ConnectionInfo.DbConnection.CreateCommand()
			if ($Transaction) { $fkCmd.Transaction = $Transaction }
			$fkCmd.CommandText = "PRAGMA foreign_keys = OFF"
			try { [void]$fkCmd.ExecuteNonQuery() } finally { $fkCmd.Dispose() }
			$result.DisabledTables.AddRange($CircularTables)
			Write-PSFMessage -Level Verbose -String 'Generation.FKDisabledPragma' -StringValues $CircularTables.Count
		}
		catch {
			Write-PSFMessage -Level Warning -String 'Generation.FKDisablePragmaFailed' -StringValues $_
		}
	}
	else {
		foreach ($ct in $CircularTables) {
			$circularFKs = @($ct.ForeignKeys | Where-Object {
				$refFullName = "$($_.ReferencedSchema).$($_.ReferencedTable)"
				$circularTableNames.Contains($refFullName)
			})
			foreach ($fk in $circularFKs) {
				try {
					$fkCmd = $ConnectionInfo.DbConnection.CreateCommand()
					if ($Transaction) { $fkCmd.Transaction = $Transaction }
					$safeName = Get-SldgSafeSqlName -SchemaName $ct.SchemaName -TableName $ct.TableName
					$safeFKName = "[$($fk.ForeignKeyName -replace '\]', ']]')]"
					$fkCmd.CommandText = "ALTER TABLE $safeName NOCHECK CONSTRAINT $safeFKName"
					try { [void]$fkCmd.ExecuteNonQuery() } finally { $fkCmd.Dispose() }
					$result.DisabledConstraintNames.Add("$($ct.FullName)|$($fk.ForeignKeyName)")
					Write-PSFMessage -Level Verbose -String 'Generation.FKDisabledTable' -StringValues "$($ct.FullName).$($fk.ForeignKeyName)"
				}
				catch {
					Write-PSFMessage -Level Warning -String 'Generation.FKDisableTableFailed' -StringValues "$($ct.FullName).$($fk.ForeignKeyName)", $_
				}
			}
			if ($circularFKs.Count -gt 0) {
				$result.DisabledTables.Add($ct)
			}
		}
	}

	$result
}

function Enable-SldgCircularFKConstraints {
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
			Write-PSFMessage -Level Verbose -String 'Generation.FKReenabledPragma'
		}
		catch {
			Write-PSFMessage -Level Warning -String 'Generation.FKReenablePragmaFailed' -StringValues $_
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
				Write-PSFMessage -Level Verbose -String 'Generation.FKReenabledTable' -StringValues "$tblFullName.$fkName"
			}
			catch {
				Write-PSFMessage -Level Warning -String 'Generation.FKReenableTableFailed' -StringValues "$tblFullName.$fkName", $_
				$failures.Add("$tblFullName.$fkName")
			}
		}
	}

	$failures
}
