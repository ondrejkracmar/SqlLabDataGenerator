function Connect-SldgDatabase {
	<#
	.SYNOPSIS
		Connects to a database for schema discovery and data generation.

	.DESCRIPTION
		Opens a connection through PSSqlRepository and stores it as the active connection
		for the other Sldg commands. Any provider PSSqlRepository knows can be used:
		SqlServer and Sqlite ship with it, DuckDB and further engines come as
		PSSqlRepository extensions (Install-PSSqlRepositoryExtension). Run
		Get-PSSqlRepositoryProvider to see what is available.

		Three ways to say where to connect:

		- Server set: -ServerInstance and -Database, optionally -Credential for
		  SQL authentication and -TrustServerCertificate. Integrated authentication is used
		  when no credential is given.
		- File set (default): -Provider Sqlite (or another file-based engine) with -Database
		  pointing at the database file.
		- ConnectionString set: -ConnectionString for anything the provider accepts; add
		  -Credential when the string carries no credentials.

		Provider-specific switches that this command does not surface can be passed through
		-ProviderParameter as a hashtable; they are splatted onto Connect-PSSqlRepository.

		The session becomes PSSqlRepository's ambient session as well, so
		Get-PSSqlRepositorySession shows it and Disconnect-SldgDatabase releases it.

	.PARAMETER ServerInstance
		The server instance to connect to (e.g., 'localhost', 'server\instance', 'server,port').

	.PARAMETER Database
		The database name (Server set) or the database file path (File set).

	.PARAMETER ConnectionString
		A full provider connection string. Wins over -ServerInstance/-Database.

	.PARAMETER Provider
		The PSSqlRepository provider name. Default is 'SqlServer'. Tab-completes from the
		providers PSSqlRepository has loaded.

	.PARAMETER Credential
		SQL authentication credentials. If not specified, integrated authentication is used
		(providers that support it).

	.PARAMETER TrustServerCertificate
		Skip TLS certificate validation (dev/test servers with self-signed certificates).

	.PARAMETER ConnectionTimeout
		Connection timeout in seconds. Default is 30.

	.PARAMETER CreateIfNotExists
		File set: create the database file when it does not exist yet. Without it a missing
		file is an error, so a typo in the path cannot silently produce an empty database.

	.PARAMETER ProviderParameter
		Additional parameters for Connect-PSSqlRepository (for example
		@{ DisableRetryOnFailure = $true } on SqlServer, or the connect parameters of an
		installed provider extension).

	.EXAMPLE
		PS C:\> Connect-SldgDatabase -ServerInstance 'localhost' -Database 'AdventureWorks'

		Connects to AdventureWorks on localhost using integrated authentication.

	.EXAMPLE
		PS C:\> $cred = Get-Credential
		PS C:\> Connect-SldgDatabase -ServerInstance 'dbserver\SQLEXPRESS' -Database 'TestDB' -Credential $cred -TrustServerCertificate

		Connects using SQL authentication.

	.EXAMPLE
		PS C:\> Connect-SldgDatabase -Provider Sqlite -Database 'C:\Data\mydb.sqlite'

		Connects to a SQLite database file.

	.EXAMPLE
		PS C:\> Connect-SldgDatabase -Provider DuckDB -ConnectionString 'Data Source=C:\Data\lab.duckdb'

		Connects to a DuckDB file through the PSSqlRepository DuckDB provider.
	#>
	[OutputType([SqlLabDataGenerator.Connection])]
	[CmdletBinding(DefaultParameterSetName = 'File')]
	param (
		[Parameter(Mandatory, ParameterSetName = 'Server')]
		[ValidateNotNullOrEmpty()]
		[string]$ServerInstance,

		[Parameter(Mandatory, ParameterSetName = 'Server')]
		[Parameter(Mandatory, ParameterSetName = 'File')]
		[ValidateNotNullOrEmpty()]
		[string]$Database,

		[Parameter(Mandatory, ParameterSetName = 'ConnectionString')]
		[ValidateNotNullOrEmpty()]
		[string]$ConnectionString,

		[Parameter(ParameterSetName = 'Server')]
		[Parameter(Mandatory, ParameterSetName = 'File')]
		[Parameter(ParameterSetName = 'ConnectionString')]
		[ValidateNotNullOrEmpty()]
		[string]$Provider = 'SqlServer',

		[PSCredential]$Credential,

		[switch]$TrustServerCertificate,

		[ValidateRange(1, 3600)]
		[int]$ConnectionTimeout = 30,

		[Parameter(ParameterSetName = 'File')]
		[switch]$CreateIfNotExists,

		[hashtable]$ProviderParameter
	)

	$connectParams = @{}
	if ($ProviderParameter) { foreach ($key in $ProviderParameter.Keys) { $connectParams[$key] = $ProviderParameter[$key] } }

	$dialect = [SqlLabDataGenerator.Data.SqlDialect]::ForProvider($Provider)
	$displayServer = 'localhost'
	$displayDatabase = $Database

	switch ($PSCmdlet.ParameterSetName) {
		'Server' {
			$displayServer = $ServerInstance
			$connectParams['Server'] = $ServerInstance
			$connectParams['Database'] = $Database
			if ($TrustServerCertificate) { $connectParams['TrustServerCertificate'] = $true }
			if ($Credential) {
				$connectParams['AuthMode'] = 'UserPassword'
				$connectParams['Credential'] = $Credential
				Write-PSFMessage -Level Verbose -String 'Connect.SqlServer.CredentialWarning'
			}
			elseif ($dialect.Name -eq 'SqlServer') {
				$connectParams['AuthMode'] = 'IntegratedSecurity'
			}
		}
		'File' {
			$dbPath = if ([System.IO.Path]::IsPathRooted($Database)) { $Database } else { Join-Path (Get-Location) $Database }
			$dbPath = [System.IO.Path]::GetFullPath($dbPath)
			if (-not $CreateIfNotExists -and -not (Test-Path -LiteralPath $dbPath -PathType Leaf)) {
				Stop-PSFFunction -String 'Connect.Failed' -StringValues $Provider, $displayServer, $dbPath, 'Database file not found. Use -CreateIfNotExists to create a new database.' -EnableException $true
			}
			$displayDatabase = $dbPath
			$connectParams['Path'] = $dbPath
		}
		'ConnectionString' {
			$connectParams['ConnectionString'] = $ConnectionString
			if ($Credential) {
				$connectParams['AuthMode'] = 'UserPassword'
				$connectParams['Credential'] = $Credential
			}
			$displayDatabase = if ($ConnectionString -match '(?i)(?:Initial Catalog|Database|Data Source)\s*=\s*([^;]+)') { $Matches[1].Trim() } else { $Provider }
			if ($ConnectionString -match '(?i)(?:Server|Data Source|Host)\s*=\s*([^;]+)') { $displayServer = $Matches[1].Trim() }
		}
	}

	Write-PSFMessage -Level Host -String 'Connect.Connecting' -StringValues $Provider, $displayDatabase, $displayServer

	$connectionInfo = Connect-SldgRepositorySession -Provider $Provider -ConnectParameter $connectParams `
		-ServerInstance $displayServer -Database $displayDatabase -ConnectionTimeout $ConnectionTimeout

	# Validate connection is alive before storing
	if (-not $connectionInfo.IsOpen) {
		Stop-PSFFunction -String 'Connect.Failed' -StringValues $Provider, $displayServer, $displayDatabase, 'Connection is not in Open state after connect.' -EnableException $true
	}

	# Store as active connection
	$script:SldgState.ActiveConnection = $connectionInfo
	$script:SldgState.ActiveProvider = $connectionInfo.Provider

	Write-PSFMessage -Level Host -String 'Connect.Success' -StringValues $connectionInfo.Provider, $displayServer, $displayDatabase

	$connectionInfo
}
