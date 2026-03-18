function Get-SldgDatabaseSchema {
	<#
	.SYNOPSIS
		Discovers and returns the complete schema of the connected database.

	.DESCRIPTION
		Reads tables, columns, data types, primary keys, foreign keys, unique constraints,
		and check constraints from the connected database. Returns a structured SchemaModel
		object that serves as the foundation for data generation.

	.PARAMETER SchemaFilter
		Optional list of schema names to include (e.g., 'dbo', 'Sales'). If not specified, all schemas are included.

	.PARAMETER TableFilter
		Optional list of table names to include. If not specified, all tables are included.

	.PARAMETER ConnectionInfo
		Explicit connection to use. If not specified, uses the active connection from Connect-SldgDatabase.

	.EXAMPLE
		PS C:\> $schema = Get-SldgDatabaseSchema

		Discovers all tables in the connected database.

	.EXAMPLE
		PS C:\> $schema = Get-SldgDatabaseSchema -SchemaFilter 'dbo', 'Sales' -TableFilter 'Customer', 'Order'

		Discovers only specific tables.
	#>
	[CmdletBinding()]
	param (
		[string[]]$SchemaFilter,

		[string[]]$TableFilter,

		$ConnectionInfo
	)

	if (-not $ConnectionInfo) { $ConnectionInfo = $script:SldgState.ActiveConnection }
	if (-not $ConnectionInfo) {
		Stop-PSFFunction -Message "No active database connection. Use Connect-SldgDatabase first." -EnableException $true
	}

	# Connection staleness check
	if ($ConnectionInfo.Connection -and $ConnectionInfo.Connection.State -ne 'Open') {
		Stop-PSFFunction -Message ($script:strings.'Connect.HealthCheckFailed' -f $ConnectionInfo.Provider, $ConnectionInfo.ServerInstance, $ConnectionInfo.Database) -EnableException $true
	}

	$provider = Get-SldgProviderInternal -Name $ConnectionInfo.Provider

	Write-PSFMessage -Level Host -Message ($script:strings.'Schema.Discovering' -f $ConnectionInfo.Database)

	$params = @{ ConnectionInfo = $ConnectionInfo }
	if ($SchemaFilter) { $params['SchemaFilter'] = $SchemaFilter }
	if ($TableFilter) { $params['TableFilter'] = $TableFilter }

	$schemaModel = & $provider.FunctionMap.GetSchema @params

	if ($schemaModel.TableCount -eq 0) {
		Write-PSFMessage -Level Warning -Message $script:strings.'Schema.NoTables'
	}
	else {
		$totalColumns = ($schemaModel.Tables | Measure-Object -Property ColumnCount -Sum).Sum
		$totalFKs = ($schemaModel.Tables | ForEach-Object { $_.ForeignKeys.Count } | Measure-Object -Sum).Sum
		Write-PSFMessage -Level Host -Message ($script:strings.'Schema.Found' -f $schemaModel.TableCount, $totalColumns)
		Write-PSFMessage -Level Verbose -Message ($script:strings.'Schema.ForeignKeys' -f $totalFKs)
	}

	$schemaModel
}
