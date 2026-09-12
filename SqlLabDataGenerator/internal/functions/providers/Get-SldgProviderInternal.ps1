function Get-SldgProviderInternal {
	<#
	.SYNOPSIS
		Resolves the schema/data function map for a connection or provider name.
	.DESCRIPTION
		Connections come from PSSqlRepository, which can hand out any number of providers
		(SqlServer, Sqlite, DuckDB, installed extensions). What this module varies per engine
		is only how the catalog is read and how rows are written, and that is keyed by the
		dialect's SchemaSource - 'SqlServer', 'Sqlite' or 'InformationSchema' - not by the
		provider name. Any provider without a dedicated reader resolves to the
		INFORMATION_SCHEMA map.
	.PARAMETER Name
		A PSSqlRepository provider name ('SqlServer', 'DuckDB', ...) or a dialect schema
		source ('InformationSchema'). Omit to list every registered map.
	.PARAMETER ConnectionInfo
		A SqlLabDataGenerator.Connection; its dialect selects the map.
	#>
	[CmdletBinding()]
	param (
		[string]$Name,

		[SqlLabDataGenerator.Connection]$ConnectionInfo
	)

	$key = $null
	if ($ConnectionInfo) {
		$key = $ConnectionInfo.GetDialect().SchemaSource
	}
	elseif ($Name) {
		$key = if ($script:SldgState.Providers.ContainsKey($Name)) { $Name } else { [SqlLabDataGenerator.Data.SqlDialect]::ForProvider($Name).SchemaSource }
	}

	if ($key) {
		$provider = $script:SldgState.Providers[$key]
		if (-not $provider) {
			$available = ($script:SldgState.Providers.Keys | Sort-Object) -join ', '
			Stop-PSFFunction -String 'Provider.NotFound' -StringValues $key, $available -EnableException $true
		}
		return $provider
	}

	$script:SldgState.Providers.Values
}
