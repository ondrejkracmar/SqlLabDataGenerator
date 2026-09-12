function Invoke-SldgDbQuery {
	<#
	.SYNOPSIS
		Runs a read-only query against a DbConnection and returns the rows as a DataTable.
	.DESCRIPTION
		Provider-agnostic replacement for the SqlDataAdapter/SqliteDataReader code the
		provider functions used to carry each: DbCommand + DbDataReader + DataTable.Load work
		on every ADO.NET driver PSSqlRepository can hand out. Parameters are bound by name
		('@name') through DbCommand.CreateParameter, so callers never interpolate values.
	.PARAMETER ConnectionInfo
		The SqlLabDataGenerator.Connection whose DbConnection runs the query.
	.PARAMETER Query
		The SQL text. Identifiers must already be quoted by the connection's dialect and
		parameters written with its placeholder ($dialect.ParameterPlaceholder('name')).
	.PARAMETER Parameter
		Optional hashtable of parameter name (without prefix) to value.
	.PARAMETER Transaction
		Optional DbTransaction to enlist the command in.
	.PARAMETER CommandTimeout
		Timeout in seconds. Defaults to the Database.SchemaTimeout setting.
	.OUTPUTS
		System.Data.DataTable
	#>
	[OutputType([System.Data.DataTable])]
	[CmdletBinding()]
	param (
		[Parameter(Mandatory)]
		[SqlLabDataGenerator.Connection]$ConnectionInfo,

		[Parameter(Mandatory)]
		[string]$Query,

		[hashtable]$Parameter,

		[System.Data.Common.DbTransaction]$Transaction,

		[int]$CommandTimeout = 0
	)

	if ($CommandTimeout -le 0) {
		$CommandTimeout = Get-PSFConfigValue -FullName 'SqlLabDataGenerator.Database.SchemaTimeout' -Fallback 120
	}

	$dialect = $ConnectionInfo.GetDialect()
	$cmd = $ConnectionInfo.DbConnection.CreateCommand()
	$reader = $null
	try {
		$cmd.CommandText = $Query
		$cmd.CommandTimeout = $CommandTimeout
		if ($Transaction) { $cmd.Transaction = $Transaction }
		if ($Parameter) {
			foreach ($name in $Parameter.Keys) {
				$p = $cmd.CreateParameter()
				$p.ParameterName = $dialect.ParameterName($name)
				$p.Value = if ($null -eq $Parameter[$name]) { [DBNull]::Value } else { $Parameter[$name] }
				[void]$cmd.Parameters.Add($p)
			}
		}

		$dataTable = New-Object System.Data.DataTable
		$reader = $cmd.ExecuteReader()
		$dataTable.Load($reader)
		# The comma keeps PowerShell from unrolling the table into its rows.
		, $dataTable
	}
	finally {
		if ($reader) { $reader.Dispose() }
		$cmd.Dispose()
	}
}
