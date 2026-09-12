# Selects the compiled library for the running .NET runtime.
# PowerShell 7.4/7.5 run on .NET 8/9 -> net8.0; PowerShell 7.6+ runs on .NET 10 -> net10.0.
# The same rule PSSqlRepository applies, so the two modules always agree on the framework
# and SqlLabDataGenerator.dll's EF Core reference resolves to the copy PSSqlRepository loaded.
$script:SqlLabDataGeneratorFramework = if ([System.Environment]::Version.Major -ge 10) { 'net10.0' } else { 'net8.0' }

try {
    Add-Type -Path "$script:ModuleRoot\bin\$script:SqlLabDataGeneratorFramework\SqlLabDataGenerator.dll" -ErrorAction Stop
}
catch {
    Write-Warning "Failed to load SqlLabDataGenerator Assembly for '$script:SqlLabDataGeneratorFramework'! Unable to import module."
    throw
}
try {
    Update-TypeData -AppendPath "$script:ModuleRoot\types\SqlLabDataGenerator.Types.ps1xml" -ErrorAction Stop
}
catch {
    Write-Warning "Failed to load SqlLabDataGenerator type extensions! Unable to import module."
    throw
}

# Database drivers are NOT loaded here any more. Every connection is opened through
# PSSqlRepository (a required module), which ships and loads Microsoft.Data.SqlClient,
# Microsoft.Data.Sqlite, DuckDB and any installed provider extension itself.
