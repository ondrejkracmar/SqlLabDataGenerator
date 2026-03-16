function Get-SldgSafeSqlName {
	<#
	.SYNOPSIS
		Returns a bracket-escaped SQL identifier.
	.DESCRIPTION
		Escapes closing brackets in schema, table, and column names and returns
		a bracket-escaped identifier safe for SQL commands.
		Use -ColumnName alone for a single [column] identifier.
		Use -SchemaName/-TableName for [schema].[table] or [table] (SQLite).
	#>
	[CmdletBinding()]
	param (
		[string]$SchemaName,

		[string]$TableName,

		[string]$ColumnName,

		[switch]$SQLite
	)

	if ($ColumnName -and -not $TableName) {
		$safeCol = $ColumnName -replace '\]', ']]'
		return "[$safeCol]"
	}

	$safeTable = $TableName -replace '\]', ']]'
	if ($SQLite -or -not $SchemaName) {
		return "[$safeTable]"
	}
	$safeSchema = $SchemaName -replace '\]', ']]'
	return "[$safeSchema].[$safeTable]"
}
