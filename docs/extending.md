# Extending SqlLabDataGenerator

How to extend the module with additional database engines, data transformers, locales, and generation rules.

> For basic usage, see [Getting Started](getting-started.md). For AI features, see [AI Configuration](ai-configuration.md).

---

## Table of Contents

- [Adding a Database Engine](#adding-a-database-engine)
- [Custom Transformer](#custom-transformer)
- [Custom Locale](#custom-locale)
- [Custom Generation Rules](#custom-generation-rules)

---

## Adding a Database Engine

SqlLabDataGenerator does not open database connections itself. `Connect-SldgDatabase` registers the
module's empty repository context with [PSSqlRepository](https://github.com/ondrejkracmar/PSSqlRepository),
calls `Connect-PSSqlRepository`, and works from then on with the raw `System.Data.Common.DbConnection`
of the session. That means **every PSSqlRepository provider is a SqlLabDataGenerator provider**:

```powershell
Get-PSSqlRepositoryProvider                     # SqlServer, Sqlite, DuckDB, ... whatever is installed
Install-PSSqlRepositoryExtension -FromModule PSSqlRepository.Providers.DuckDB -Trust
Connect-SldgDatabase -Provider DuckDB -ConnectionString 'Data Source=.\lab.duckdb'
```

What differs per engine is isolated in two places:

| Concern | Where | Built-in |
|---|---|---|
| SQL phrasing: identifier quoting, `TOP`/`LIMIT`, `COALESCE`, parameter placeholders, identity insert, constraint toggling, parameter cap | `SqlLabDataGenerator.Data.SqlDialect` (C#, `src/library/SqlLabDataGenerator/Data/SqlDialect.cs`) | `SqlServerDialect`, `SqliteDialect`, `DuckDbDialect`, `MySqlDialect`, `AnsiSqlDialect` (default) |
| Reading the catalog | a `GetSchema` function registered by `Register-SldgBuiltInProvider`, keyed by `SqlDialect.SchemaSource` | `Get-SldgSqlServerSchema` (`sys.*`), `Get-SldgSqliteSchema` (`PRAGMA`), `Get-SldgInformationSchema` (ANSI `INFORMATION_SCHEMA`) |

Reading and writing rows (`Read-SldgTableData`, `Write-SldgTableData`) are already generic: they
ask the dialect for quoting and placeholders and bind every value as a `DbParameter`.

### A new engine that speaks INFORMATION_SCHEMA and `@name` parameters

Nothing to do. Install the PSSqlRepository provider; the `AnsiSqlDialect` and the
`INFORMATION_SCHEMA` reader cover it. Types reported by the catalog are mapped onto the SQL Server
vocabulary the generators use by `ConvertTo-SldgCanonicalDataType` - extend its table if the engine
reports a name it does not know.

### A new engine with its own quoting or parameter syntax

Add a `SqlDialect` subclass and one `case` in `SqlDialect.ForProvider`:

```csharp
public sealed class PostgreSqlDialect : SqlDialect
{
    public override string Name => "PostgreSql";
    public override string SchemaSource => "InformationSchema";
    public override string QuoteIdentifier(string name) => "\"" + name.Replace("\"", "\"\"") + "\"";
    public override string DisableAllForeignKeysStatement => "SET session_replication_role = replica";
    public override string EnableAllForeignKeysStatement => "SET session_replication_role = DEFAULT";
}
```

Rebuild the library (`dotnet build src/library/SqlLabDataGenerator.sln -c Release`) and add a case
to `SqlDialectTests.cs`.

### A new engine whose catalog is not INFORMATION_SCHEMA

Write a `Get-Sldg<Engine>Schema` function that returns a `[SqlLabDataGenerator.SchemaModel]`
(the SQLite reader is the template: it builds `ColumnInfo`/`TableInfo` objects directly; the SQL
Server reader instead shapes DataTables and hands them to `ConvertTo-SldgSchemaModel`), give the
dialect a new `SchemaSource` name, and register the map in `Register-SldgBuiltInProvider`:

```powershell
Register-SldgProviderInternal -Name 'MyCatalog' -FunctionMap @{
    GetSchema = 'Get-SldgMyEngineSchema'
    WriteData = 'Write-SldgTableData'
    ReadData  = 'Read-SldgTableData'
}
```

### Rules

- Never quote identifiers by hand or branch on `$ConnectionInfo.Provider`; ask
  `$ConnectionInfo.GetDialect()`.
- Values travel as `DbParameter`s. `Invoke-SldgDbQuery` and `Write-SldgTableData` are the only
  places that build commands - reuse them.
- Add an integration test under `src/tests/functions/integration/` that skips (with a reason)
  when the provider is not installed; see `DuckDBIntegration.Tests.ps1`.

---

## Custom Transformer

A transformer converts generated `DataTable` data into a specific output format. Built-in transformers: `EntraIdUser`, `EntraIdGroup`.

### Writing a Transform Function

```powershell
function ConvertTo-MyFormat {
    param (
        [Parameter(Mandatory)]
        [System.Data.DataTable]$Data
    )

    foreach ($row in $Data.Rows) {
        [PSCustomObject]@{
            PSTypeName = 'MyApp.User'
            FullName   = "$($row['FirstName']) $($row['LastName'])"
            Email      = $row['Email']
            Department = $row['Department']
            CreatedAt  = Get-Date -Format 'yyyy-MM-ddTHH:mm:ssZ'
        }
    }
}
```

### Registration

```powershell
Register-SldgTransformer -Name 'MyFormat' `
    -Description 'Converts generated data to MyApp user format' `
    -TransformFunction 'ConvertTo-MyFormat' `
    -RequiredSemanticTypes @('FirstName', 'LastName', 'Email') `
    -OutputType 'MyApp.User'
```

### Usage

```powershell
$result = Invoke-SldgDataGeneration -Plan $plan -NoInsert -PassThru

Export-SldgTransformedData -Data $result.Tables[0].DataTable `
    -Transformer 'MyFormat' -OutputPath './users.json'
```

### Column Auto-Detection

The built-in transformers use column name pattern matching to map DataTable columns to output properties. You can follow the same approach:

```powershell
function ConvertTo-MyFormat {
    param ([System.Data.DataTable]$Data)

    $emailCol = $Data.Columns | Where-Object { $_.ColumnName -match 'email|mail' } | Select-Object -First 1
    $nameCol  = $Data.Columns | Where-Object { $_.ColumnName -match 'name|display' } | Select-Object -First 1

    foreach ($row in $Data.Rows) {
        [PSCustomObject]@{
            Email = if ($emailCol) { $row[$emailCol.ColumnName] } else { '' }
            Name  = if ($nameCol)  { $row[$nameCol.ColumnName] }  else { '' }
        }
    }
}
```

---

## Custom Locale

Locales provide culture-specific data pools (names, addresses, phone formats) for realistic localized data. Built-in locales: `en-US`, `cs-CZ`.

### Option 1: Manual Data

```powershell
Register-SldgLocale -Name 'sk-SK' -Data @{
    MaleNames       = @('Jan', 'Peter', 'Martin', 'Jozef', 'Pavol')
    FemaleNames     = @('Maria', 'Jana', 'Eva', 'Anna', 'Zuzana')
    LastNames       = @('Novak', 'Horvath', 'Kovac', 'Balaz', 'Toth')
    StreetNames     = @('Hlavna', 'Stefanikova', 'Hviezdoslavova')
    StreetTypes     = @('ulica', 'namestie', 'cesta')
    Locations       = @('Bratislava', 'Kosice', 'Presov', 'Zilina')
    Countries       = @('Slovakia', 'Slovensko')
    EmailDomains    = @('email.sk', 'centrum.sk', 'azet.sk')
    PhoneFormat     = '+421 9## ### ###'
    CompanyPrefixes = @('Slovenska', 'Vychodna', 'Zapadna')
    CompanyCores    = @('Technika', 'Energetika', 'Stavba')
    CompanySuffixes = @('s.r.o.', 'a.s.', 'k.s.')
    Departments     = @('IT', 'Financie', 'Marketing', 'Vyroba')
    JobTitles       = @('Riaditel', 'Manazer', 'Analytik', 'Vyvojar')
    Industries      = @('Automobilovy priemysel', 'IT', 'Energetika')
}
```

### Option 2: AI-Generated

```powershell
Register-SldgLocale -Name 'ja-JP' -UseAI -PoolSize 50
```

### Option 3: Mixed

```powershell
Register-SldgLocale -Name 'business-mix' -MixFrom @{
    PersonNames = 'cs-CZ'
    Addresses   = 'de-DE'
    Companies   = 'en-US'
    PhoneFormat = 'cs-CZ'
}
```

### Required Data Keys

| Key | Type | Description |
|---|---|---|
| `MaleNames` | `string[]` | Male first names |
| `FemaleNames` | `string[]` | Female first names |
| `LastNames` | `string[]` | Family names |
| `StreetNames` | `string[]` | Street names |
| `StreetTypes` | `string[]` | Street type suffixes (St, Ave, ul.) |
| `Locations` | `string[]` | City/town names |
| `Countries` | `string[]` | Country names |
| `EmailDomains` | `string[]` | Email domain names |
| `PhoneFormat` | `string` | Phone format pattern (`#` = digit) |
| `CompanyPrefixes` | `string[]` | Company name prefixes |
| `CompanyCores` | `string[]` | Company name core words |
| `CompanySuffixes` | `string[]` | Company legal suffixes (Inc, s.r.o.) |
| `Departments` | `string[]` | Department names |
| `JobTitles` | `string[]` | Job title names |
| `Industries` | `string[]` | Industry sector names |

---

## Custom Generation Rules

Override default generation for specific columns using `Set-SldgGenerationRule`. Rules are stored in the plan and applied during `Invoke-SldgDataGeneration`.

### Basic Rules

```powershell
# Value list — pick random value from the list
Set-SldgGenerationRule -Plan $plan -TableName 'dbo.Order' -ColumnName 'Status' `
    -ValueList @('Pending', 'Shipped', 'Delivered', 'Cancelled')

# Static value — same for every row
Set-SldgGenerationRule -Plan $plan -TableName 'dbo.Order' -ColumnName 'Currency' `
    -StaticValue 'CZK'

# ScriptBlock — custom logic
Set-SldgGenerationRule -Plan $plan -TableName 'dbo.Product' -ColumnName 'SKU' `
    -ScriptBlock { "PRD-{0:D6}" -f (Get-Random -Minimum 1 -Maximum 999999) }
```

### AI-Powered Rules

Guide AI generation with hints and cross-column dependencies:

```powershell
# AI hint — tell AI what to generate
Set-SldgGenerationRule -Plan $plan -TableName 'dbo.Project' `
    -ColumnName 'Settings' -Generator 'Json' `
    -AIGenerationHint 'Project settings with theme, notification preferences, and sprint configuration'

# Context-dependent JSON — structure varies based on another column
Set-SldgGenerationRule -Plan $plan -TableName 'dbo.UsageReport' `
    -ColumnName 'ReportData' -Generator 'Json' `
    -AIGenerationHint 'M365 usage report data. Structure varies by report type.' `
    -CrossColumnDependency 'ReportType'

# Value examples — guide AI output format
Set-SldgGenerationRule -Plan $plan -TableName 'dbo.Config' `
    -ColumnName 'SettingsJson' -Generator 'Json' `
    -AIGenerationHint 'Application configuration' `
    -ValueExamples @(
        '{"theme":"dark","language":"cs","notifications":{"email":true}}',
        '{"theme":"light","language":"en","notifications":{"email":false}}'
    )
```

| Parameter | Purpose |
|---|---|
| `-AIGenerationHint` | Free-text instructions for AI about what to generate |
| `-CrossColumnDependency` | Column whose value drives structure variation (auto-reorders columns) |
| `-ValueExamples` | Example documents showing expected format (AI uses as reference) |

Rules take priority over semantic type-based generation. For a full walkthrough with JSON/XML columns, see [AI Configuration — JSON and XML Columns](ai-configuration.md#json-and-xml-column-configuration).