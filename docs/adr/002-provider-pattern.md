# ADR-002: Provider-Based Database Abstraction

## Status
Accepted

## Date
2025-01-01

## Context
The module needs to support multiple database engines (SQL Server, SQLite) with engine-specific connection, schema discovery, and data writing logic, while presenting a unified API to users.

## Decision
Implement a provider pattern where each database engine registers a set of function mappings:

```powershell
Register-SldgProviderInternal -Name 'SqlServer' -FunctionMap @{
    Connect    = 'Connect-SldgSqlServer'
    GetSchema  = 'Get-SldgSqlServerSchema'
    WriteData  = 'Write-SldgSqlServerData'
    ReadData   = 'Read-SldgSqlServerData'
    Disconnect = 'Disconnect-SldgSqlServer'
}
```

Public commands (`Connect-SldgDatabase`, `Invoke-SldgDataGeneration`) dispatch to the active provider's functions via `& $provider.FunctionMap.WriteData`.

Providers are stored in `$script:SldgState.Providers` and the active connection in `$script:SldgState.ActiveConnection`.

## Consequences
- **Positive**: Adding a new database engine requires only implementing 5 functions and calling `Register-SldgProvider`.
- **Positive**: All public commands are engine-agnostic — users don't need to know the underlying provider API.
- **Negative**: Provider functions must adhere to implicit interface contracts (parameter names, return types) without compile-time enforcement.
- **Negative**: Engine-specific features (e.g., SqlBulkCopy for SQL Server) are hidden behind the abstraction.
