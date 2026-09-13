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

	# Tables PSSqlRepository imported on connect are read through their entity type. An explicit
	# DbTransaction keeps the SQL path: the entity query runs on the EF context, which cannot see a
	# transaction opened on the raw connection (SQLite refuses to read outside it).
	if (-not $Transaction) {
		$binding = Get-SldgEntityBinding -ConnectionInfo $ConnectionInfo -SchemaName $SchemaName -TableName $TableName
		if ($binding) {
			$entityParams = @{ Binding = $binding; TopN = $TopN }
			if ($ColumnFilter) { $entityParams['ColumnFilter'] = $ColumnFilter }
			return , (Read-SldgEntityData @entityParams)
		}
		Write-PSFMessage -Level Debug -String 'Entity.ReadUnavailable' -StringValues "$SchemaName.$TableName"
	}

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
