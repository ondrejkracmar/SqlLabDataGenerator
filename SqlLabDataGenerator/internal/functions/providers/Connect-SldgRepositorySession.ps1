function Connect-SldgRepositorySession {
	<#
	.SYNOPSIS
		Opens a database session through PSSqlRepository and returns the raw connection.
	.DESCRIPTION
		The single place where this module talks to a database driver. It registers the
		module's empty repository context (SqlLabDataGenerator.Data.SldgSchemaContext) for the
		requested PSSqlRepository provider, calls Connect-PSSqlRepository with the supplied
		parameters, and pulls the provider-agnostic System.Data.Common.DbConnection out of the
		resulting EF Core session. Everything downstream - schema discovery, inserts, FK
		lookups - works against that DbConnection and the SqlDialect resolved for the provider,
		so any provider PSSqlRepository knows (SqlServer, Sqlite, DuckDB, installed extensions)
		works here without a driver of its own.

		Connect-PSSqlRepository publishes the session as PSSqlRepository's ambient session;
		Disconnect-SldgRepositorySession releases it again.
	.PARAMETER Provider
		PSSqlRepository provider name (Get-PSSqlRepositoryProvider).
	.PARAMETER ConnectParameter
		Hashtable splatted onto Connect-PSSqlRepository: the provider's own connect
		parameters (-Server/-Database, -Path, -ConnectionString, ...), -AuthMode, -Credential.
	.PARAMETER ServerInstance
		Display value for the connection object (host or 'localhost').
	.PARAMETER Database
		Display value for the connection object (database name or file path).
	.PARAMETER ConnectionTimeout
		Timeout in seconds applied while opening the raw DbConnection.
	#>
	[OutputType([SqlLabDataGenerator.Connection])]
	[CmdletBinding()]
	param (
		[Parameter(Mandatory)]
		[string]$Provider,

		[Parameter(Mandatory)]
		[hashtable]$ConnectParameter,

		[string]$ServerInstance = 'localhost',

		[string]$Database,

		[int]$ConnectionTimeout = 30
	)

	if (-not (Get-Command -Name Connect-PSSqlRepository -ErrorAction SilentlyContinue)) {
		Stop-PSFFunction -String 'Connect.PSSqlRepositoryMissing' -EnableException $true
	}

	$providerInfo = Get-PSSqlRepositoryProvider | Where-Object Name -eq $Provider | Select-Object -First 1
	if (-not $providerInfo) {
		$available = (Get-PSSqlRepositoryProvider | ForEach-Object Name | Sort-Object) -join ', '
		Stop-PSFFunction -String 'Provider.NotFound' -StringValues $Provider, $available -EnableException $true
	}

	# The empty context is what lets Connect-PSSqlRepository open a session for a database
	# whose schema this module has not seen yet. Registration is per provider and idempotent.
	Register-PSSqlRepositoryContext -ContextType ([SqlLabDataGenerator.Data.SldgSchemaContext]) -ProviderName $providerInfo.Name

	$repository = $null
	$dbConnection = $null
	try {
		$repository = Connect-PSSqlRepository -ProviderName $providerInfo.Name @ConnectParameter -Confirm:$false -ErrorAction Stop
		if (-not $repository) {
			throw 'Connect-PSSqlRepository returned no session.'
		}

		# Session.Services is the session's DI scope; the context registered above is the
		# only DbContext in it. EF Core's relational facade hands out the driver's DbConnection.
		$context = $repository.Session.Services.GetService([SqlLabDataGenerator.Data.SldgSchemaContext])
		if (-not $context) {
			throw 'The PSSqlRepository session does not expose the SqlLabDataGenerator schema context.'
		}
		$dbConnection = [Microsoft.EntityFrameworkCore.RelationalDatabaseFacadeExtensions]::GetDbConnection($context.Database)

		if ($dbConnection.State -ne [System.Data.ConnectionState]::Open) {
			$openTask = $dbConnection.OpenAsync()
			if (-not $openTask.Wait([timespan]::FromSeconds([math]::Max(1, $ConnectionTimeout)))) {
				throw "Opening the connection did not complete within $ConnectionTimeout seconds."
			}
			if ($openTask.IsFaulted) { throw $openTask.Exception.GetBaseException() }
		}
	}
	catch {
		if ($repository) {
			try { Disconnect-PSSqlRepository -Confirm:$false -ErrorAction SilentlyContinue } catch { $null = $_ }
		}
		Stop-PSFFunction -String 'Connect.Failed' -StringValues $providerInfo.Name, $ServerInstance, $Database, $_.Exception.Message -EnableException $true -ErrorRecord $_
		return
	}

	$dialect = [SqlLabDataGenerator.Data.SqlDialect]::ForProvider($providerInfo.Name)
	Write-PSFMessage -Level Verbose -String 'Connect.SessionOpened' -StringValues $providerInfo.Name, $dialect.Name, $dbConnection.GetType().Name

	[SqlLabDataGenerator.Connection]@{
		DbConnection   = $dbConnection
		Repository     = $repository
		Dialect        = $dialect
		ServerInstance = $ServerInstance
		Database       = $Database
		Provider       = $providerInfo.Name
		ConnectedAt    = Get-Date
	}
}
