function ConvertTo-SldgCanonicalDataType {
	<#
	.SYNOPSIS
		Maps an engine's column type name onto the SQL Server type vocabulary the engine uses.
	.DESCRIPTION
		Generators, range clamping, uniqueness handling and validation all branch on SQL
		Server type names ('int', 'nvarchar', 'datetime2', 'bit', ...). Every other engine
		reports its own names - 'integer' and 'double' from DuckDB, 'character varying' and
		'timestamp without time zone' from PostgreSQL, 'TEXT' and 'REAL' affinities from
		SQLite - so the readers for those catalogs run each type through this map before
		building a ColumnInfo. Anything unrecognised is returned lower-cased and unchanged.

		Note the one deliberate asymmetry: 'timestamp' is SQL Server's rowversion (never
		generated), but a date-time on DuckDB, PostgreSQL and MySQL - it maps to 'datetime2'.
	.PARAMETER DataType
		The type name as reported by the catalog, with or without a length/precision suffix.
	.OUTPUTS
		System.String
	#>
	[OutputType([string])]
	[CmdletBinding()]
	param (
		[Parameter(Mandatory)]
		[AllowEmptyString()]
		[string]$DataType
	)

	$name = ($DataType -replace '\(.*\)', '').Trim().ToLowerInvariant()
	if (-not $name) { return 'nvarchar' }

	switch -Regex ($name) {
		'^(tinyint|utinyint|int1|uint8)$'                                  { return 'tinyint' }
		'^(smallint|int2|usmallint|int16|uint16)$'                         { return 'smallint' }
		'^(int|integer|int4|mediumint|uinteger|int32|uint32|serial)$'      { return 'int' }
		'^(bigint|int8|hugeint|ubigint|int64|uint64|bigserial|long)$'      { return 'bigint' }
		'^(bit|bool|boolean)$'                                             { return 'bit' }
		'^(decimal|numeric|dec|number)$'                                   { return 'decimal' }
		'^(money|smallmoney)$'                                             { return $name }
		'^(float|double|double precision|float8|binary_double)$'           { return 'float' }
		'^(real|float4|binary_float)$'                                     { return 'real' }
		'^(nvarchar|nchar|ntext|varchar|char|text|character varying|character|string|bpchar|varchar2|nvarchar2|clob|nclob|tinytext|mediumtext|longtext|enum|set|citext)$' {
			if ($name -in 'char', 'character', 'bpchar', 'nchar') { return 'nchar' }
			if ($name -in 'varchar', 'character varying', 'varchar2') { return 'varchar' }
			if ($name -in 'text', 'tinytext', 'mediumtext', 'longtext', 'clob', 'nclob', 'ntext', 'citext') { return 'nvarchar' }
			return 'nvarchar'
		}
		'^(date)$'                                                         { return 'date' }
		'^(time|time without time zone|time with time zone|timetz)$'       { return 'time' }
		'^(datetime|datetime2|smalldatetime|timestamp|timestamp without time zone|timestamp with time zone|timestamptz|timestamp_s|timestamp_ms|timestamp_ns)$' {
			if ($name -eq 'smalldatetime') { return 'smalldatetime' }
			if ($name -eq 'datetime') { return 'datetime' }
			return 'datetime2'
		}
		'^(datetimeoffset)$'                                               { return 'datetimeoffset' }
		'^(interval)$'                                                     { return 'nvarchar' }
		'^(uniqueidentifier|uuid|guid)$'                                   { return 'uniqueidentifier' }
		'^(varbinary|binary|blob|bytea|image|tinyblob|mediumblob|longblob|raw)$' { return 'varbinary' }
		'^(xml)$'                                                          { return 'xml' }
		'^(json|jsonb)$'                                                   { return 'json' }
		'^(rowversion)$'                                                   { return 'rowversion' }
		default                                                            { return $name }
	}
}
