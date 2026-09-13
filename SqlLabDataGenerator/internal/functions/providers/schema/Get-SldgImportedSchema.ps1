function Get-SldgImportedSchema {
	<#
	.SYNOPSIS
		Builds the schema model from PSSqlRepository's database-first import - the one reader for every engine.
	.DESCRIPTION
		PSSqlRepository reads the catalogue through the EF Core provider's own reverse-engineering
		component (Import-PSSqlRepositorySchema): tables, columns with their store type, nullability,
		default, identity and computed flags, primary keys, unique constraints, indexes and foreign
		keys - the same for SQL Server, SQLite, DuckDB and any provider extension. This function turns
		that result into the INFORMATION_SCHEMA-shaped rows ConvertTo-SldgSchemaModel consumes, so the
		generator has one schema reader instead of one per catalogue.

		Two things the EF catalogue model does not carry come from a small dialect-keyed augmentation:
		CHECK constraints (Get-SldgCheckConstraintRow) and view definitions for the JSON/XML column
		hints (Get-SldgViewHintRow, SQL Server only).

		The catalogue is read fresh on every call, so tables created after Connect-SldgDatabase are
		seen. Entity types are only registered at connect time; Get-SldgDatabaseSchema attaches them
		from the connection.
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

	$dialect = $ConnectionInfo.GetDialect()
	$import = Import-SldgRepositorySchema -ConnectionInfo $ConnectionInfo
	$systemSchemas = @('information_schema', 'pg_catalog', 'pg_toast', 'mysql', 'performance_schema', 'sys', 'duckdb_internal')

	$tables = [System.Data.DataTable]::new()
	foreach ($name in 'TABLE_SCHEMA', 'TABLE_NAME') { [void]$tables.Columns.Add($name, [string]) }

	$columns = [System.Data.DataTable]::new()
	foreach ($name in 'TABLE_SCHEMA', 'TABLE_NAME', 'COLUMN_NAME', 'DATA_TYPE', 'IS_NULLABLE', 'COLUMN_DEFAULT') { [void]$columns.Columns.Add($name, [string]) }
	foreach ($name in 'CHARACTER_MAXIMUM_LENGTH', 'NUMERIC_PRECISION', 'NUMERIC_SCALE', 'ORDINAL_POSITION', 'IsIdentity', 'IsComputed') { [void]$columns.Columns.Add($name, [int]) }

	$foreignKeys = [System.Data.DataTable]::new()
	foreach ($name in 'ForeignKeyName', 'ParentSchema', 'ParentTable', 'ParentColumn', 'ReferencedSchema', 'ReferencedTable', 'ReferencedColumn') { [void]$foreignKeys.Columns.Add($name, [string]) }

	$uniqueConstraints = [System.Data.DataTable]::new()
	foreach ($name in 'SchemaName', 'TableName', 'ConstraintName', 'ColumnName') { [void]$uniqueConstraints.Columns.Add($name, [string]) }
	foreach ($name in 'IsUnique', 'IsPrimaryKey') { [void]$uniqueConstraints.Columns.Add($name, [bool]) }

	$columnsByTable = @{}

	foreach ($table in @($import.Tables)) {
		if ($table.IsView) { continue }
		$schemaName = if ($table.Schema) { [string]$table.Schema } else { $dialect.DefaultSchema }
		if ($schemaName -in $systemSchemas) { continue }
		$tableName = [string]$table.Name

		[void]$tables.Rows.Add($schemaName, $tableName)
		$tableKey = "$schemaName.$tableName"
		$columnsByTable[$tableKey] = [System.Collections.Generic.List[string]]::new()

		$ordinal = 0
		foreach ($column in @($table.Columns)) {
			$ordinal++
			$facets = ConvertFrom-SldgStoreTypeFacet -StoreType $column.StoreType
			$default = [string]$column.DefaultValueSql
			# Identity: the engine generates the value on insert without a declared default (SQL Server
			# IDENTITY, SQLite AUTOINCREMENT / rowid alias), or the default draws from a sequence (DuckDB,
			# PostgreSQL serial). Either way the generator must not supply the value.
			$isIdentity = ($column.IsGeneratedOnAdd -and -not $column.IsComputed -and (-not $default -or $default -match '(?i)nextval\('))
			$row = $columns.NewRow()
			$row.TABLE_SCHEMA = $schemaName
			$row.TABLE_NAME = $tableName
			$row.COLUMN_NAME = [string]$column.Name
			$dataType = ConvertTo-SldgCanonicalDataType -DataType ([string]$column.StoreType)
			# SQLite's REAL affinity is an 8-byte double, not SQL Server's 4-byte real.
			if ($dataType -eq 'real' -and $dialect.SchemaSource -eq 'Sqlite') { $dataType = 'float' }
			$row.DATA_TYPE = $dataType
			$row.IS_NULLABLE = if ($column.IsNullable) { 'YES' } else { 'NO' }
			$row.COLUMN_DEFAULT = if ($default) { $default } else { [DBNull]::Value }
			$row.CHARACTER_MAXIMUM_LENGTH = if ($null -ne $facets.MaxLength) { $facets.MaxLength } else { [DBNull]::Value }
			$row.NUMERIC_PRECISION = if ($null -ne $facets.Precision) { $facets.Precision } else { [DBNull]::Value }
			$row.NUMERIC_SCALE = if ($null -ne $facets.Scale) { $facets.Scale } else { [DBNull]::Value }
			$row.ORDINAL_POSITION = $ordinal
			$row.IsIdentity = [int][bool]$isIdentity
			$row.IsComputed = [int][bool]$column.IsComputed
			$columns.Rows.Add($row)
			$columnsByTable[$tableKey].Add([string]$column.Name)

			if ($column.IsPrimaryKey) {
				[void]$uniqueConstraints.Rows.Add($schemaName, $tableName, "PK_$tableName", [string]$column.Name, $true, $true)
			}
		}

		foreach ($unique in @($table.UniqueConstraints)) {
			foreach ($columnName in @($unique.Columns)) {
				[void]$uniqueConstraints.Rows.Add($schemaName, $tableName, [string]$unique.Name, [string]$columnName, $true, $false)
			}
		}
		foreach ($index in @($table.Indexes)) {
			if (-not $index.IsUnique) { continue }
			foreach ($columnName in @($index.Columns)) {
				[void]$uniqueConstraints.Rows.Add($schemaName, $tableName, [string]$index.Name, [string]$columnName, $true, $false)
			}
		}

		foreach ($fk in @($table.ForeignKeys)) {
			$referencedSchema = if ($fk.PrincipalSchema) { [string]$fk.PrincipalSchema } else { $dialect.DefaultSchema }
			for ($i = 0; $i -lt $fk.Columns.Count; $i++) {
				$constraintName = if ($fk.Name) { [string]$fk.Name } else { "FK_${tableName}_$($fk.Columns[$i])_$($fk.PrincipalTable)_$($fk.PrincipalColumns[$i])" }
				[void]$foreignKeys.Rows.Add($constraintName, $schemaName, $tableName, [string]$fk.Columns[$i], $referencedSchema, [string]$fk.PrincipalTable, [string]$fk.PrincipalColumns[$i])
			}
		}
	}

	# Some EF providers (DuckDB.EFCore among them) scaffold no unique constraints or indexes. The
	# standard catalogue view fills the gap where it exists; a failure just leaves uniqueness unknown.
	if ($dialect.SchemaSource -eq 'InformationSchema' -and @($uniqueConstraints.Select('IsPrimaryKey = false')).Count -eq 0) {
		try {
			$uniqueRaw = Invoke-SldgDbQuery -ConnectionInfo $ConnectionInfo -Query @"
SELECT kcu.TABLE_SCHEMA, kcu.TABLE_NAME, kcu.COLUMN_NAME, tc.CONSTRAINT_NAME
FROM INFORMATION_SCHEMA.TABLE_CONSTRAINTS tc
INNER JOIN INFORMATION_SCHEMA.KEY_COLUMN_USAGE kcu
    ON kcu.CONSTRAINT_NAME = tc.CONSTRAINT_NAME
   AND kcu.TABLE_SCHEMA = tc.TABLE_SCHEMA
   AND kcu.TABLE_NAME = tc.TABLE_NAME
WHERE tc.CONSTRAINT_TYPE = 'UNIQUE'
"@
			foreach ($row in $uniqueRaw.Rows) {
				[void]$uniqueConstraints.Rows.Add([string]$row.TABLE_SCHEMA, [string]$row.TABLE_NAME, [string]$row.CONSTRAINT_NAME, [string]$row.COLUMN_NAME, $true, $false)
			}
		}
		catch {
			Write-PSFMessage -Level Verbose -String 'Schema.UniqueConstraintsUnavailable' -StringValues $ConnectionInfo.Provider, $_.Exception.Message
		}
	}

	$checkConstraints = Get-SldgCheckConstraintRow -ConnectionInfo $ConnectionInfo -ColumnsByTable $columnsByTable
	$viewHints = Get-SldgViewHintRow -ConnectionInfo $ConnectionInfo

	Write-PSFMessage -Level Verbose -Message ($script:strings.'Schema.SqlServer.Retrieved' -f $tables.Rows.Count, $columns.Rows.Count, $foreignKeys.Rows.Count)

	ConvertTo-SldgSchemaModel -Tables $tables -Columns $columns -ForeignKeys $foreignKeys `
		-UniqueConstraints $uniqueConstraints -CheckConstraints $checkConstraints `
		-ViewHints $viewHints `
		-SchemaFilter $SchemaFilter -TableFilter $TableFilter -Database $ConnectionInfo.Database
}
