# Extending SqlLabDataGenerator

This guide covers how to extend SqlLabDataGenerator with custom database providers, data transformers, and locales.

## Table of Contents

- [Custom Database Provider](#custom-database-provider)
- [Custom Transformer](#custom-transformer)
- [Custom Locale](#custom-locale)
- [Custom Generation Rules](#custom-generation-rules)

---

## Custom Database Provider

A database provider teaches SqlLabDataGenerator how to connect, read schemas, write data, and disconnect from a specific database engine.

### Required Functions

You must implement **5 functions** that conform to these contracts:

#### 1. Connect Function

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
        Provider     = 'MyDatabase'
        DbConnection = $conn          # The open connection object
        ServerInstance = $Server
        Database     = $Database
    }
}
```

#### 2. GetSchema Function

```powershell
function Get-MyDatabaseSchema {
    param (
        [Parameter(Mandatory)]$ConnectionInfo,
        [string[]]$IncludeTable,
        [string[]]$ExcludeTable
    )

    # Return an array of table objects
    @(
        [PSCustomObject]@{
            SchemaName  = 'dbo'
            TableName   = 'Users'
            FullName    = '[dbo].[Users]'
            Columns     = @(
                [PSCustomObject]@{
                    ColumnName  = 'Id'
                    DataType    = 'int'
                    IsIdentity  = $true
                    IsNullable  = $false
                    MaxLength   = $null
                    IsPrimaryKey = $true
                }
                # ... more columns
            )
            ForeignKeys = @()  # FK relationship objects
        }
    )
}
```

#### 3. WriteData Function

```powershell
function Write-MyDatabaseData {
    param (
        [Parameter(Mandatory)]$ConnectionInfo,
        [Parameter(Mandatory)][string]$SchemaName,
        [Parameter(Mandatory)][string]$TableName,
        [Parameter(Mandatory)][System.Data.DataTable]$Data,
        [int]$BatchSize = 1000,
        $Transaction  # Optional external transaction for rollback support
    )

    # Insert rows and return the count of inserted rows
    return $Data.Rows.Count
}
```

#### 4. ReadData Function

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

#### 5. Disconnect Function

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

```powershell
# Load your functions into the session, then register:
Register-SldgProvider -Name 'MyDatabase' `
    -ConnectFunction    'Connect-MyDatabase' `
    -GetSchemaFunction  'Get-MyDatabaseSchema' `
    -WriteDataFunction  'Write-MyDatabaseData' `
    -ReadDataFunction   'Read-MyDatabaseData' `
    -DisconnectFunction 'Disconnect-MyDatabase'

# Now use it:
Connect-SldgDatabase -Provider 'MyDatabase' -Server 'localhost' -Database 'TestDB'
```

### Tips

- Always use **parameterized queries** in WriteData — never concatenate user data into SQL.
- Support the optional `-Transaction` parameter so `Invoke-SldgDataGeneration -UseTransaction` works with your provider.
- Return a `[System.Data.DataTable]` from ReadData for compatibility with the validation pipeline.
- The module uses compiled C# types (namespace `SqlLabDataGenerator`) for all core objects. Your Connect function should return a `[SqlLabDataGenerator.Connection]` object with `DbConnection`, `ServerInstance`, `Database`, and `Provider` properties.

---

## Custom Transformer

A transformer converts generated `DataTable` data into a specific output format (e.g., Entra ID users, CSV records, API payloads).

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
# Generate and transform
$plan = New-SldgGenerationPlan -IncludeTable 'Users' -RowCount 100
$result = Invoke-SldgDataGeneration -Plan $plan -NoInsert -PassThru

# Apply transformer
Export-SldgTransformedData -Data $result.Tables[0].DataTable `
    -Transformer 'MyFormat' -OutputPath './users.json'
```

### Column Auto-Detection

The built-in transformers (EntraIdUser, EntraIdGroup) use column name pattern matching to map DataTable columns to output properties. You can follow the same approach:

```powershell
function ConvertTo-MyFormat {
    param ([System.Data.DataTable]$Data)

    # Auto-detect columns by name pattern
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

Locales provide culture-specific data pools (names, addresses, phone formats) for realistic localized data generation.

### Option 1: Manual Registration

```powershell
Register-SldgLocale -Name 'sk-SK' -Data @{
    MaleNames       = @('Jan', 'Peter', 'Martin', 'Jozef', 'Pavol')
    FemaleNames     = @('Maria', 'Jana', 'Eva', 'Anna', 'Zuzana')
    LastNames       = @('Novak', 'Horvath', 'Kováč', 'Baláž', 'Tóth')
    StreetNames     = @('Hlavná', 'Štefánikova', 'Hviezdoslavova')
    StreetTypes     = @('ulica', 'námestie', 'cesta')
    Locations       = @('Bratislava', 'Košice', 'Prešov', 'Žilina')
    Countries       = @('Slovakia', 'Slovensko')
    EmailDomains    = @('email.sk', 'centrum.sk', 'azet.sk')
    PhoneFormat     = '+421 9## ### ###'
    CompanyPrefixes = @('Slovenská', 'Východná', 'Západná')
    CompanyCores    = @('Technika', 'Energetika', 'Stavba')
    CompanySuffixes = @('s.r.o.', 'a.s.', 'k.s.')
    Departments     = @('IT', 'Financie', 'Marketing', 'Výroba')
    JobTitles       = @('Riaditeľ', 'Manažér', 'Analytik', 'Vývojár')
    Industries      = @('Automobilový priemysel', 'IT', 'Energetika')
}
```

### Option 2: AI-Generated

```powershell
# Generate any locale automatically (requires a configured AI provider)
Register-SldgLocale -Name 'ja-JP' -UseAI -PoolSize 50
```

### Option 3: Mixed Locale

```powershell
# Combine categories from different languages
Register-SldgLocale -Name 'business-mix' -MixFrom @{
    PersonNames = 'cs-CZ'      # Czech names
    Addresses   = 'de-DE'      # German addresses
    Companies   = 'en-US'      # English company names
    PhoneFormat = 'cs-CZ'      # Czech phone format
}
```

### Required Data Keys

| Key | Type | Description |
|-----|------|-------------|
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

Override default generation for specific columns using `Set-SldgGenerationRule`:

```powershell
# Static value list
Set-SldgGenerationRule -Table 'Orders' -Column 'Status' `
    -ValueList @('Pending', 'Shipped', 'Delivered', 'Cancelled')

# Custom script block
Set-SldgGenerationRule -Table 'Products' -Column 'SKU' `
    -ScriptBlock { "PRD-{0:D6}" -f (Get-Random -Minimum 1 -Maximum 999999) }

# Sequential values
Set-SldgGenerationRule -Table 'Invoices' -Column 'InvoiceNumber' `
    -Pattern 'INV-{0:D8}' -Sequential
```

### AI-Powered Generation Hints

Guide AI generation with hints and cross-column dependencies:

```powershell
# Simple AI hint — tell AI what to generate
Set-SldgGenerationRule -Plan $plan -TableName 'dbo.Project' `
    -ColumnName 'Settings' -Generator 'Json' `
    -AIGenerationHint 'Project settings with theme, notification preferences, and sprint configuration'

# Context-dependent JSON — structure varies based on another column
Set-SldgGenerationRule -Plan $plan -TableName 'dbo.UsageReport' `
    -ColumnName 'ReportData' -Generator 'Json' `
    -AIGenerationHint 'M365 usage report data. Structure varies by report type.' `
    -CrossColumnDependency 'ReportType'

# Provide examples to guide AI output format
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
| `-CrossColumnDependency` | Column name whose value drives structure variation (auto-reorders columns) |
| `-ValueExamples` | Example documents showing expected format (AI uses as reference) |

Rules are stored in the generation plan and applied during `Invoke-SldgDataGeneration`. They take priority over semantic type-based generation.
