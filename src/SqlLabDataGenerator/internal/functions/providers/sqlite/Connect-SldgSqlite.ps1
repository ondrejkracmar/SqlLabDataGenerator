function Connect-SldgSqlite {
	<#
	.SYNOPSIS
		Opens a connection to a SQLite database file.
	#>
	[CmdletBinding()]
	param (
		[Parameter(Mandatory)]
		[string]$Database,

		[switch]$CreateIfNotExists,

		[int]$ConnectionTimeout = 30
	)

	# SQLite uses Microsoft.Data.Sqlite (modern) or System.Data.SQLite
	# Try to find available assembly
	$assemblyLoaded = $false
	foreach ($typeName in @('Microsoft.Data.Sqlite.SqliteConnection', 'System.Data.SQLite.SQLiteConnection')) {
		try {
			$null = [System.Type]::GetType($typeName, $false)
			if ([System.Type]::GetType($typeName, $false)) {
				$assemblyLoaded = $true
				break
			}
		}
		catch { }
	}

	if (-not $assemblyLoaded) {
		# Try loading from NuGet package cache or module bin
		$sqliteDll = Join-Path $PSScriptRoot '..\..\..\..\bin\Microsoft.Data.Sqlite.dll'
		if (Test-Path $sqliteDll) {
			Add-Type -Path $sqliteDll
			$assemblyLoaded = $true
		}
	}

	# Resolve database path
	$dbPath = if ([System.IO.Path]::IsPathRooted($Database)) { $Database } else { Join-Path (Get-Location) $Database }

	if (-not $CreateIfNotExists -and -not (Test-Path $dbPath)) {
		Stop-PSFFunction -Message ($script:strings.'Connect.Failed' -f 'SQLite', $dbPath, '', 'Database file not found. Use -CreateIfNotExists to create a new database.') -EnableException $true
	}

	# Build connection string safely — avoid string interpolation to prevent injection
	$connectionString = $null
	try {
		if ([System.Type]::GetType('Microsoft.Data.Sqlite.SqliteConnectionStringBuilder', $false)) {
			$builder = New-Object Microsoft.Data.Sqlite.SqliteConnectionStringBuilder
			$builder.DataSource = $dbPath
			$connectionString = $builder.ToString()
		}
	}
	catch { }

	if (-not $connectionString) {
		# Fallback: sanitize path to prevent connection-string parameter injection
		$sanitizedPath = $dbPath -replace '[;=]', ''
		$connectionString = "Data Source=$sanitizedPath"
	}

	try {
		# Try Microsoft.Data.Sqlite first, then System.Data.SQLite, then ADO.NET generic
		$connection = $null
		if ([System.Type]::GetType('Microsoft.Data.Sqlite.SqliteConnection', $false)) {
			$connection = New-Object Microsoft.Data.Sqlite.SqliteConnection($connectionString)
		}
		elseif ([System.Type]::GetType('System.Data.SQLite.SQLiteConnection', $false)) {
			$connection = New-Object System.Data.SQLite.SQLiteConnection($connectionString)
		}
		else {
			# Fallback: use generic ADO.NET with SQLite connection string
			# Requires System.Data.SQLite or Microsoft.Data.Sqlite in GAC or path
			Stop-PSFFunction -Message ($script:strings.'Connect.Failed' -f 'SQLite', $dbPath, '', 'No SQLite ADO.NET provider found. Install Microsoft.Data.Sqlite NuGet package or System.Data.SQLite.') -EnableException $true
		}

		$connection.Open()
		Write-PSFMessage -Level Verbose -Message "Connected to SQLite database '$dbPath'"
	}
	catch {
		Stop-PSFFunction -Message ($script:strings.'Connect.Failed' -f 'SQLite', $dbPath, '', $_) -EnableException $true -ErrorRecord $_
	}

	[PSCustomObject]@{
		PSTypeName     = 'SqlLabDataGenerator.Connection'
		Connection     = $connection
		ServerInstance = 'localhost'
		Database       = $dbPath
		Provider       = 'SQLite'
		ConnectedAt    = Get-Date
	}
}
