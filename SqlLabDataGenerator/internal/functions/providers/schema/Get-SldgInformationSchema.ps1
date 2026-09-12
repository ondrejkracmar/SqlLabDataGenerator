function Get-SldgInformationSchema {
	<#
	.SYNOPSIS
		Reads schema metadata through the ANSI INFORMATION_SCHEMA views.
	.DESCRIPTION
		The schema reader for every engine without a dedicated catalog reader - DuckDB,
		PostgreSQL, MySQL/MariaDB and whatever PSSqlRepository provider comes next. It uses
		only the views and columns the SQL standard defines (TABLES, COLUMNS,
		TABLE_CONSTRAINTS, KEY_COLUMN_USAGE, REFERENTIAL_CONSTRAINTS, CHECK_CONSTRAINTS) and
		shapes the rows exactly like the SQL Server reader so ConvertTo-SldgSchemaModel can
		build the same SchemaModel from them.

		Engines differ in what they expose beyond the standard (identity columns, computed
		columns, view definitions); those are detected best-effort from the COLUMNS view where
		the engine adds the information (IS_IDENTITY / EXTRA / IS_GENERATED) and left false
		otherwise. System schemas (information_schema, pg_catalog, mysql, sys, ...) are
		excluded.
	.PARAMETER ConnectionInfo
		The active SqlLabDataGenerator.Connection.
	.PARAMETER SchemaFilter
		Optional list of schema names to include.
	.PARAMETER TableFilter
		Optional list of table names to include.
	#>
	[OutputType([SqlLabDataGenerator.SchemaModel])]
	[CmdletBinding()]
	param (
		[Parameter(Mandatory)]
		[SqlLabDataGenerator.Connection]$ConnectionInfo,

		[string[]]$SchemaFilter,

		[string[]]$TableFilter
	)

	$systemSchemas = @('information_schema', 'pg_catalog', 'pg_toast', 'mysql', 'performance_schema', 'sys', 'duckdb_internal')

	$query = { param([string]$Sql) Invoke-SldgDbQuery -ConnectionInfo $ConnectionInfo -Query $Sql }

	$tablesRaw = & $query @"
SELECT TABLE_SCHEMA, TABLE_NAME
FROM INFORMATION_SCHEMA.TABLES
WHERE TABLE_TYPE = 'BASE TABLE'
ORDER BY TABLE_SCHEMA, TABLE_NAME
"@

	$columnsRaw = & $query @"
SELECT *
FROM INFORMATION_SCHEMA.COLUMNS
ORDER BY TABLE_SCHEMA, TABLE_NAME, ORDINAL_POSITION
"@

	# PRIMARY KEY / UNIQUE constraints per column
	$uniqueRaw = & $query @"
SELECT kcu.TABLE_SCHEMA, kcu.TABLE_NAME, kcu.COLUMN_NAME, tc.CONSTRAINT_NAME, tc.CONSTRAINT_TYPE
FROM INFORMATION_SCHEMA.TABLE_CONSTRAINTS tc
INNER JOIN INFORMATION_SCHEMA.KEY_COLUMN_USAGE kcu
    ON kcu.CONSTRAINT_NAME = tc.CONSTRAINT_NAME
   AND kcu.TABLE_SCHEMA = tc.TABLE_SCHEMA
   AND kcu.TABLE_NAME = tc.TABLE_NAME
WHERE tc.CONSTRAINT_TYPE IN ('PRIMARY KEY', 'UNIQUE')
"@

	# FOREIGN KEY constraints: the referencing column comes from KEY_COLUMN_USAGE of the
	# FK constraint, the referenced column from KEY_COLUMN_USAGE of the unique constraint
	# named by REFERENTIAL_CONSTRAINTS, matched on ordinal position for composite keys.
	$fkRaw = & $query @"
SELECT
    rc.CONSTRAINT_NAME AS ForeignKeyName,
    kcu.TABLE_SCHEMA   AS ParentSchema,
    kcu.TABLE_NAME     AS ParentTable,
    kcu.COLUMN_NAME    AS ParentColumn,
    ref.TABLE_SCHEMA   AS ReferencedSchema,
    ref.TABLE_NAME     AS ReferencedTable,
    ref.COLUMN_NAME    AS ReferencedColumn
FROM INFORMATION_SCHEMA.REFERENTIAL_CONSTRAINTS rc
INNER JOIN INFORMATION_SCHEMA.KEY_COLUMN_USAGE kcu
    ON kcu.CONSTRAINT_NAME = rc.CONSTRAINT_NAME
   AND kcu.CONSTRAINT_SCHEMA = rc.CONSTRAINT_SCHEMA
INNER JOIN INFORMATION_SCHEMA.KEY_COLUMN_USAGE ref
    ON ref.CONSTRAINT_NAME = rc.UNIQUE_CONSTRAINT_NAME
   AND ref.CONSTRAINT_SCHEMA = rc.UNIQUE_CONSTRAINT_SCHEMA
   AND ref.ORDINAL_POSITION = kcu.ORDINAL_POSITION
ORDER BY rc.CONSTRAINT_NAME, kcu.ORDINAL_POSITION
"@

	# CHECK constraints are optional in practice (DuckDB exposes the view, MySQL < 8.0.16 does not).
	$checkRaw = $null
	try {
		$checkRaw = & $query @"
SELECT tc.TABLE_SCHEMA AS SchemaName, tc.TABLE_NAME AS TableName, cc.CONSTRAINT_NAME AS ConstraintName, cc.CHECK_CLAUSE AS ConstraintDefinition
FROM INFORMATION_SCHEMA.CHECK_CONSTRAINTS cc
INNER JOIN INFORMATION_SCHEMA.TABLE_CONSTRAINTS tc
    ON tc.CONSTRAINT_NAME = cc.CONSTRAINT_NAME
   AND tc.CONSTRAINT_SCHEMA = cc.CONSTRAINT_SCHEMA
WHERE tc.CONSTRAINT_TYPE = 'CHECK'
"@
	}
	catch {
		Write-PSFMessage -Level Verbose -String 'Schema.CheckConstraintsUnavailable' -StringValues $ConnectionInfo.Provider, $_.Exception.Message
	}

	#region Shape the rows like the SQL Server reader
	$tables = New-Object System.Data.DataTable
	[void]$tables.Columns.Add('TABLE_SCHEMA', [string])
	[void]$tables.Columns.Add('TABLE_NAME', [string])
	foreach ($row in $tablesRaw.Rows) {
		if ([string]$row.TABLE_SCHEMA -in $systemSchemas) { continue }
		[void]$tables.Rows.Add([string]$row.TABLE_SCHEMA, [string]$row.TABLE_NAME)
	}

	$columns = New-Object System.Data.DataTable
	foreach ($name in 'TABLE_SCHEMA', 'TABLE_NAME', 'COLUMN_NAME', 'DATA_TYPE', 'IS_NULLABLE', 'COLUMN_DEFAULT') { [void]$columns.Columns.Add($name, [string]) }
	foreach ($name in 'CHARACTER_MAXIMUM_LENGTH', 'NUMERIC_PRECISION', 'NUMERIC_SCALE', 'ORDINAL_POSITION', 'IsIdentity', 'IsComputed') { [void]$columns.Columns.Add($name, [int]) }

	$hasColumn = { param($Table, [string]$Name) $Table.Columns.Contains($Name) }
	$columnHasIdentity = & $hasColumn $columnsRaw 'IS_IDENTITY'
	$columnHasExtra = & $hasColumn $columnsRaw 'EXTRA'
	$columnHasGenerated = & $hasColumn $columnsRaw 'IS_GENERATED'
	$columnHasDefault = & $hasColumn $columnsRaw 'COLUMN_DEFAULT'

	foreach ($row in $columnsRaw.Rows) {
		if ([string]$row.TABLE_SCHEMA -in $systemSchemas) { continue }
		$new = $columns.NewRow()
		$new.TABLE_SCHEMA = [string]$row.TABLE_SCHEMA
		$new.TABLE_NAME = [string]$row.TABLE_NAME
		$new.COLUMN_NAME = [string]$row.COLUMN_NAME
		$new.DATA_TYPE = ConvertTo-SldgCanonicalDataType -DataType ([string]$row.DATA_TYPE)
		$new.IS_NULLABLE = if (([string]$row.IS_NULLABLE).ToUpperInvariant() -in 'YES', 'TRUE', '1') { 'YES' } else { 'NO' }
		$new.COLUMN_DEFAULT = if ($columnHasDefault -and $row.COLUMN_DEFAULT -isnot [DBNull]) { [string]$row.COLUMN_DEFAULT } else { [DBNull]::Value }
		foreach ($numeric in 'CHARACTER_MAXIMUM_LENGTH', 'NUMERIC_PRECISION', 'NUMERIC_SCALE', 'ORDINAL_POSITION') {
			$value = $row.$numeric
			$new.$numeric = if ($null -eq $value -or $value -is [DBNull]) { [DBNull]::Value } else { [int]$value }
		}

		$isIdentity = $false
		if ($columnHasIdentity -and ([string]$row.IS_IDENTITY).ToUpperInvariant() -in 'YES', 'TRUE', '1') { $isIdentity = $true }
		if ($columnHasExtra -and ([string]$row.EXTRA) -match 'auto_increment') { $isIdentity = $true }
		if ($columnHasDefault -and ([string]$row.COLUMN_DEFAULT) -match '^nextval\(') { $isIdentity = $true }
		$isComputed = $columnHasGenerated -and ([string]$row.IS_GENERATED).ToUpperInvariant() -in 'ALWAYS', 'YES', 'TRUE', '1'
		$new.IsIdentity = [int]$isIdentity
		$new.IsComputed = [int]$isComputed
		$columns.Rows.Add($new)
	}

	$uniqueConstraints = New-Object System.Data.DataTable
	foreach ($name in 'SchemaName', 'TableName', 'ConstraintName', 'ColumnName') { [void]$uniqueConstraints.Columns.Add($name, [string]) }
	[void]$uniqueConstraints.Columns.Add('IsUnique', [bool])
	[void]$uniqueConstraints.Columns.Add('IsPrimaryKey', [bool])
	foreach ($row in $uniqueRaw.Rows) {
		$isPk = [string]$row.CONSTRAINT_TYPE -eq 'PRIMARY KEY'
		[void]$uniqueConstraints.Rows.Add([string]$row.TABLE_SCHEMA, [string]$row.TABLE_NAME, [string]$row.CONSTRAINT_NAME, [string]$row.COLUMN_NAME, $true, $isPk)
	}

	$checkConstraints = New-Object System.Data.DataTable
	foreach ($name in 'SchemaName', 'TableName', 'ConstraintName', 'ConstraintDefinition', 'ColumnName') { [void]$checkConstraints.Columns.Add($name, [string]) }
	if ($checkRaw) {
		# INFORMATION_SCHEMA does not tie a CHECK to a column; attribute it to every column
		# of the table whose name appears in the clause, like the SQLite reader does.
		$columnsByTable = @{}
		foreach ($row in $columns.Rows) {
			$key = "$($row.TABLE_SCHEMA).$($row.TABLE_NAME)"
			if (-not $columnsByTable.ContainsKey($key)) { $columnsByTable[$key] = [System.Collections.Generic.List[string]]::new() }
			$columnsByTable[$key].Add([string]$row.COLUMN_NAME)
		}
		foreach ($row in $checkRaw.Rows) {
			$key = "$($row.SchemaName).$($row.TableName)"
			if (-not $columnsByTable.ContainsKey($key)) { continue }
			$clause = [string]$row.ConstraintDefinition
			foreach ($columnName in $columnsByTable[$key]) {
				if ($clause -match "(?i)\b$([regex]::Escape($columnName))\b") {
					[void]$checkConstraints.Rows.Add([string]$row.SchemaName, [string]$row.TableName, [string]$row.ConstraintName, $clause, $columnName)
				}
			}
		}
	}
	#endregion Shape the rows like the SQL Server reader

	Write-PSFMessage -Level Verbose -String 'Schema.SqlServer.Retrieved' -StringValues $tables.Rows.Count, $columns.Rows.Count, $fkRaw.Rows.Count

	ConvertTo-SldgSchemaModel -Tables $tables -Columns $columns -ForeignKeys $fkRaw `
		-UniqueConstraints $uniqueConstraints -CheckConstraints $checkConstraints `
		-SchemaFilter $SchemaFilter -TableFilter $TableFilter -Database $ConnectionInfo.Database
}
