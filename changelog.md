# Changelog

All notable changes to **SqlLabDataGenerator** are documented in this file.

Format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/) with [Semantic Versioning](https://semver.org/).

---

## [Unreleased]

### Added — Context-Dependent Structured Data Generation
- **`-AIGenerationHint`** parameter on `Set-SldgGenerationRule` — free-text instructions for AI-powered JSON/XML generation.
- **`-CrossColumnDependency`** parameter on `Set-SldgGenerationRule` — links a structured column to another column whose value drives structure variation (e.g., JSON structure varies by report type).
- **`-ValueExamples`** parameter on `Set-SldgGenerationRule` — provide example documents to guide AI generation format.
- **Context-dependent AI prompt** — new `structured-value-contextual.default.prompt` template used when `-CrossColumnDependency` is set; includes context column/value in the AI prompt.
- **Per-context caching** — cache key format `StructuredData|{Table}|{Column}|{Type}|ctx:{ContextValue}` ensures each dependency value gets its own pool of 10 AI-generated documents.
- **Automatic column reordering** — columns with `-CrossColumnDependency` are generated after their dependency columns within each row.
- **Row context tracking** — `$rowContext` hashtable tracks generated values per row, enabling cross-column data flow during generation.

### Added — Compiled C# Type System
- **Hybrid PS/C# module architecture** — compiled C# class library (`SqlLabDataGenerator.dll`, .NET 8.0) provides strongly-typed output objects.
- 24 POCO classes in flat `SqlLabDataGenerator` namespace replacing all `PSTypeName` string annotations: `ColumnInfo`, `TableInfo`, `SchemaModel`, `ForeignKeyRef`, `ForeignKeyInfo`, `Connection`, `ColumnPlan`, `TablePlan`, `GenerationPlan`, `TableResult`, `GenerationResult`, `RowSet`, `ScenarioTemplate`, `AIPlanAdvice`, `AIProviderInfo`, `AIModelOverride`, `AIProviderTestResult`, `PromptTemplate`, `ColumnClassification`, `ValidationResult`, `Provider`, `Transformer`, `EntraIdUser`, `EntraIdGroup`.
- `RequiredAssemblies = @('bin\SqlLabDataGenerator.dll')` in module manifest for automatic DLL loading.
- All public functions return typed objects — enables IntelliSense, tab completion on properties, pipeline filtering, and Format-Table/Format-List views.

### Added — Prompt Management
- **`Get-SldgPromptTemplate`** — list and inspect built-in and custom .prompt templates with optional content retrieval.
- **`Set-SldgPromptTemplate`** — create or update custom prompt overrides from string content, file, or pipeline input.
- **`Remove-SldgPromptTemplate`** — delete custom prompt overrides (built-in templates are protected).
- Externalized prompt templates as `.prompt` files with YAML front matter (`Purpose`, `Variant`, `Description`, `Version`) and `{{Variable}}` placeholders.
- Resolution order: custom override → built-in template → error.
- `AI.PromptPath` configuration key for custom prompt directory.

### Added — Per-Purpose AI Model Overrides
- **`Set-SldgAIProvider -Purpose`** — configure different AI models for different tasks (column-analysis, structured-value, batch-generation, plan-advice, locale-data, locale-category).
- **`Get-SldgAIProvider -Purpose`** — inspect per-purpose model override configuration.
- `AI.ModelOverrides` configuration stores purpose-specific model settings.
- Provider-level credentials support via `-Credential` parameter on `Set-SldgAIProvider`.

### Changed
- `Connection` class property renamed to `DbConnection` (resolves CS0542 member-name-equals-type-name conflict).
- Module manifest updated: 22 exported functions (added Get/Set/Remove-SldgPromptTemplate), RequiredAssemblies enabled.

### Added — Scenario Mode
- **Scenario mode** (`New-SldgGenerationPlan -Mode Scenario`) — domain-specific data generation using built-in templates.
- Five built-in scenario templates: **eCommerce**, **Healthcare**, **HR**, **Finance**, **Education**.
- Auto-detection (`-ScenarioName Auto`) matches schema table names to the best template.
- Scenario templates define table role multipliers (Lookup ×0.05, Master ×1.0, Transaction ×3–20, Detail ×8–30) for realistic relational data volumes.
- Scenario-specific value rules for status, type, and category columns (e.g., `OrderStatus` → Pending/Processing/Shipped/Delivered/Cancelled).
- New internal function `Get-SldgScenarioTemplate` — retrieves and matches scenario templates.

### Added — Parallel Table Generation
- **`-Parallel` switch** on `Invoke-SldgDataGeneration` — independent tables generated concurrently (PS 7+ only).
- Tables grouped by FK dependency level via `Group-SldgTablesByLevel`; tables at the same level run in parallel.
- **`-ThrottleLimit`** parameter and `Generation.ThrottleLimit` config (default: 4) for concurrency control.
- Automatic fallback to sequential on PS 5.1 or when `-UseTransaction` is active.
- Parallel generation, sequential writes — thread-safe FK value propagation between levels.

### Added — Streaming for Large Tables
- **Streaming (chunked) generation** — tables exceeding `Generation.StreamingThreshold` (default: 100,000 rows) are generated and written in fixed-size chunks.
- `Generation.StreamingChunkSize` config (default: 10,000 rows) — each chunk is generated, written, and disposed to keep memory bounded.
- Cross-chunk uniqueness tracking via shared `UniqueTracker` parameter in `New-SldgRowSet`.
- New internal function `Invoke-SldgStreamingGeneration` — orchestrates chunked generation and write cycles.

---

## [1.1.0] — 2026-03-16

**AI-First Architecture, Locales, SQLite & Transform Layer**

### Added — AI-Powered Data Generation (Deep Integration)
- **AI batch value generator** (`New-SldgAIGeneratedBatch`) — AI generates entire rows of contextually-consistent data.
- AI understands column names in any language (DisplayName, Jmeno, Prijmeni, Telefon, Oddeleni, etc.).
- AI recognizes business context from table relationships (Orders.Total = Money, not Integer).
- Cross-column consistency — AI generates Email matching FirstName+LastName, etc.
- **AI plan advisor** (`Get-SldgAIPlanAdvice`) — AI suggests optimal row counts, detects lookup vs transaction tables, recommends generation rules.
- `New-SldgGenerationPlan -UseAI` applies AI-suggested row counts and custom rules.
- Enhanced AI column analysis with ValueExamples, ValuePattern, CrossColumnDependency metadata.
- `Generation.AIGeneration` config — enable AI-first data generation with static fallback.
- AI value caching — repeated requests for same column types served from cache.
- `Get-SldgColumnAnalysis -Locale` parameter for locale-specific AI analysis.

### Added — AI Platform
- Ollama AI provider support — use local or custom-trained models for semantic analysis.
- Configurable Ollama endpoint, temperature, and certificate skip settings.
- `Set-SldgAIProvider` — one-command AI setup (provider, model, endpoint, features).
- `Get-SldgAIProvider` — show current AI configuration and active database connection.
- `Test-SldgAIProvider` — test AI connectivity with response time measurement.

### Changed — AI Platform
- `Invoke-SldgAIRequest` now dispatches to OpenAI, AzureOpenAI, or Ollama.

### Added — Locale / Culture System
- Universal locale system for culturally-aware data generation.
- **AI-powered locale generation** — use any language/culture without pre-built data packs.
- `Register-SldgLocale -UseAI` generates complete locale via AI for any culture code.
- `Register-SldgLocale -MixFrom` combines categories from different languages (e.g., Czech names + German addresses).
- Automatic AI locale fallback — when `Generation.AILocale` is enabled, missing locales are generated on-the-fly.
- Built-in en-US locale (English United States) as offline fallback.
- Built-in cs-CZ locale (Czech Republic — Czech names, addresses, phone formats, companies, etc.).
- All generators accept `-Locale` parameter with fallback chain: static → AI → en-US.
- Template-based phone number formatting and locale-aware address formatting.
- `-PoolSize` and `-CustomInstructions` parameters for fine-tuning AI generation.

### Added — SQLite Provider
- Full SQLite database provider (Connect, Schema, Read, Write, Disconnect).
- Supports both `Microsoft.Data.Sqlite` and `System.Data.SQLite` assemblies.
- PRAGMA-based schema discovery with type affinity mapping.
- `-CreateIfNotExists` switch for automatic database file creation.

### Added — Data Transform / Export Layer
- Pluggable transformer architecture for converting generated data to external formats.
- `Export-SldgTransformedData` — transform DataTable rows via registered transformers.
- `Get-SldgTransformer` / `Register-SldgTransformer` — manage transformers at runtime.
- Built-in EntraIdUser transformer (Microsoft Graph API compatible user payloads).
- Built-in EntraIdGroup transformer (Security, Microsoft365, DistributionList).
- Auto-detection of column mappings via regex (supports English and Czech column names).
- JSON export with `@{ value = @(...) }` wrapper for Graph API batch operations.

### Changed — Configuration
- Tab completion for locales, transformers, phone formats, AI providers (incl. Ollama).
- Module manifest — 18 exported functions, updated description and tags.
- Format views for Transformer, EntraIdUser, EntraIdGroup types.

---

## [1.0.0] — 2026-03-16

**MVP Release**

### Added — Architecture
- 5-layer architecture (Schema Discovery, Semantic Analysis, Generation, Validation, Providers).
- Provider model for extensible database support.
- Built-in SQL Server provider using SqlClient.

### Added — Schema Discovery (Layer 1)
- Full schema extraction (tables, columns, FKs, PKs, unique/check constraints).
- Topological sort for FK-aware table insertion order.
- Circular dependency detection with graceful fallback.

### Added — Semantic Analysis (Layer 2)
- Pattern-based column classification (60+ patterns for names, addresses, dates, financial, etc.).
- Data-type-based fallback classification.
- PII detection (names, SSN, email, credit cards, etc.).
- Optional AI-powered analysis via OpenAI / Azure OpenAI.
- Industry-specific hints for AI classification.

### Added — Generation Engine (Layer 3)
- 10 built-in generators (PersonName, Address, Email, Phone, Date, Number, Company, Identifier, Financial, Text).
- FK-consistent value generation (child rows reference existing parent values).
- Unique constraint enforcement with retry logic.
- Nullable column randomization.
- Custom generation rules (ValueList, StaticValue, ScriptBlock, Generator override).
- Configurable seed for reproducible generation.

### Added — Validation (Layer 4)
- FK referential integrity validation.
- Unique constraint validation.
- NOT NULL constraint validation.
- Row count verification.

### Added — Public API
- `Connect-SldgDatabase` / `Disconnect-SldgDatabase`
- `Get-SldgDatabaseSchema`
- `Get-SldgColumnAnalysis` (with `-UseAI` switch)
- `New-SldgGenerationPlan`
- `Set-SldgGenerationRule`
- `Invoke-SldgDataGeneration` (with `-NoInsert`, `-PassThru`)
- `Test-SldgGeneratedData`
- `Import-SldgGenerationProfile` / `Export-SldgGenerationProfile`
- `Register-SldgProvider`

### Added — Configuration
- PSFramework-based configuration (AI, Generation, Import settings).
- JSON profile import/export for repeatable generation.
- Tab completion for providers, modes, semantic types, industries.