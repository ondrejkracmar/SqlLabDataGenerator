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

	# Database-first: let PSSqlRepository read the catalogue and emit one entity type per table
	# with a single-column primary key, registered as the provider's repository context. The
	# generator keeps its own schema readers for the metadata the import does not carry (check
	# constraints, keyless and composite-key tables), but reads and masking updates go through
	# the entities, and the caller gets [Customer]-style types for the connected database.
	# When nothing can be imported (empty database, only keyless tables) the empty context is
	# registered instead so the session still opens for raw SQL.
	$schemaImport = $null
	try {
		$schemaImport = Import-PSSqlRepositorySchema -ProviderName $providerInfo.Name @ConnectParameter -NoRegister -Confirm:$false -WarningAction SilentlyContinue -ErrorAction Stop
	}
	catch {
		Write-PSFMessage -Level Warning -String 'Connect.SchemaImportFailed' -StringValues $providerInfo.Name, $_.Exception.Message
	}

	$entityTypes = New-Object 'System.Collections.Generic.Dictionary[string,type]' ([System.StringComparer]::OrdinalIgnoreCase)
	if ($schemaImport -and $schemaImport.EntityTypes.Count -gt 0) {
		# Register the emitted types as the provider's context - the same registration the cmdlet
		# makes without -NoRegister, minus a second catalogue read.
		$providerDefinition = [PSSqlRepository.Core.Hosting.PSSqlRepositoryHost]::Current.Providers.GetProvider($providerInfo.Name)
		[PSSqlRepository.Core.Schema.DatabaseSchemaImporter]::Register($providerDefinition, $schemaImport)
		foreach ($table in $schemaImport.Imported) { $entityTypes[$table.FullName] = $table.EntityType }
		$skipped = @($schemaImport.Skipped)
		Write-PSFMessage -Level Verbose -String 'Connect.SchemaImported' -StringValues $providerInfo.Name, $schemaImport.Imported.Count, $skipped.Count, (($skipped | ForEach-Object { "$($_.FullName): $($_.SkipReason)" }) -join '; ')
	}
	else {
		if ($schemaImport) { Write-PSFMessage -Level Verbose -String 'Connect.SchemaImportSkipped' -StringValues $providerInfo.Name, "$($schemaImport.Tables.Count) table(s) seen, none with a single-column primary key" }
		Register-PSSqlRepositoryContext -ContextType ([SqlLabDataGenerator.Data.SldgSchemaContext]) -ProviderName $providerInfo.Name
	}

	$repository = $null
	$dbConnection = $null
	try {
		$repository = Connect-PSSqlRepository -ProviderName $providerInfo.Name @ConnectParameter -Confirm:$false -ErrorAction Stop
		if (-not $repository) {
			throw 'Connect-PSSqlRepository returned no session.'
		}

		# Session.Services is the session's DI scope with exactly one DbContext in it - the
		# imported DynamicEntityDbContext or the empty fallback context. EF Core's relational
		# facade hands out the driver's DbConnection.
		$context = $repository.Session.Services.GetService([Microsoft.EntityFrameworkCore.DbContext])
		if (-not $context) {
			throw 'The PSSqlRepository session does not expose a DbContext.'
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
		SchemaImport   = $schemaImport
		ConnectParameters = $ConnectParameter
		EntityTypes    = $entityTypes
	}
}
