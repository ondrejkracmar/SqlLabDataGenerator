# SqlLabDataGenerator

AI-assisted synthetic data generation platform for SQL Server, SQLite and more.

Discovers database schema, classifies columns semantically (with OpenAI, Azure OpenAI, or Ollama), generates realistic FK-consistent test data with locale support, and transforms output to Entra ID objects and other formats.

## Key Features

| Feature | Description |
|---|---|
| **Schema Discovery** | Auto-discovers tables, columns, FKs, PKs, unique/check constraints |
| **AI Semantic Analysis** | Recognizes column purpose from names in any language (Jmeno, Nachname, DisplayName…) |
| **AI Data Generation** | Generates entire rows of contextually-consistent data via AI |
| **10 Built-in Generators** | PersonName, Address, Email, Phone, Date, Number, Company, Identifier, Financial, Text |
| **Locale System** | Culture-aware data — built-in en-US, cs-CZ; AI generates any locale on-the-fly |
| **FK Consistency** | Child rows always reference valid parent values |
| **AI Providers** | OpenAI, Azure OpenAI, Ollama (local/custom models) |
| **Database Providers** | SQL Server, SQLite (extensible via `Register-SldgProvider`) |
| **Transform Layer** | Convert generated data to Entra ID users/groups, custom formats |
| **Validation** | FK integrity, unique constraints, NOT NULL, row count checks |

## Requirements

- **PowerShell** 5.1+ or PowerShell 7+
- **PSFramework** 1.13.426+
- Optional: Ollama, OpenAI API key, or Azure OpenAI deployment for AI features

## Quick Start

```powershell
# Install
Install-Module SqlLabDataGenerator -Scope CurrentUser

# Configure AI (optional — works without AI using pattern matching)
Set-SldgAIProvider -Provider Ollama -Model 'llama3' -EnableAIGeneration -EnableAILocale

# Connect to database
Connect-SldgDatabase -ServerInstance 'localhost' -Database 'AdventureWorks'

# Discover schema → Analyze → Plan → Generate
$schema   = Get-SldgDatabaseSchema
$analyzed = Get-SldgColumnAnalysis -Schema $schema -UseAI
$plan     = New-SldgGenerationPlan -Schema $analyzed -RowCount 200 -UseAI
Invoke-SldgDataGeneration -Plan $plan

# Validate
Test-SldgGeneratedData -Schema $schema

# Disconnect
Disconnect-SldgDatabase
```

## Exported Commands

### Connection
| Command | Description |
|---|---|
| `Connect-SldgDatabase` | Connect to SQL Server or SQLite database |
| `Disconnect-SldgDatabase` | Close the active connection |
| `Register-SldgProvider` | Register a custom database provider |

### AI
| Command | Description |
|---|---|
| `Set-SldgAIProvider` | Configure AI provider, model, endpoint, and features |
| `Get-SldgAIProvider` | Show current AI configuration |
| `Test-SldgAIProvider` | Test AI connectivity with response time |

### Schema & Analysis
| Command | Description |
|---|---|
| `Get-SldgDatabaseSchema` | Discover database schema (tables, columns, FKs) |
| `Get-SldgColumnAnalysis` | Semantic analysis — pattern matching + optional AI |

### Generation
| Command | Description |
|---|---|
| `New-SldgGenerationPlan` | Create an ordered execution plan |
| `Set-SldgGenerationRule` | Override generation for specific columns |
| `Invoke-SldgDataGeneration` | Execute data generation |
| `Test-SldgGeneratedData` | Validate generated data integrity |

### Profile
| Command | Description |
|---|---|
| `Export-SldgGenerationProfile` | Save plan to JSON |
| `Import-SldgGenerationProfile` | Load plan from JSON |

### Locale
| Command | Description |
|---|---|
| `Register-SldgLocale` | Register locale (manual, AI-generated, or mixed) |

### Transform
| Command | Description |
|---|---|
| `Export-SldgTransformedData` | Transform data to Entra ID / custom format |
| `Get-SldgTransformer` | List available transformers |
| `Register-SldgTransformer` | Register a custom transformer |

## Documentation

Detailed documentation is available in the [docs/](docs/) folder:

- [Getting Started](docs/getting-started.md) — installation, first run, basic workflow
- [AI Configuration & Training](docs/ai-configuration.md) — providers, custom Ollama models, fine-tuning
- [Command Reference](docs/commands/) — platyPS-generated help for every exported command

## Project Structure

```
src/
  SqlLabDataGenerator/           # PowerShell module
    functions/                   # Public commands (ai/, connection/, generation/, …)
    internal/                    # Private functions (semantic/, generation/, locale/, …)
    en-us/                       # String resources
    views/                       # Format.ps1xml
    types/                       # Types.ps1xml
  tests/                         # Pester tests
  build/                         # CI/CD scripts
docs/                            # Detailed documentation
```

## License

See [LICENSE](LICENSE) for details.
