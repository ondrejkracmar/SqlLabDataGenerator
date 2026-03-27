# Getting Started

Step-by-step guide to installing SqlLabDataGenerator and generating your first test data.

> For an overview of all features, see the [README](../README.md). For AI setup, see [AI Configuration](ai-configuration.md).

---

## Installation

### From PowerShell Gallery

```powershell
Install-Module SqlLabDataGenerator -Scope CurrentUser
```

### From Source

```powershell
git clone <repo-url>
Import-Module ./src/SqlLabDataGenerator/SqlLabDataGenerator.psd1
```

### Prerequisites

| Requirement | Version | Notes |
|---|---|---|
| PowerShell | 5.1+ or 7+ | PowerShell 7 recommended for parallel generation |
| PSFramework | 1.13.426+ | Installed automatically as dependency |
| Ollama | any | Optional — for local AI models |
| OpenAI API key | — | Optional — for OpenAI / Azure OpenAI |

---

## The Pipeline

SqlLabDataGenerator follows a 5-step pipeline. Each step produces an object that feeds into the next:

```
Connect → Discover → Analyze → Plan → Generate
```

| Step | Command | What it does |
|---|---|---|
| **Connect** | `Connect-SldgDatabase` | Opens a connection to your database |
| **Discover** | `Get-SldgDatabaseSchema` | Reads tables, columns, FKs, PKs, constraints |
| **Analyze** | `Get-SldgColumnAnalysis` | Classifies each column semantically (name? email? money?) |
| **Plan** | `New-SldgGenerationPlan` | Decides row counts and generator per column, ordered by FK deps |
| **Generate** | `Invoke-SldgDataGeneration` | Produces data and inserts it into the database |

You can stop at any step to inspect or customize the output before continuing.

---

## Tutorial: Generate Data Without AI

The module works without any AI setup. Built-in generators use column name patterns to produce realistic values.

### 1. Connect

```powershell
# SQL Server — Windows authentication
Connect-SldgDatabase -ServerInstance 'localhost' -Database 'AdventureWorks'
```

Other connection methods:

```powershell
# SQL Server — SQL authentication
$cred = Get-Credential
Connect-SldgDatabase -ServerInstance 'dbserver\SQLEXPRESS' -Database 'TestDB' -Credential $cred

# SQLite
Connect-SldgDatabase -ServerInstance 'C:\data\mydb.sqlite' -Database 'main' -Provider 'SQLite'
```

### 2. Discover Schema

```powershell
$schema = Get-SldgDatabaseSchema
```

This reads all tables, columns, data types, primary keys, foreign keys, unique constraints, and check constraints.

To limit the scope:

```powershell
$schema = Get-SldgDatabaseSchema -SchemaFilter 'dbo' -TableFilter 'Customer', 'Order'
```

### 3. Analyze Columns

```powershell
$analyzed = Get-SldgColumnAnalysis -Schema $schema
```

Pattern matching classifies columns by name — `Email` → Email generator, `FirstName` → PersonName generator, `Phone` → Phone generator, etc.

The 10 built-in generators: PersonName, Address, Email, Phone, Date, Number, Company, Identifier, Financial, Text.

### 4. Create a Plan

```powershell
$plan = New-SldgGenerationPlan -Schema $analyzed -RowCount 100
```

