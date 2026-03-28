# SqlLabDataGenerator

**AI-powered** PowerShell module that fills your SQL Server or SQLite databases with realistic test data. Uses large language models (OpenAI, Azure OpenAI, or Ollama) to **understand your database structure** — recognizing what each column represents regardless of naming conventions or language — and then **generates contextually consistent rows** where names, emails, addresses, and business data make sense together.

### Key AI Capabilities

- **Semantic schema analysis** — AI reads your tables, columns, sample data, and relationships to understand the *purpose* of each column (e.g. `Jmeno` → person name, `CisloUctu` → bank account) instead of relying solely on naming patterns
- **Intelligent data generation** — AI produces entire rows with cross-column consistency: emails match names, addresses are coherent, financial values are realistic for the business domain
- **Two-tier architecture** — use a powerful cloud model (GPT-4o) for deep schema analysis and a fast local model (Llama 3) for high-throughput data generation, combining quality with speed
- **Any-language locale support** — generate data in any language without pre-built locale packs; the AI adapts names, addresses, and values to the target culture automatically
- **Per-table generation notes** — schema analysis produces expert-level guidance for each table that is passed to the generation model, resulting in higher-quality data even from smaller local models

The module also works **without AI** using 10 built-in generators (PersonName, Address, Email, Phone, Date, Number, Company, Identifier, Financial, Text) and pattern-based column classification. The provider architecture is extensible to additional database engines (PostgreSQL, MySQL, Oracle, and others).

## How It Works

The module follows a **5-step pipeline**. Each step builds on the previous one:

```
Connect → Discover → Analyze (AI) → Plan (AI) → Generate (AI)
```

1. **Connect** — open a connection to your database (`Connect-SldgDatabase`)
2. **Discover** — read tables, columns, foreign keys, constraints (`Get-SldgDatabaseSchema`)
3. **Analyze** — classify each column semantically using AI or pattern matching (`Get-SldgColumnAnalysis`)
4. **Plan** — AI analyzes sample data and relationships, produces per-table generation notes (`New-SldgGenerationPlan`)
5. **Generate** — AI produces contextually-consistent rows respecting all constraints (`Invoke-SldgDataGeneration`)

The pipeline is designed so that you can run it with a single command chain, or stop at any step to inspect and customize.

## Requirements

- **PowerShell** 5.1+ or PowerShell 7+ (7+ recommended for parallel generation and Ollama TLS skip)
- **PSFramework** (installed automatically as dependency)
- Optional: Ollama, OpenAI API key, or Azure OpenAI deployment for AI features

## Installation

```powershell
Install-Module SqlLabDataGenerator -Scope CurrentUser
```

Or import directly from source:

```powershell
git clone <repo-url>
Import-Module ./src/SqlLabDataGenerator/SqlLabDataGenerator.psd1
```

## Quick Start — Without AI

You don't need AI to start generating data. The module includes 10 built-in generators (PersonName, Address, Email, Phone, Date, Number, Company, Identifier, Financial, Text) that use pattern matching to figure out what each column needs.

```powershell
# 1. Connect
Connect-SldgDatabase -ServerInstance 'localhost' -Database 'AdventureWorks'

# 2. Discover schema (tables, columns, FKs, constraints)
$schema = Get-SldgDatabaseSchema

# 3. Analyze — pattern matching classifies columns by name
#    e.g. "Email" → Email generator, "FirstName" → PersonName generator
$analyzed = Get-SldgColumnAnalysis -Schema $schema

# 4. Plan — 100 rows per table, ordered by FK dependencies
$plan = New-SldgGenerationPlan -Schema $analyzed -RowCount 100

# 5. Generate and insert into the database
Invoke-SldgDataGeneration -Plan $plan

# Optional: check that FKs, unique constraints, NOT NULL all hold
Test-SldgGeneratedData -Schema $schema

# Done — close connection
Disconnect-SldgDatabase
```

That's it — five commands and your database has realistic test data.

## Quick Start — With AI

AI makes everything smarter: column analysis recognizes names in any language (Czech `Jmeno`, German `Nachname`), generates entire rows of contextually-consistent data, and supports any locale.

