# Extending SqlLabDataGenerator

How to extend the module with custom database providers, data transformers, locales, and generation rules.

> For basic usage, see [Getting Started](getting-started.md). For AI features, see [AI Configuration](ai-configuration.md).

---

## Table of Contents

- [Custom Database Provider](#custom-database-provider)
- [Custom Transformer](#custom-transformer)
- [Custom Locale](#custom-locale)
- [Custom Generation Rules](#custom-generation-rules)

---

## Custom Database Provider

A database provider teaches SqlLabDataGenerator how to connect, read schemas, write data, and disconnect from a specific database engine. Built-in providers: SQL Server, SQLite.

### Required Functions

Implement 5 functions:

#### 1. Connect

```powershell
function Connect-MyDatabase {
    param (
        [Parameter(Mandatory)][string]$Server,
        [Parameter(Mandatory)][string]$Database,
        [PSCredential]$Credential,
        [string]$ConnectionString
    )

    # Open connection and return a connection info object
    [SqlLabDataGenerator.Connection]@{
        Provider       = 'MyDatabase'
        DbConnection   = $conn
        ServerInstance = $Server
        Database       = $Database
    }
}
```

#### 2. GetSchema

```powershell
function Get-MyDatabaseSchema {
    param (
        [Parameter(Mandatory)]$ConnectionInfo,
        [string[]]$IncludeTable,
        [string[]]$ExcludeTable
    )

    @(
        [PSCustomObject]@{
            SchemaName  = 'dbo'
            TableName   = 'Users'
            FullName    = '[dbo].[Users]'
            Columns     = @(
                [PSCustomObject]@{
                    ColumnName   = 'Id'
                    DataType     = 'int'
                    IsIdentity   = $true
                    IsNullable   = $false
                    MaxLength    = $null
                    IsPrimaryKey = $true
                }
                # ... more columns
            )
            ForeignKeys = @()
        }
    )
}
```

#### 3. WriteData

```powershell
function Write-MyDatabaseData {
    param (
        [Parameter(Mandatory)]$ConnectionInfo,
        [Parameter(Mandatory)][string]$SchemaName,
        [Parameter(Mandatory)][string]$TableName,
        [Parameter(Mandatory)][System.Data.DataTable]$Data,
        [int]$BatchSize = 1000,
        $Transaction
    )

    # Insert rows — use parameterized queries, never concatenate user data into SQL
    return $Data.Rows.Count
}
```

#### 4. ReadData

```powershell
function Read-MyDatabaseData {
    param (
        [Parameter(Mandatory)]$ConnectionInfo,
        [Parameter(Mandatory)][string]$SchemaName,
        [Parameter(Mandatory)][string]$TableName,
        [int]$Top = 100
    )

    # Return a DataTable of existing rows
    return $dataTable
}
```

#### 5. Disconnect

```powershell
function Disconnect-MyDatabase {
    param (
        [Parameter(Mandatory)]$ConnectionInfo
    )

    $ConnectionInfo.DbConnection.Close()
    $ConnectionInfo.DbConnection.Dispose()
}
```

### Registration

Register your provider using the internal registration function:

```powershell
Register-SldgProviderInternal -Name 'MyDatabase' -FunctionMap @{
    Connect    = 'Connect-MyDatabase'
    GetSchema  = 'Get-MyDatabaseSchema'
    WriteData  = 'Write-MyDatabaseData'
    ReadData   = 'Read-MyDatabaseData'
    Disconnect = 'Disconnect-MyDatabase'
}

# Now use it:
Connect-SldgDatabase -Provider 'MyDatabase' -ServerInstance 'localhost' -Database 'TestDB'
```

### Tips

- Always use **parameterized queries** in WriteData — never concatenate user data into SQL.
- Support the `-Transaction` parameter so `Invoke-SldgDataGeneration -UseTransaction` works with your provider.
- Return `[System.Data.DataTable]` from ReadData for compatibility with validation and transforms.
- The module uses compiled C# types (namespace `SqlLabDataGenerator`). Your Connect function should return a `[SqlLabDataGenerator.Connection]` object.

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