The plan orders tables by FK dependencies (parent tables first) and assigns a generator to each column. You can customize it before generating — see [Customizing Columns](#customizing-columns) below.

### 5. Generate

```powershell
Invoke-SldgDataGeneration -Plan $plan
```

Data is inserted directly into the database. FK columns are automatically filled with valid parent values.

### 6. Validate and Disconnect

```powershell
Test-SldgGeneratedData -Schema $schema
Disconnect-SldgDatabase
```

Validation checks FK integrity, unique constraints, NOT NULL, and row counts.

---

## Tutorial: Generate Data With AI

AI adds three capabilities on top of the basic pipeline:

1. **Smarter analysis** — recognizes column names in any language (Czech `Jmeno`, German `Nachname`)
2. **Better data** — generates entire rows with cross-column consistency (email matches name, address is coherent)
3. **Any locale** — generates culture-specific names, addresses, phone formats on the fly

### Setup

```powershell
# Ollama (local, free)
Set-SldgAIProvider -Provider Ollama -Model 'llama3' -EnableAIGeneration -EnableAILocale

# Or OpenAI
Set-SldgAIProvider -Provider OpenAI -Model 'gpt-4o' -ApiKey $env:OPENAI_API_KEY -EnableAIGeneration

# Verify
Test-SldgAIProvider
```

See [AI Configuration](ai-configuration.md) for all providers, per-purpose models, and detailed options.

### Run the Pipeline with AI

```powershell
Connect-SldgDatabase -ServerInstance 'localhost' -Database 'AdventureWorks'

$schema   = Get-SldgDatabaseSchema
$analyzed = Get-SldgColumnAnalysis -Schema $schema -UseAI
$plan     = New-SldgGenerationPlan -Schema $analyzed -RowCount 200 -UseAI

Invoke-SldgDataGeneration -Plan $plan

Test-SldgGeneratedData -Schema $schema
Disconnect-SldgDatabase
```

The only difference from the basic pipeline is adding `-UseAI` to `Get-SldgColumnAnalysis` and `New-SldgGenerationPlan`. AI data generation is controlled globally via `Set-SldgAIProvider -EnableAIGeneration`.

> **Tip:** AI features are additive. You can use AI only for analysis (`-UseAI` on `Get-SldgColumnAnalysis`) while keeping static generators for data, or enable AI data generation without AI locale support.

### Two-Tier AI (Optional)

For the best results, configure a powerful cloud model for schema analysis and a fast local model for data generation. The cloud model analyzes your schema + sample data once and produces per-table generation notes that guide the local model:

```powershell
# Smart model analyzes schema — called once during New-SldgGenerationPlan -UseAI
Set-SldgAIProvider -Provider OpenAI -Model 'gpt-4o' -ApiKey $key -Purpose 'schema-analysis'

# Fast local model generates data — guided by notes from the smart model
Set-SldgAIProvider -Provider Ollama -Model 'llama3' -EnableAIGeneration
```

See [AI Configuration — Two-Tier AI Architecture](ai-configuration.md#two-tier-ai-architecture) for details.

---

## Customizing Columns

After creating a plan, override specific columns before running `Invoke-SldgDataGeneration`:

```powershell
# Fixed list of values
Set-SldgGenerationRule -Plan $plan -TableName 'dbo.Order' -ColumnName 'Status' `
    -ValueList @('Pending', 'Shipped', 'Delivered', 'Cancelled')

# Constant value for every row
Set-SldgGenerationRule -Plan $plan -TableName 'dbo.Order' -ColumnName 'Currency' -StaticValue 'CZK'

# Custom logic
Set-SldgGenerationRule -Plan $plan -TableName 'dbo.Product' -ColumnName 'SKU' `
    -ScriptBlock { "PRD-{0:D6}" -f (Get-Random -Minimum 1 -Maximum 999999) }

# AI hint for JSON columns
Set-SldgGenerationRule -Plan $plan -TableName 'dbo.Project' -ColumnName 'Settings' `
    -Generator 'Json' -AIGenerationHint 'Project settings with theme, notifications, sprint config'

# Context-dependent JSON — structure varies by another column
Set-SldgGenerationRule -Plan $plan -TableName 'dbo.UsageReport' -ColumnName 'ReportData' `
    -Generator 'Json' `
    -AIGenerationHint 'M365 usage report data; structure varies by report type' `
    -CrossColumnDependency 'ReportType'
```

For advanced JSON/XML generation (context-dependent, value examples, resolution chain), see [AI Configuration — JSON and XML Columns](ai-configuration.md#json-and-xml-column-configuration).

---

## Generation Modes

| Mode | When to use | Command |
|---|---|---|
| **Synthetic** (default) | Fill empty tables with new data | `New-SldgGenerationPlan -Schema $analyzed -RowCount 200` |
| **Masking** | Anonymize PII in existing data | `New-SldgGenerationPlan -Schema $analyzed -Mode Masking` |
| **Scenario** | Industry templates with realistic table ratios | `New-SldgGenerationPlan -Schema $analyzed -Mode Scenario -ScenarioName Auto` |

**Masking** reads current rows and replaces sensitive columns (names, emails, phones) while keeping non-PII data intact — useful for dev copies of production databases.

**Scenario** uses industry templates (eCommerce, Healthcare, HR, Finance, Education) that know which tables are lookup vs. transaction tables and set row ratios automatically. Use `-ScenarioName Auto` to auto-detect from table names.

```powershell
# Scenario with AI advice
$plan = New-SldgGenerationPlan -Schema $analyzed -Mode Scenario `
    -ScenarioName 'Healthcare' -RowCount 200 -UseAI -IndustryHint 'Healthcare CZ'
```

---

## Locales

By default, data is generated in English (`en-US`). To change the locale:

```powershell
Set-SldgAIProvider -Provider Ollama -Model 'llama3' -EnableAIGeneration -EnableAILocale -Locale 'cs-CZ'
```

Built-in locales: `en-US`, `cs-CZ`. With AI enabled, any culture code works:

```powershell
# AI-generate a locale for any culture
Register-SldgLocale -Name 'de-DE' -UseAI -PoolSize 50

# Mix categories from different cultures
Register-SldgLocale -Name 'mixed' -MixFrom @{
    PersonNames = 'cs-CZ'
    Addresses   = 'de-DE'
    Companies   = 'en-US'
}
```

See [Extending — Custom Locale](extending.md#custom-locale) for registering locales with your own static data.

---

## In-Memory Generation

Generate data without inserting into the database:

```powershell
$result = Invoke-SldgDataGeneration -Plan $plan -NoInsert -PassThru

# Access generated DataTables
$result.Tables[0].DataTable | Format-Table
```

---

## Parallel Generation

Generate independent tables concurrently (PowerShell 7+):

```powershell
$result = Invoke-SldgDataGeneration -Plan $plan -Parallel -ThrottleLimit 4
```

For very large tables (100k+ rows), the module automatically switches to chunked streaming to keep memory usage low.

---

## Profiles

Save your plan as a JSON file and share it with your team:

```powershell
# Export
Export-SldgGenerationProfile -Plan $plan -Path '.\profile.json' -IncludeSemanticAnalysis

# Import on another machine or in CI/CD
$plan = New-SldgGenerationPlan -Schema $analyzed
Import-SldgGenerationProfile -Path '.\profile.json' -Plan $plan
Invoke-SldgDataGeneration -Plan $plan
```

Profiles store row counts, value lists, static values, and generator overrides. ScriptBlock rules are rejected on import for security.

---

## Data Transforms

Convert generated data into formats for other systems:

```powershell
$result = Invoke-SldgDataGeneration -Plan $plan -NoInsert -PassThru

Export-SldgTransformedData -Data $result.Tables[0].DataTable `
    -Transformer 'EntraIdUser' -OutputPath '.\users.json' `
    -TransformerParams @{ Domain = 'contoso.onmicrosoft.com' }
```

Built-in transformers: `EntraIdUser`, `EntraIdGroup`. See [Extending — Custom Transformer](extending.md#custom-transformer) to create your own.

---

## Next Steps

- [AI Configuration](ai-configuration.md) — providers, per-purpose models, JSON/XML columns, prompt customization, walkthroughs, custom model training
- [Extending](extending.md) — custom database providers, transformers, locales, generation rules
- [Command Reference](commands/) — detailed help for every exported command