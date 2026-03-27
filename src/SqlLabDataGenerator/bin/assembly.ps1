# Load SqlLabDataGenerator assembly
try {
    if ($PSVersionTable.PSVersion.Major -ge 5) {
        Add-Type -Path "$script:ModuleRoot\bin\SqlLabDataGenerator.dll" -ErrorAction Stop
    }
    else {
        Add-Type -Path "$script:ModuleRoot\bin\PS4\SqlLabDataGenerator.dll" -ErrorAction Stop
    }
}
catch {
    Write-Warning "Failed to load SqlLabDataGenerator Assembly! Unable to import module."
    throw
}
try {
    Update-TypeData -AppendPath "$script:ModuleRoot\types\SqlLabDataGenerator.Types.ps1xml" -ErrorAction Stop
}
catch {
    Write-Warning "Failed to load SqlLabDataGenerator type extensions! Unable to import module."
    throw
}

# Load Microsoft.Data.SqlClient assembly for SQL Server provider
try {
    $sqlClientPath = "$script:ModuleRoot\bin\Microsoft.Data.SqlClient.dll"
    if (Test-Path $sqlClientPath) {
        Add-Type -Path $sqlClientPath -ErrorAction Stop
    }
}
catch {
    Write-Warning "Failed to load Microsoft.Data.SqlClient assembly! SQL Server provider will not be available."
}

# Load SQLite assemblies from the module bin directory
# Dependencies must be loaded in order: core → provider → batteries → main
try {
    $sqliteDeps = @(
        'SQLitePCLRaw.core.dll',
        'SQLitePCLRaw.provider.e_sqlite3.dll',
        'SQLitePCLRaw.batteries_v2.dll',
        'Microsoft.Data.Sqlite.dll'
    )
    foreach ($dll in $sqliteDeps) {
        $dllPath = "$script:ModuleRoot\bin\$dll"
        if (Test-Path $dllPath) {
            Add-Type -Path $dllPath -ErrorAction Stop
        }
        else {
            Write-Warning "SQLite dependency '$dll' not found at '$dllPath'. SQLite provider may not work correctly."
        }
    }
    # Initialize the native SQLite provider
    if ([System.Type]::GetType('SQLitePCL.Batteries_V2', $false)) {
        [SQLitePCL.Batteries_V2]::Init()
    }
}
catch {
    Write-Warning "Failed to load SQLite assemblies! SQLite provider will not be available."
}