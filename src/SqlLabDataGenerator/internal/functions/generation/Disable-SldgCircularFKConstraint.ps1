function Disable-SldgCircularFKConstraint {
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
			Write-PSFMessage -Level Verbose -Message ($script:strings.'Generation.FKDisabledPragma' -f $CircularTables.Count)
		}
		catch {
			Write-PSFMessage -Level Warning -Message ($script:strings.'Generation.FKDisablePragmaFailed' -f $_)
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
					Write-PSFMessage -Level Verbose -Message ($script:strings.'Generation.FKDisabledTable' -f "$($ct.FullName).$($fk.ForeignKeyName)")
				}
				catch {
					Write-PSFMessage -Level Warning -Message ($script:strings.'Generation.FKDisableTableFailed' -f "$($ct.FullName).$($fk.ForeignKeyName)", $_)
				}
			}
			if ($circularFKs.Count -gt 0) {
				$result.DisabledTables.Add($ct)
			}
		}
	}

	$result
}
