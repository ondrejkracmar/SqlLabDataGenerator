function Get-SldgSqlServerSchema {
	<#
	.SYNOPSIS
		Reads complete schema metadata from a SQL Server database.
	.DESCRIPTION
		Queries INFORMATION_SCHEMA and sys catalog views to extract tables, columns,
		foreign keys, primary keys, unique constraints, and check constraints.
		Filtering by schema/table is applied in PowerShell after retrieval.
	#>
	[CmdletBinding()]
	param (
		[Parameter(Mandatory)]
		$ConnectionInfo,

		[string[]]$SchemaFilter,

		[string[]]$TableFilter
	)

	$conn = $ConnectionInfo.Connection

	# Helper to execute a read-only query
	$executeQuery = {
		param([string]$Query)
		$cmd = $conn.CreateCommand()
		$cmd.CommandText = $Query
		$cmd.CommandTimeout = 120
		$adapter = New-Object System.Data.SqlClient.SqlDataAdapter($cmd)
		$dataTable = New-Object System.Data.DataTable
		try {
			[void]$adapter.Fill($dataTable)
		}
		finally {
			$adapter.Dispose()
			$cmd.Dispose()
		}
		$dataTable
	}

	# Get tables
	$tables = & $executeQuery -Query @"
SELECT TABLE_SCHEMA, TABLE_NAME
FROM INFORMATION_SCHEMA.TABLES
WHERE TABLE_TYPE = 'BASE TABLE'
ORDER BY TABLE_SCHEMA, TABLE_NAME
"@

	# Get columns with identity/computed info
	$columns = & $executeQuery -Query @"
SELECT
    c.TABLE_SCHEMA, c.TABLE_NAME, c.COLUMN_NAME,
    c.DATA_TYPE, c.CHARACTER_MAXIMUM_LENGTH,
    c.NUMERIC_PRECISION, c.NUMERIC_SCALE,
    c.IS_NULLABLE, c.COLUMN_DEFAULT, c.ORDINAL_POSITION,
    COLUMNPROPERTY(OBJECT_ID(QUOTENAME(c.TABLE_SCHEMA) + '.' + QUOTENAME(c.TABLE_NAME)), c.COLUMN_NAME, 'IsIdentity') AS IsIdentity,
    COLUMNPROPERTY(OBJECT_ID(QUOTENAME(c.TABLE_SCHEMA) + '.' + QUOTENAME(c.TABLE_NAME)), c.COLUMN_NAME, 'IsComputed') AS IsComputed
FROM INFORMATION_SCHEMA.COLUMNS c
INNER JOIN INFORMATION_SCHEMA.TABLES t
    ON c.TABLE_SCHEMA = t.TABLE_SCHEMA AND c.TABLE_NAME = t.TABLE_NAME
WHERE t.TABLE_TYPE = 'BASE TABLE'
ORDER BY c.TABLE_SCHEMA, c.TABLE_NAME, c.ORDINAL_POSITION
"@

	# Get foreign keys
	$foreignKeys = & $executeQuery -Query @"
SELECT
    fk.name AS ForeignKeyName,
    OBJECT_SCHEMA_NAME(fk.parent_object_id) AS ParentSchema,
    OBJECT_NAME(fk.parent_object_id) AS ParentTable,
    COL_NAME(fkc.parent_object_id, fkc.parent_column_id) AS ParentColumn,
    OBJECT_SCHEMA_NAME(fk.referenced_object_id) AS ReferencedSchema,
    OBJECT_NAME(fk.referenced_object_id) AS ReferencedTable,
    COL_NAME(fkc.referenced_object_id, fkc.referenced_column_id) AS ReferencedColumn
FROM sys.foreign_keys fk
INNER JOIN sys.foreign_key_columns fkc ON fk.object_id = fkc.constraint_object_id
ORDER BY fk.name
"@

	# Get primary keys and unique constraints
	$uniqueConstraints = & $executeQuery -Query @"
SELECT
    OBJECT_SCHEMA_NAME(ic.object_id) AS SchemaName,
    OBJECT_NAME(ic.object_id) AS TableName,
    i.name AS ConstraintName,
    COL_NAME(ic.object_id, ic.column_id) AS ColumnName,
    i.is_unique AS IsUnique,
    i.is_primary_key AS IsPrimaryKey
FROM sys.index_columns ic
INNER JOIN sys.indexes i ON ic.object_id = i.object_id AND ic.index_id = i.index_id
WHERE (i.is_primary_key = 1 OR i.is_unique = 1)
ORDER BY OBJECT_SCHEMA_NAME(ic.object_id), OBJECT_NAME(ic.object_id), i.name
"@

	# Get check constraints
	$checkConstraints = & $executeQuery -Query @"
SELECT
    OBJECT_SCHEMA_NAME(cc.parent_object_id) AS SchemaName,
    OBJECT_NAME(cc.parent_object_id) AS TableName,
    cc.name AS ConstraintName,
    cc.definition AS ConstraintDefinition,
    COL_NAME(cc.parent_object_id, cc.parent_column_id) AS ColumnName
FROM sys.check_constraints cc
"@

	Write-PSFMessage -Level Verbose -Message "Retrieved: $($tables.Rows.Count) tables, $($columns.Rows.Count) columns, $($foreignKeys.Rows.Count) FK relationships"

	# Build normalized schema model
	ConvertTo-SldgSchemaModel -Tables $tables -Columns $columns -ForeignKeys $foreignKeys `
		-UniqueConstraints $uniqueConstraints -CheckConstraints $checkConstraints `
		-SchemaFilter $SchemaFilter -TableFilter $TableFilter -Database $ConnectionInfo.Database
}
