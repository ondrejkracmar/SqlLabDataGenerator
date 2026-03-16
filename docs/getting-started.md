# Getting Started with SqlLabDataGenerator

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
| PowerShell | 5.1+ or 7+ | PowerShell 7 recommended for Ollama TLS skip |
| PSFramework | 1.13.426+ | Installed automatically as dependency |
| Ollama | any | Optional — for local AI models |
| OpenAI API key | — | Optional — for OpenAI / Azure OpenAI |

---

## Basic Workflow

SqlLabDataGenerator follows a 5-step pipeline:

```
Connect → Discover → Analyze → Plan → Generate
```

### 1. Connect to a Database

```powershell
# SQL Server — Windows auth
Connect-SldgDatabase -ServerInstance 'localhost' -Database 'AdventureWorks'

# SQL Server — SQL auth
$cred = Get-Credential
Connect-SldgDatabase -ServerInstance 'dbserver\SQLEXPRESS' -Database 'TestDB' -Credential $cred

# SQLite
Connect-SldgDatabase -ServerInstance 'C:\data\mydb.sqlite' -Database 'main' -Provider 'SQLite'
```

### 2. Discover Schema

```powershell
$schema = Get-SldgDatabaseSchema

# Filter to specific schemas/tables
$schema = Get-SldgDatabaseSchema -SchemaFilter 'dbo' -TableFilter 'Customer', 'Order'
```

The schema model contains tables, columns, data types, PKs, FKs, unique constraints, and check constraints.

### 3. Analyze Columns

```powershell
# Pattern matching only (no AI needed)
$analyzed = Get-SldgColumnAnalysis -Schema $schema

# With AI enrichment (much richer results)
$analyzed = Get-SldgColumnAnalysis -Schema $schema -UseAI -Locale 'cs-CZ'
```

AI analysis recognizes column names in any language and provides:
- Semantic type classification (FirstName, Email, Phone, Money, etc.)
- PII detection
- Value examples and patterns
- Cross-column dependency detection

### 4. Create a Generation Plan

```powershell
# Basic plan — 200 rows per table
$plan = New-SldgGenerationPlan -Schema $analyzed -RowCount 200

# AI-assisted plan — AI suggests row counts and rules
$plan = New-SldgGenerationPlan -Schema $analyzed -RowCount 200 -UseAI -IndustryHint 'eCommerce'
```

Customize specific columns:

```powershell
Set-SldgGenerationRule -Plan $plan -TableName 'dbo.Customer' -ColumnName 'Status' -ValueList @('Active', 'Inactive', 'Pending')
Set-SldgGenerationRule -Plan $plan -TableName 'dbo.Order' -ColumnName 'Currency' -StaticValue 'CZK'
```

### 5. Generate Data

```powershell
# Generate and insert into database
$result = Invoke-SldgDataGeneration -Plan $plan

# Generate in memory only (no DB write)
$result = Invoke-SldgDataGeneration -Plan $plan -NoInsert -PassThru

# Validate
Test-SldgGeneratedData -Schema $schema
```

### 6. Disconnect

```powershell
Disconnect-SldgDatabase
```

---

## Using AI

See [AI Configuration & Training](ai-configuration.md) for the full guide. Quick setup:

```powershell
# Ollama (local, free)
Set-SldgAIProvider -Provider Ollama -Model 'llama3' -EnableAIGeneration -EnableAILocale

# OpenAI
Set-SldgAIProvider -Provider OpenAI -Model 'gpt-4o' -ApiKey $env:OPENAI_API_KEY -EnableAIGeneration

# Verify
Test-SldgAIProvider
```

---

## Locales

```powershell
# Use built-in locale
Set-SldgAIProvider -Locale 'cs-CZ'

# AI-generate any locale
Register-SldgLocale -Name 'de-DE' -UseAI

# Mix languages
Register-SldgLocale -Name 'custom' -MixFrom @{
    PersonNames = 'cs-CZ'
    Addresses   = 'de-DE'
    Companies   = 'en-US'
}
```

---

## Profiles (Repeatable Generation)

```powershell
# Save
Export-SldgGenerationProfile -Plan $plan -Path 'C:\profiles\mydb.json'

# Load
$plan = New-SldgGenerationPlan -Schema $analyzed
Import-SldgGenerationProfile -Path 'C:\profiles\mydb.json' -Plan $plan
```

---

## Data Transforms

```powershell
# Generate in memory
$result = Invoke-SldgDataGeneration -Plan $plan -NoInsert -PassThru

# Transform to Entra ID users
$users = Export-SldgTransformedData -Data $result.Tables[0].DataTable `
    -Transformer 'EntraIdUser' `
    -TransformerParams @{ Domain = 'contoso.onmicrosoft.com' }

# Export as JSON
Export-SldgTransformedData -Data $result.Tables[0].DataTable `
    -Transformer 'EntraIdUser' `
    -OutputPath 'C:\export\users.json' `
    -TransformerParams @{ Domain = 'contoso.onmicrosoft.com' }
```

---

## Configuration Reference

All settings use PSFramework configuration system (`Set-PSFConfig` / `Get-PSFConfigValue`).
The `Set-SldgAIProvider` cmdlet wraps the most common settings.

| Key | Default | Description |
|---|---|---|
| `AI.Provider` | `None` | AI provider: None, OpenAI, AzureOpenAI, Ollama |
| `AI.ApiKey` | _(empty)_ | API key (not needed for Ollama) |
| `AI.Endpoint` | _(empty)_ | Endpoint URL (auto for OpenAI, required for AzureOpenAI) |
| `AI.Model` | `gpt-4` | Model name (gpt-4, gpt-4o, llama3, mistral, etc.) |
| `AI.MaxTokens` | `4096` | Max tokens per AI response |
| `AI.Ollama.Temperature` | `0.3` | Ollama temperature (0.0–1.0) |
| `AI.Ollama.SkipCertificateCheck` | `$false` | Skip TLS cert check for dev Ollama servers |
| `Generation.DefaultRowCount` | `100` | Default rows per table |
| `Generation.BatchSize` | `1000` | DB insert batch size |
| `Generation.Seed` | `0` | Random seed (0 = random) |
| `Generation.Locale` | `en-US` | Default locale |
| `Generation.AILocale` | `$false` | Auto-generate locale data via AI |
| `Generation.AIGeneration` | `$false` | AI-first data generation |
| `Generation.Mode` | `Synthetic` | Generation mode: Synthetic, Masking, Scenario |

---

## Next Steps

- [AI Configuration & Training](ai-configuration.md) — deep dive into AI setup and custom model training
- [Command Reference](commands/) — detailed help for every command
