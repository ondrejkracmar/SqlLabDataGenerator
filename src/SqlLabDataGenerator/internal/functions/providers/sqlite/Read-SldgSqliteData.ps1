function Read-SldgSqliteData {
	<#
	.SYNOPSIS
		Reads existing data from a SQLite table (for masking mode).
	#>
	[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSReviewUnusedParameter', 'SchemaName', Justification = 'Provider interface parameter')]
	[CmdletBinding()]
	param (
		[Parameter(Mandatory)]
		$ConnectionInfo,

		[Parameter(Mandatory)]
		[string]$SchemaName,

		[Parameter(Mandatory)]
		[string]$TableName,

		[string[]]$ColumnFilter,

		[int]$TopN = 0
	)

	$conn = $ConnectionInfo.DbConnection

	$colExpr = if ($ColumnFilter) {
		($ColumnFilter | ForEach-Object { "[$($_ -replace '\]', ']]')]" }) -join ', '
	} else { '*' }

	$sql = "SELECT $colExpr FROM [$TableName]"
	if ($TopN -gt 0) { $sql += " LIMIT $TopN" }

	$cmd = $conn.CreateCommand()
	$cmd.CommandText = $sql

	$dataTable = New-Object System.Data.DataTable
	try {
		$reader = $cmd.ExecuteReader()
		$dataTable.Load($reader)
	}
	finally {
		if ($reader) { $reader.Close(); $reader.Dispose() }
		$cmd.Dispose()
	}

	$dataTable
}
