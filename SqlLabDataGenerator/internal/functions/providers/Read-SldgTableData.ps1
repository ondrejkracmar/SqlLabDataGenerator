function Read-SldgTableData {
	<#
	.SYNOPSIS
		Reads existing rows from a table (masking mode, AI sample data).
	.DESCRIPTION
		Works on every provider: the dialect quotes the names and phrases the row cap
		(TOP on SQL Server, LIMIT elsewhere); the rows come back through Invoke-SldgDbQuery.
	.PARAMETER ConnectionInfo
		The active SqlLabDataGenerator.Connection.
	.PARAMETER SchemaName
		Schema of the table (ignored by engines without schemas).
	.PARAMETER TableName
		The table to read.
	.PARAMETER ColumnFilter
		Optional subset of columns to select.
	.PARAMETER TopN
		Maximum number of rows; 0 reads the whole table.
	.PARAMETER Transaction
		Optional DbTransaction to read inside (required by SQLite while one is open on the connection).
	#>
	[OutputType([System.Data.DataTable])]
	[CmdletBinding()]
	param (
		[Parameter(Mandatory)]
		[SqlLabDataGenerator.Connection]$ConnectionInfo,

		[Parameter(Mandatory)]
		[string]$SchemaName,

		[Parameter(Mandatory)]
		[string]$TableName,

		[string[]]$ColumnFilter,

		[int]$TopN = 0,

		[System.Data.Common.DbTransaction]$Transaction
	)

	$dialect = $ConnectionInfo.GetDialect()
	$safeTable = $dialect.QualifiedName($SchemaName, $TableName)
	$columns = if ($ColumnFilter) { ($ColumnFilter | ForEach-Object { $dialect.QuoteIdentifier($_) }) -join ', ' } else { '*' }

	$query = $dialect.SelectLimited($columns, $safeTable, $TopN)
	$queryParams = @{ ConnectionInfo = $ConnectionInfo; Query = $query }
	if ($Transaction) { $queryParams['Transaction'] = $Transaction }
	$dataTable = Invoke-SldgDbQuery @queryParams

	Write-PSFMessage -Level Verbose -String 'Schema.SqlServer.Read' -StringValues $dataTable.Rows.Count, $safeTable
	, $dataTable
}