```powershell
# Configure AI (run once per session)
Set-SldgAIProvider -Provider Ollama -Model 'llama3' -EnableAIGeneration -EnableAILocale

# Verify the connection works
Test-SldgAIProvider

# Connect
Connect-SldgDatabase -ServerInstance 'localhost' -Database 'AdventureWorks'

# Discover + Analyze with AI enrichment
$schema   = Get-SldgDatabaseSchema
$analyzed = Get-SldgColumnAnalysis -Schema $schema -UseAI

# Plan with AI advice — AI suggests realistic row counts and rules
#   When schema-analysis provider is configured, also performs deep schema analysis
#   with sample data and stores per-table generation notes in the plan
$plan = New-SldgGenerationPlan -Schema $analyzed -RowCount 200 -UseAI

# Generate — AI produces entire rows with cross-column consistency
#   (e.g. Email matches FirstName + LastName, Address is coherent)
#   Per-table notes from schema analysis guide the generation model automatically
Invoke-SldgDataGeneration -Plan $plan

Test-SldgGeneratedData -Schema $schema
Disconnect-SldgDatabase
```

> **Tip:** AI features are additive. You can enable AI generation (`-EnableAIGeneration`) without AI locale (`-EnableAILocale`), or use AI only for analysis (`-UseAI` on `Get-SldgColumnAnalysis`) while keeping static generators for the actual data.

## Customizing the Plan

After creating a plan, you can override how specific columns are generated before running `Invoke-SldgDataGeneration`:

```powershell
$plan = New-SldgGenerationPlan -Schema $analyzed -RowCount 200

# Pick from a fixed list of values
Set-SldgGenerationRule -Plan $plan -TableName 'dbo.Order' -ColumnName 'Status' `
    -ValueList @('Pending', 'Shipped', 'Delivered', 'Cancelled')

# Always use the same value
Set-SldgGenerationRule -Plan $plan -TableName 'dbo.Order' -ColumnName 'Currency' -StaticValue 'CZK'

# Custom logic via ScriptBlock
Set-SldgGenerationRule -Plan $plan -TableName 'dbo.Product' -ColumnName 'SKU' `
    -ScriptBlock { "PRD-{0:D6}" -f (Get-Random -Minimum 1 -Maximum 999999) }

# Tell AI how to generate a JSON column
Set-SldgGenerationRule -Plan $plan -TableName 'dbo.Project' -ColumnName 'Settings' `
    -Generator 'Json' -AIGenerationHint 'Project settings with theme, notifications, sprint config'

# Context-dependent JSON — structure changes based on another column's value
Set-SldgGenerationRule -Plan $plan -TableName 'dbo.UsageReport' -ColumnName 'ReportData' `
    -Generator 'Json' `
    -AIGenerationHint 'M365 usage report data; structure varies by report type' `
    -CrossColumnDependency 'ReportType'

# Now generate with your customizations applied
Invoke-SldgDataGeneration -Plan $plan
```

## Generation Modes

The module supports three ways to generate data:

| Mode | When to use | Example |
|---|---|---|
| **Synthetic** (default) | Fill empty tables with new data | `New-SldgGenerationPlan -Schema $analyzed -RowCount 200` |
| **Masking** | Anonymize PII in existing data | `New-SldgGenerationPlan -Schema $analyzed -Mode Masking` |
| **Scenario** | Industry-specific templates with realistic table ratios | `New-SldgGenerationPlan -Schema $analyzed -Mode Scenario -ScenarioName Auto` |

**Masking** reads current rows and replaces sensitive columns (names, emails, phones) while keeping non-PII data intact — useful for creating dev copies of production databases.

**Scenario** uses industry templates (eCommerce, Healthcare, HR, Finance, Education) that know which tables are lookup vs. transaction tables and set appropriate row ratios automatically.

## Locales and Multi-Language Support

By default the module generates English (`en-US`) data. To generate data in another language:

```powershell
# Set locale when configuring AI
Set-SldgAIProvider -Provider Ollama -Model 'llama3' -EnableAIGeneration -EnableAILocale -Locale 'cs-CZ'
```

Built-in locales: `en-US`, `cs-CZ`. With AI enabled, any culture code works — the AI generates appropriate names, addresses, and values on the fly.

```powershell
# AI-generate a full locale data pack for any culture
Register-SldgLocale -Name 'ja-JP' -UseAI -PoolSize 50

# Mix categories from different cultures
Register-SldgLocale -Name 'mixed' -MixFrom @{
    PersonNames = 'cs-CZ'
    Addresses   = 'de-DE'
    Companies   = 'en-US'
}
```

## AI Providers

Three providers are supported. Choose based on your needs:

