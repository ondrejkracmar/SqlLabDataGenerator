function Read-SldgSqlServerData {
	<#
	.SYNOPSIS
		Reads existing data from a SQL Server table (used for masking mode).
	#>
	[CmdletBinding()]
	param (
		[Parameter(Mandatory)]
		$ConnectionInfo,

		[Parameter(Mandatory)]
		[string]$SchemaName,

		[Parameter(Mandatory)]
		[string]$TableName,

		[int]$TopN = 0
	)

	$conn = $ConnectionInfo.Connection
	$safeName = Get-SldgSafeSqlName -SchemaName $SchemaName -TableName $TableName

	$query = if ($TopN -gt 0) {
		"SELECT TOP ($TopN) * FROM $safeName"
	}
	else {
		"SELECT * FROM $safeName"
	}

	$cmd = $conn.CreateCommand()
	$cmd.CommandText = $query
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

	Write-PSFMessage -Level Verbose -Message "Read $($dataTable.Rows.Count) rows from $safeName"
	$dataTable
}
