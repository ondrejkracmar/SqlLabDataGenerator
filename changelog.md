# Changelog

All notable changes to **SqlLabDataGenerator** are documented in this file.

Format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/) with [Semantic Versioning](https://semver.org/).

---

## [Unreleased]

_Nothing yet._

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
 - New: `Set-SldgAIProvider` — one-command AI setup (provider, model, endpoint, features)
 - New: `Get-SldgAIProvider` — show current AI configuration and active database connection
 - New: `Test-SldgAIProvider` — test AI connectivity with response time measurement

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