| Provider | Auth | Local | Cost | Best For |
|---|---|---|---|---|
| **Ollama** | None | Yes | Free | Development, privacy, custom models |
| **OpenAI** | API key | No | Per token | Highest quality, broad language support |
| **Azure OpenAI** | API key | No | Per token | Enterprise, data residency, compliance |

```powershell
# Ollama (local, free — recommended for development)
Set-SldgAIProvider -Provider Ollama -Model 'llama3' -EnableAIGeneration -EnableAILocale

# OpenAI
Set-SldgAIProvider -Provider OpenAI -Model 'gpt-4o' -ApiKey $env:OPENAI_API_KEY -EnableAIGeneration

# Azure OpenAI
Set-SldgAIProvider -Provider AzureOpenAI -Model 'gpt-4' `
    -Endpoint 'https://myinstance.openai.azure.com' -ApiKey $env:AZURE_OPENAI_KEY -EnableAIGeneration
```

You can also use different models for different tasks — for example, a powerful model for analysis and a fast local model for data generation:

```powershell
Set-SldgAIProvider -Provider OpenAI -Model 'gpt-4o' -ApiKey $key              # default for all
Set-SldgAIProvider -Provider Ollama -Model 'llama3' -Purpose 'batch-generation' # data gen: local
Set-SldgAIProvider -Provider Ollama -Model 'codellama' -Purpose 'structured-value' # JSON/XML: local
```

### Two-Tier AI Architecture

For best results, combine a powerful cloud model for schema analysis with a fast local model for data generation:

```powershell
# Tier 1 — Smart cloud model analyzes schema + sample data, produces per-table generation notes
Set-SldgAIProvider -Provider OpenAI -Model 'gpt-4o' -ApiKey $key -Purpose 'schema-analysis'

# Tier 2 — Fast local model generates data, guided by the notes from Tier 1
Set-SldgAIProvider -Provider Ollama -Model 'llama3' -EnableAIGeneration
```

When you run `New-SldgGenerationPlan -UseAI`, the module:
1. Queries sample rows from each table
2. Sends the full schema + samples to the schema-analysis model (Tier 1)
3. Receives per-table generation notes (table purpose, relationship context, value diversity hints, etc.)
4. Stores the notes in the plan and passes them to the batch-generation model (Tier 2) during `Invoke-SldgDataGeneration`

The local model gets expert-level guidance without needing to analyze the schema itself — resulting in higher-quality data at lower cost.

## Output Without Database Insert

Sometimes you need the data in memory or as a file, not inserted into the database:

```powershell
# Generate but don't insert — get DataTables in memory
$result = Invoke-SldgDataGeneration -Plan $plan -NoInsert -PassThru

# Access generated data
$result.Tables[0].DataTable | Format-Table
```

## Profiles — Repeatable Generation

Save your plan (with all custom rules) as a JSON file and share it with your team. Everyone generates the same shape of data regardless of their AI setup:

```powershell
# Save
Export-SldgGenerationProfile -Plan $plan -Path '.\profile.json' -IncludeSemanticAnalysis

# Load on another machine or CI/CD
$plan = New-SldgGenerationPlan -Schema $analyzed
Import-SldgGenerationProfile -Path '.\profile.json' -Plan $plan
Invoke-SldgDataGeneration -Plan $plan
```

## Data Transforms

Convert generated data into formats needed by other systems — for example, create Entra ID (Azure AD) user objects:

```powershell
$result = Invoke-SldgDataGeneration -Plan $plan -NoInsert -PassThru

Export-SldgTransformedData -Data $result.Tables[0].DataTable `
    -Transformer 'EntraIdUser' -OutputPath '.\users.json' `
    -TransformerParams @{ Domain = 'contoso.onmicrosoft.com' }
