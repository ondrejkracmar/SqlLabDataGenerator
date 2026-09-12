function Get-SldgSafeSqlName {
	<#
	.SYNOPSIS
		Returns a safely-quoted SQL identifier for the connection's dialect.
	.DESCRIPTION
		Thin wrapper over SqlLabDataGenerator.Data.SqlDialect so PowerShell callers quote
		identifiers the way the target engine expects: [name] on SQL Server, "name" on
		SQLite/DuckDB/PostgreSQL, `name` on MySQL. Engines without schemas (SQLite) drop
		the schema prefix.

		Use -ColumnName alone for a single identifier, -SchemaName/-TableName for a
		qualified table name. Pass -ConnectionInfo (preferred) or -Dialect to choose the
		dialect; -SQLite is kept for older callers and selects the SQLite dialect. With no
		dialect information at all the SQL Server rules apply.
	.PARAMETER SchemaName
		Schema part of a qualified table name.
	.PARAMETER TableName
		Table part of a qualified table name.
	.PARAMETER ColumnName
		A single identifier (column, constraint, index).
	.PARAMETER ConnectionInfo
		The SqlLabDataGenerator.Connection whose dialect does the quoting.
	.PARAMETER Dialect
		An explicit SqlLabDataGenerator.Data.SqlDialect.
	.PARAMETER SQLite
		Quote for SQLite. Kept for backward compatibility; prefer -ConnectionInfo.
	#>
	[OutputType([string])]
	[CmdletBinding()]
	param (
		[string]$SchemaName,

		[string]$TableName,

		[string]$ColumnName,

		[SqlLabDataGenerator.Connection]$ConnectionInfo,

		[SqlLabDataGenerator.Data.SqlDialect]$Dialect,

		[switch]$SQLite
	)

	if (-not $Dialect) {
		$Dialect = if ($ConnectionInfo) { $ConnectionInfo.GetDialect() }
		elseif ($SQLite) { [SqlLabDataGenerator.Data.SqliteDialect]::new() }
		else { [SqlLabDataGenerator.Data.SqlServerDialect]::new() }
	}

	if ($PSBoundParameters.ContainsKey('ColumnName') -and -not $TableName) {
		return $Dialect.QuoteIdentifier($ColumnName)
	}

	$Dialect.QualifiedName($SchemaName, $TableName)
}
