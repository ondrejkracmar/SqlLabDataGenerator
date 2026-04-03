function Connect-SldgSqlite {
	<#
	.SYNOPSIS
		Opens a connection to a SQLite database file.
	#>
	[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSReviewUnusedParameter', 'ConnectionTimeout', Justification = 'Provider interface parameter')]
	[CmdletBinding()]
	param (
		[Parameter(Mandatory)]
		[string]$Database,

		[switch]$CreateIfNotExists,

		[int]$ConnectionTimeout = 30
	)

	# SQLite assemblies are loaded at module import via bin\assembly.ps1
	# Verify that a supported SQLite provider is available
	$assemblyLoaded = $false
	foreach ($typeName in @('Microsoft.Data.Sqlite.SqliteConnection', 'System.Data.SQLite.SQLiteConnection')) {
		try {
			if ([System.Type]::GetType($typeName, $false)) {
				$assemblyLoaded = $true
				break
			}
		}
		catch { $null = $_ }
	}

	if (-not $assemblyLoaded) {
		Stop-PSFFunction -Message ($script:strings.'Connect.Failed' -f 'SQLite', $Database, '', 'No SQLite ADO.NET provider found. Microsoft.Data.Sqlite assembly failed to load at module import.') -EnableException $true
	}

	# Resolve database path
	$dbPath = if ([System.IO.Path]::IsPathRooted($Database)) { $Database } else { Join-Path (Get-Location) $Database }
	$dbPath = [System.IO.Path]::GetFullPath($dbPath)

	# Security: block path traversal — resolved path must be under the starting directory
	$basePath = [System.IO.Path]::GetFullPath((Get-Location).Path)
	if (-not $basePath.EndsWith([System.IO.Path]::DirectorySeparatorChar)) {
		$basePath += [System.IO.Path]::DirectorySeparatorChar
	}
	if (-not $dbPath.StartsWith($basePath, [System.StringComparison]::OrdinalIgnoreCase)) {
		Stop-PSFFunction -Message ($script:strings.'Connect.Failed' -f 'SQLite', $Database, '', "Path traversal detected. Resolved path '$dbPath' is outside the working directory.") -EnableException $true
	}

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
	catch { $null = $_ }

	if (-not $connectionString) {
		# Fallback: use connection string builder pattern to prevent injection
		$connectionString = "Data Source=$([System.Uri]::EscapeDataString($dbPath) -replace '%5C','\' -replace '%3A',':' -replace '%2F','/')"
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
		Write-PSFMessage -Level Verbose -Message ($script:strings.'Connect.SQLite.Connected' -f $dbPath)
	}
	catch {
		Stop-PSFFunction -Message ($script:strings.'Connect.Failed' -f 'SQLite', $dbPath, '', $_) -EnableException $true -ErrorRecord $_
	}

	[SqlLabDataGenerator.Connection]@{
		DbConnection   = $connection
		ServerInstance = 'localhost'
		Database       = $dbPath
		Provider       = 'SQLite'
		ConnectedAt    = Get-Date
	}
}