```

See [Extending](docs/extending.md) for how to create your own transformers.

## Parallel Generation and Streaming

For large databases, speed things up with parallel table generation (PowerShell 7+):

```powershell
# Parallel: independent tables generated concurrently
$result = Invoke-SldgDataGeneration -Plan $plan -Parallel -ThrottleLimit 4
```

Streaming is automatic — when a table exceeds the row threshold (default 100 000), the module switches to chunked generation (default 10 000 rows per chunk) to keep memory usage low. No extra configuration needed.

## Exported Commands (21)

### Connection
| Command | Description |
|---|---|
| `Connect-SldgDatabase` | Connect to SQL Server or SQLite; supports Windows auth, SQL auth, connection string |
| `Disconnect-SldgDatabase` | Close the active connection |

### AI Configuration
| Command | Description |
|---|---|
| `Set-SldgAIProvider` | Configure AI provider, model, endpoint, locale, per-purpose overrides |
| `Get-SldgAIProvider` | Show current AI configuration and all model overrides |
| `Test-SldgAIProvider` | Test AI connectivity and measure response time |

### Prompt Management
| Command | Description |
|---|---|
| `Get-SldgPromptTemplate` | List or read AI prompt templates (built-in and custom) |
| `Set-SldgPromptTemplate` | Create or update a custom prompt template override |
| `Remove-SldgPromptTemplate` | Remove a custom prompt override (falls back to built-in) |

### Schema & Analysis
| Command | Description |
|---|---|
| `Get-SldgDatabaseSchema` | Discover tables, columns, FKs, PKs, unique/check constraints |
| `Get-SldgColumnAnalysis` | Classify columns semantically — pattern matching + optional AI |

### Generation
| Command | Description |
|---|---|
| `New-SldgGenerationPlan` | Create an execution plan ordered by FK dependencies; supports AI advice and scenario templates |
| `Set-SldgGenerationRule` | Override column generation: ValueList, StaticValue, ScriptBlock, AI hints, cross-column dependencies |
| `Invoke-SldgDataGeneration` | Run data generation; supports `-Parallel`, `-NoInsert`, `-PassThru`, `-UseTransaction` |
| `Test-SldgGeneratedData` | Validate FK integrity, unique constraints, NOT NULL, row counts |

### Profile
| Command | Description |
|---|---|
| `Export-SldgGenerationProfile` | Save plan + rules to JSON for sharing |
| `Import-SldgGenerationProfile` | Load plan from JSON (rejects ScriptBlock rules for security) |

### Locale
| Command | Description |
|---|---|
| `Register-SldgLocale` | Register locale — built-in data, AI-generated, or mixed from multiple cultures |

### Transform
| Command | Description |
|---|---|
| `Export-SldgTransformedData` | Transform data to Entra ID users/groups or custom format |
| `Get-SldgTransformer` | List available transformers |
| `Register-SldgTransformer` | Register a custom transformer |

## Configuration

Fine-tune behavior via PSFramework config. Most settings have sensible defaults; the ones you're most likely to change are marked with ⚙️:

| Setting | Default | Description |
|---|---|---|
| ⚙️ `Generation.Locale` | `en-US` | Locale code. Set via `Set-SldgAIProvider -Locale` |
| ⚙️ `Generation.AIGeneration` | `$false` | Enable AI row generation. Set via `Set-SldgAIProvider -EnableAIGeneration` |
| ⚙️ `Generation.AILocale` | `$false` | Enable AI locale generation. Set via `Set-SldgAIProvider -EnableAILocale` |
| `Generation.Mode` | `Synthetic` | Generation mode: Synthetic, Masking, or Scenario |
| `Generation.Seed` | `0` | Random seed for reproducibility (0 = random) |
| `Generation.NullProbability` | `10` | Probability (0–100) of NULL for nullable columns |
| `Generation.StreamingThreshold` | `100000` | Row count above which streaming kicks in |
| `Generation.StreamingChunkSize` | `10000` | Rows per chunk in streaming mode |
| `Generation.ThrottleLimit` | `4` | Max concurrent tables in parallel mode |
| `AI.MaxTokens` | `4096` | Maximum tokens for AI responses |
| `AI.RetryCount` | `3` | Retry attempts for failed AI requests |
| `AI.RateLimitPerMinute` | `30` | Max AI requests per minute |
| `AI.PromptPath` | _(empty)_ | Custom prompt template override directory |
| `Cache.TTLMinutes` | `60` | Time-to-live for cached AI responses |
| `Audit.LogPath` | _(empty)_ | Path to JSON-lines audit log file |

## Documentation

For detailed guides beyond this README:

- [Getting Started](docs/getting-started.md) — full installation, first run, step-by-step workflow
- [AI Configuration & Training](docs/ai-configuration.md) — provider setup, custom Ollama models, prompt customization, walkthroughs
- [Extending](docs/extending.md) — custom database providers, transformers, locales, generation rules
- [Command Reference](docs/commands/) — detailed help for every exported command

## License

See [LICENSE](LICENSE) for details.
