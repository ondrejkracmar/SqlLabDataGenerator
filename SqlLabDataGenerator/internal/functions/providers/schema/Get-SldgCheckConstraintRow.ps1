function Get-SldgCheckConstraintRow {
	<#
	.SYNOPSIS
		Reads CHECK constraints per column - the one piece of the catalogue the EF import does not carry.
	.DESCRIPTION
		Generators clamp values to CHECK clauses (ranges, IN lists), so the clauses are read
		straight from the engine, keyed by the dialect's catalogue: sys.check_constraints on SQL
		Server (already attributed to a column), the CREATE TABLE text in sqlite_master on SQLite,
		and INFORMATION_SCHEMA.CHECK_CONSTRAINTS everywhere else. Table-level clauses are
		attributed to every column of the table whose name appears in them. Engines without a
		readable catalogue (or without the standard view) yield no rows and a verbose note.
	.PARAMETER ConnectionInfo
		The active SqlLabDataGenerator.Connection.
	.PARAMETER ColumnsByTable
		Column names per 'schema.table' key, used to attribute table-level clauses.
	.OUTPUTS
		System.Data.DataTable with SchemaName, TableName, ConstraintName, ConstraintDefinition, ColumnName.
	#>
	[OutputType([System.Data.DataTable])]
	[CmdletBinding()]
	param (
		[Parameter(Mandatory)]
		[SqlLabDataGenerator.Connection]$ConnectionInfo,

		[Parameter(Mandatory)]
		[hashtable]$ColumnsByTable
	)

	$rows = [System.Data.DataTable]::new()
	foreach ($name in 'SchemaName', 'TableName', 'ConstraintName', 'ConstraintDefinition', 'ColumnName') { [void]$rows.Columns.Add($name, [string]) }

	$dialect = $ConnectionInfo.GetDialect()
	$columnIndex = $ColumnsByTable
	$regexTimeout = [timespan]::FromSeconds(2)

	# Attributes one clause to every column of the table it mentions.
	$attribute = {
		param([string]$SchemaName, [string]$TableName, [string]$ConstraintName, [string]$Clause)
		$key = "$SchemaName.$TableName"
		if (-not $Clause -or -not $columnIndex.ContainsKey($key)) { return }
		foreach ($columnName in $columnIndex[$key]) {
			try {
				if ([regex]::IsMatch($Clause, "(?i)\b$([regex]::Escape($columnName))\b", 'None', $regexTimeout)) {
					[void]$rows.Rows.Add($SchemaName, $TableName, $ConstraintName, $Clause, $columnName)
				}
			}
			catch [System.Text.RegularExpressions.RegexMatchTimeoutException] {
				Write-PSFMessage -Level Warning -Message ($script:strings.'Schema.SQLite.CheckParseTimeout' -f $TableName)
			}
		}
	}

	switch ($dialect.SchemaSource) {
		'SqlServer' {
			$raw = Invoke-SldgDbQuery -ConnectionInfo $ConnectionInfo -Query @"
SELECT
    OBJECT_SCHEMA_NAME(cc.parent_object_id) AS SchemaName,
    OBJECT_NAME(cc.parent_object_id) AS TableName,
    cc.name AS ConstraintName,
    cc.definition AS ConstraintDefinition,
    COL_NAME(cc.parent_object_id, cc.parent_column_id) AS ColumnName
FROM sys.check_constraints cc
"@
			foreach ($row in $raw.Rows) {
				if ($row.ColumnName -is [DBNull] -or -not [string]$row.ColumnName) {
					& $attribute ([string]$row.SchemaName) ([string]$row.TableName) ([string]$row.ConstraintName) ([string]$row.ConstraintDefinition)
				}
				else {
					[void]$rows.Rows.Add([string]$row.SchemaName, [string]$row.TableName, [string]$row.ConstraintName, [string]$row.ConstraintDefinition, [string]$row.ColumnName)
				}
			}
		}
		'Sqlite' {
			$raw = Invoke-SldgDbQuery -ConnectionInfo $ConnectionInfo -Query "SELECT name, sql FROM sqlite_master WHERE type = 'table' AND name NOT LIKE 'sqlite_%'"
			foreach ($row in $raw.Rows) {
				$createSql = [string]$row.sql
				if (-not $createSql) { continue }
				try {
					$checkRegex = [regex]::new('CHECK\s*\(([^)]+)\)', 'IgnoreCase', $regexTimeout)
					$index = 0
					foreach ($m in $checkRegex.Matches($createSql)) {
						$index++
						& $attribute $dialect.DefaultSchema ([string]$row.name) "CK_$($row.name)_$index" $m.Groups[1].Value.Trim()
					}
				}
				catch [System.Text.RegularExpressions.RegexMatchTimeoutException] {
					Write-PSFMessage -Level Warning -Message ($script:strings.'Schema.SQLite.CheckParseTimeout' -f [string]$row.name)
				}
			}
		}
		default {
			try {
				$raw = Invoke-SldgDbQuery -ConnectionInfo $ConnectionInfo -Query @"
SELECT tc.TABLE_SCHEMA AS SchemaName, tc.TABLE_NAME AS TableName, cc.CONSTRAINT_NAME AS ConstraintName, cc.CHECK_CLAUSE AS ConstraintDefinition
FROM INFORMATION_SCHEMA.CHECK_CONSTRAINTS cc
INNER JOIN INFORMATION_SCHEMA.TABLE_CONSTRAINTS tc
    ON tc.CONSTRAINT_NAME = cc.CONSTRAINT_NAME
   AND tc.CONSTRAINT_SCHEMA = cc.CONSTRAINT_SCHEMA
WHERE tc.CONSTRAINT_TYPE = 'CHECK'
"@
				foreach ($row in $raw.Rows) {
					& $attribute ([string]$row.SchemaName) ([string]$row.TableName) ([string]$row.ConstraintName) ([string]$row.ConstraintDefinition)
				}
			}
			catch {
				Write-PSFMessage -Level Verbose -String 'Schema.CheckConstraintsUnavailable' -StringValues $ConnectionInfo.Provider, $_.Exception.Message
			}
		}
	}

	, $rows
}
