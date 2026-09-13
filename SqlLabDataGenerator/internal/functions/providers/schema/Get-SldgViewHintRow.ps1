function Get-SldgViewHintRow {
	<#
	.SYNOPSIS
		Reads view definitions that reference base tables, for the JSON/XML column hints.
	.DESCRIPTION
		A view that applies JSON_VALUE / OPENJSON / .value() to a column tells the generator
		that the column holds JSON or XML, and often which shape. Only SQL Server exposes view
		text together with the dependency graph in a way that ties a view to the tables it reads
		(sys.sql_expression_dependencies + sys.sql_modules); other engines yield no rows.
	.PARAMETER ConnectionInfo
		The active SqlLabDataGenerator.Connection.
	.OUTPUTS
		System.Data.DataTable with ViewSchema, ViewName, TableSchema, TableName, ViewDefinition.
	#>
	[OutputType([System.Data.DataTable])]
	[CmdletBinding()]
	param (
		[Parameter(Mandatory)]
		[SqlLabDataGenerator.Connection]$ConnectionInfo
	)

	$rows = [System.Data.DataTable]::new()
	foreach ($name in 'ViewSchema', 'ViewName', 'TableSchema', 'TableName', 'ViewDefinition') { [void]$rows.Columns.Add($name, [string]) }

	if ($ConnectionInfo.GetDialect().SchemaSource -ne 'SqlServer') { return , $rows }

	$raw = Invoke-SldgDbQuery -ConnectionInfo $ConnectionInfo -Query @"
SELECT
    OBJECT_SCHEMA_NAME(d.referencing_id) AS ViewSchema,
    OBJECT_NAME(d.referencing_id) AS ViewName,
    OBJECT_SCHEMA_NAME(d.referenced_id) AS TableSchema,
    OBJECT_NAME(d.referenced_id) AS TableName,
    m.definition AS ViewDefinition
FROM sys.sql_expression_dependencies d
INNER JOIN sys.sql_modules m ON m.object_id = d.referencing_id
INNER JOIN sys.views v ON v.object_id = d.referencing_id
WHERE d.referenced_id IS NOT NULL
    AND OBJECTPROPERTY(d.referencing_id, 'IsView') = 1
ORDER BY TableSchema, TableName, ViewSchema, ViewName
"@
	foreach ($row in $raw.Rows) {
		[void]$rows.Rows.Add([string]$row.ViewSchema, [string]$row.ViewName, [string]$row.TableSchema, [string]$row.TableName, [string]$row.ViewDefinition)
	}

	, $rows
}
