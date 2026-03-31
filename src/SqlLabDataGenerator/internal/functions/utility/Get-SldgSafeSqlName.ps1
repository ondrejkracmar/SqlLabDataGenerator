function Get-SldgSafeSqlName {
	<#
	.SYNOPSIS
		Returns a safely-escaped SQL identifier.
	.DESCRIPTION
		Escapes identifiers for use in SQL commands.
		- SQL Server: bracket-escaped [name] (escapes ] as ]])
		- SQLite (-SQLite switch): double-quote escaped "name" (escapes " as "")
		Use -ColumnName alone for a single identifier.
		Use -SchemaName/-TableName for [schema].[table] or [table] / "table".
	#>
	[CmdletBinding()]
	param (
		[string]$SchemaName,

		[string]$TableName,

		[string]$ColumnName,

		[switch]$SQLite
	)

	if ($SQLite) {
		# SQLite: bracket escaping (same as SQL Server) but strip schema prefix
		if ($ColumnName -and -not $TableName) {
			$safeCol = $ColumnName -replace '\]', ']]'
			return "[$safeCol]"
		}
		$safeTable = $TableName -replace '\]', ']]'
		return "[$safeTable]"
	}

	# SQL Server uses bracket escaping
	if ($ColumnName -and -not $TableName) {
		$safeCol = $ColumnName -replace '\]', ']]'
		return "[$safeCol]"
	}

	$safeTable = $TableName -replace '\]', ']]'
	if (-not $SchemaName) {
		return "[$safeTable]"
	}
	$safeSchema = $SchemaName -replace '\]', ']]'
	return "[$safeSchema].[$safeTable]"
}
