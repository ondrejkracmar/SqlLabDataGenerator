# AI Configuration

SqlLabDataGenerator uses AI at three levels — all optional:

1. **Semantic Analysis** — classifying what each column means (FirstName, Email, Money, …)
2. **Data Generation** — generating entire rows of realistic, consistent values
3. **Locale Generation** — creating culture-specific data pools for any language

Without AI the module falls back to pattern matching and static generators. See [Getting Started](getting-started.md) for the basic pipeline.

---

## Table of Contents

- [Supported Providers](#supported-providers)
- [Quick Setup](#quick-setup)
- [Set-SldgAIProvider Parameters](#set-sldgaiprovider-parameters)
- [Per-Purpose Model Overrides](#per-purpose-model-overrides)
- [How AI Works in the Pipeline](#how-ai-works-in-the-pipeline)
- [JSON and XML Column Configuration](#json-and-xml-column-configuration)
- [Locales](#locales)
- [Scenario Mode](#scenario-mode)
- [Prompt Customization](#prompt-customization)
- [Walkthrough: Project Database with OpenAI](#walkthrough-project-database-with-openai)
- [Walkthrough: Czech Healthcare Database](#walkthrough-czech-healthcare-database)
- [Custom Model Training for Ollama](#custom-model-training-for-ollama)
- [Performance Tuning](#performance-tuning)
- [Troubleshooting](#troubleshooting)

---

## Supported Providers

| Provider | Auth | Local | Cost | Best For |
|---|---|---|---|---|
| **Ollama** | None | Yes | Free | Development, privacy, custom models |
| **OpenAI** | API key | No | Per token | Highest quality, broad language support |
| **Azure OpenAI** | API key | No | Per token | Enterprise, data residency, compliance |

---

## Quick Setup

### Ollama (Recommended for Development)

```powershell
# 1. Install Ollama — https://ollama.com/download
# 2. Pull a model
ollama pull llama3

# 3. Configure
Set-SldgAIProvider -Provider Ollama -Model 'llama3' -EnableAIGeneration -EnableAILocale

# 4. Verify
Test-SldgAIProvider
```

**Output:**

```
Provider   : Ollama
Model      : llama3
Status     : Connected
ResponseMs : 342
```

### OpenAI

```powershell
Set-SldgAIProvider -Provider OpenAI -Model 'gpt-4o' -ApiKey $env:OPENAI_API_KEY -EnableAIGeneration -EnableAILocale
Test-SldgAIProvider
```

### Azure OpenAI

```powershell
Set-SldgAIProvider -Provider AzureOpenAI `
    -Model 'gpt-4' `
    -Endpoint 'https://myinstance.openai.azure.com' `
    -ApiKey $env:AZURE_OPENAI_KEY `
    -EnableAIGeneration
Test-SldgAIProvider
```

### Disable AI

```powershell
Set-SldgAIProvider -Provider None
```

---

## Set-SldgAIProvider Parameters

```powershell
Set-SldgAIProvider
    -Provider <None|OpenAI|AzureOpenAI|Ollama>    # Required
    [-Model <string>]                               # e.g. 'llama3', 'gpt-4o', 'mistral'
    [-Endpoint <string>]                            # URL (auto for OpenAI/Ollama localhost)
    [-ApiKey <string>]                              # Required for OpenAI/AzureOpenAI
    [-MaxTokens <int>]                              # Default: 4096
    [-Temperature <double>]                         # Ollama: 0.0-1.0, default 0.3
    [-EnableAIGeneration]                           # Turn on AI row generation
    [-EnableAILocale]                               # Turn on AI locale generation
    [-SkipCertificateCheck]                         # Ollama dev servers with self-signed certs
    [-Locale <string>]                              # e.g. 'cs-CZ', 'de-DE'
    [-Credential <PSCredential>]                    # Alternative to -ApiKey
    [-Purpose <string>]                             # Per-purpose model override
```

Related cmdlets:

| Cmdlet | Purpose |
|---|---|
| `Get-SldgAIProvider` | Display current configuration and active model overrides |
| `Test-SldgAIProvider` | Test connectivity and measure response time |

---

## Per-Purpose Model Overrides

Use `-Purpose` to assign a different AI model for specific tasks — for example, a powerful model for analysis and a fast local model for data generation:

```powershell
# Global: GPT-4o for all tasks
Set-SldgAIProvider -Provider OpenAI -Model 'gpt-4o' -ApiKey $key

# Override: Ollama llama3 for batch data generation (faster, local, free)
Set-SldgAIProvider -Provider Ollama -Model 'llama3' -Purpose 'batch-generation'

# Override: codellama for structured JSON/XML value generation
Set-SldgAIProvider -Provider Ollama -Model 'codellama' -Purpose 'structured-value'
```

Available purposes:

| Purpose | Used By |
|---|---|
| `column-analysis` | `Get-SldgColumnAnalysis -UseAI` |
| `batch-generation` | `Invoke-SldgDataGeneration` (AI row generation) |
| `plan-advice` | `New-SldgGenerationPlan -UseAI` |
| `structured-value` | JSON/XML value generation |
| `structured-value-contextual` | Context-dependent JSON/XML (uses `-CrossColumnDependency`) |
| `locale-data` | `Register-SldgLocale -UseAI` |
| `locale-category` | Locale category generation |

View active overrides:

```powershell
(Get-SldgAIProvider).ModelOverrides
```

---

## How AI Works in the Pipeline

### 1. Semantic Analysis (`Get-SldgColumnAnalysis -UseAI`)

AI receives the full database schema and returns:

| Field | Description |
|---|---|
| `SemanticType` | Classification (FirstName, Email, Money, ZipCode, …) |
| `IsPII` | Whether the column contains personally identifiable information |
| `Confidence` | 0.0–1.0 confidence score |
| `ValueExamples` | Sample realistic values in the target locale |
| `ValuePattern` | Regex or format string for generated values |
| `CrossColumnDependency` | Relationships (e.g., Email should match FirstName+LastName) |
| `GenerationHint` | Specific instructions for the generator |

AI recognizes column names in **any language**:

- Czech: `Jmeno` → FirstName, `Prijmeni` → LastName, `Telefon` → Phone, `PSC` → ZipCode
- German: `Vorname` → FirstName, `Nachname` → LastName, `Strasse` → Street, `PLZ` → ZipCode
- Business context: `Orders.Total` → Money (not Integer), `Products.SKU` → Identifier

### 2. Plan Advice (`New-SldgGenerationPlan -UseAI`)

AI analyzes the schema and suggests:

- **Row counts**: Lookup tables (10–50), transaction tables (1000+), bridge tables scaled to parents
- **Table types**: Lookup, Transaction, Bridge, Config
- **Custom rules**: Realistic value lists for Status/Type columns, format hints

```powershell
$plan = New-SldgGenerationPlan -Schema $analyzed -RowCount 100 -UseAI -IndustryHint 'Healthcare'
# AI might suggest: dbo.PatientStatus -> 5 rows, dbo.Patient -> 500, dbo.Visit -> 2000
```

### 3. Data Generation

When enabled via `Set-SldgAIProvider -EnableAIGeneration`, `Invoke-SldgDataGeneration` uses AI to generate entire rows:

- AI receives column definitions, semantic types, locale, cross-column dependencies
- Generates batches of 50 rows as JSON arrays
- Ensures cross-column consistency (Email matches Name, Address is coherent)
- Falls back to static generators for FK columns or when AI is unavailable
- Results are cached per table/column signature

### 4. Locale Generation

When enabled via `Set-SldgAIProvider -EnableAILocale`, AI generates locale data pools on-the-fly:

```powershell
Register-SldgLocale -Name 'ja-JP' -UseAI -PoolSize 50
```

Fallback chain: registered static pack → AI cache → AI generation → en-US.

---

## JSON and XML Column Configuration

Columns classified as `Json` or `Xml` (typically `nvarchar(max)`, `text`, `xml`) get structured values automatically. AI uses column and table names to infer what kind of document to generate.

### Context-Dependent Generation

When a JSON/XML column should produce **different structures depending on another column's value**, use `-CrossColumnDependency`:

```powershell
# Step 1 — Define the driving column values
Set-SldgGenerationRule -Plan $plan -TableName 'dbo.UsageReport' `
    -ColumnName 'ReportType' -ValueList @(
        'UserActivity', 'MailboxUsage', 'OneDriveUsage',
        'TeamsDeviceUsage', 'SharePointSiteUsage'
    )

# Step 2 — Link the JSON column to the driving column
Set-SldgGenerationRule -Plan $plan -TableName 'dbo.UsageReport' `
    -ColumnName 'ReportData' `
    -Generator 'Json' `
    -AIGenerationHint 'Generate Microsoft 365 usage report data. Vary JSON structure by report type:
        UserActivity -> sessions, actions, lastLogin;
        MailboxUsage -> storage, itemCount, quotaUsed;
        OneDriveUsage -> filesCount, storageUsed, sharedFiles;
        TeamsDeviceUsage -> deviceType, usageMinutes, lastActivity;
        SharePointSiteUsage -> siteUrl, pageViews, storageUsed.' `
    -CrossColumnDependency 'ReportType'
```

**How it works:**

1. The module reorders columns so `ReportType` is generated **before** `ReportData`.
2. For each row, after generating `ReportType` (e.g., `'MailboxUsage'`), the value is stored in `$rowContext`.
3. When generating `ReportData`, the engine passes `ContextColumn = 'ReportType'`, `ContextValue = 'MailboxUsage'` to the AI prompt.
4. AI uses the `structured-value-contextual` prompt template to vary the document structure.
5. Cache key includes the context value, so each report type gets its own pool of AI-generated documents.

**Result**: `UserActivity` rows get `{"sessions":12,"actions":["login","viewReport"],"lastLogin":"2026-03-18"}` while `MailboxUsage` rows get `{"storage":"4.2 GB","itemCount":1247,"quotaUsed":0.42}`.

### Resolution Chain

The engine resolves JSON/XML values in this order:

1. **Custom rule** — `ValueList`, `StaticValue`, or `ScriptBlock` wins
2. **AI structured-value** — generates 10 realistic documents, caches them, picks randomly
3. **Static heuristic fallback** — pattern-matches column name to a template category

Static fallback categories:

| Column Name Pattern | Generated JSON |
|---|---|
| `setting`, `config`, `preference`, `option` | `{"theme":"dark","language":"cs","notifications":true,"itemsPerPage":25}` |
| `metadata`, `property`, `attribute` | `{"version":"2.1","tags":["important"],"source":"import","author":"system"}` |
| `address`, `location`, `geo` | `{"street":"Hlavni 15","city":"Praha","zip":"110 00","lat":50.08,"lon":14.43}` |
| `payload`, `data`, `content`, `body` | `{"orderId":"ORD-4521","items":3,"amount":1250.00,"status":"processed"}` |
| _(anything else)_ | Generic key-value pairs |

### Configuration Options

```powershell
# Option A: Let AI generate (recommended — AI infers from column+table name)
# Nothing to configure — just enable AI generation

# Option B: AI hint — tell AI what structure you want
Set-SldgGenerationRule -Plan $plan -TableName 'dbo.Project' `
    -ColumnName 'Settings' -Generator 'Json' `
    -AIGenerationHint 'Project settings with theme, notifications, sprint config'

# Option C: Value examples — guide AI output format
Set-SldgGenerationRule -Plan $plan -TableName 'dbo.Config' `
    -ColumnName 'SettingsJson' -Generator 'Json' `
    -AIGenerationHint 'Application configuration' `
    -ValueExamples @(
        '{"theme":"dark","language":"cs","notifications":{"email":true}}',
        '{"theme":"light","language":"en","notifications":{"email":false}}'
    )

# Option D: Value list — pick from predefined JSON documents
Set-SldgGenerationRule -Plan $plan -TableName 'dbo.Customer' `
    -ColumnName 'Preferences' -ValueList @(
        '{"theme":"dark","language":"cs","notifications":true,"pageSize":25}',
        '{"theme":"light","language":"en","notifications":false,"pageSize":50}'
    )

# Option E: ScriptBlock — full control
Set-SldgGenerationRule -Plan $plan -TableName 'dbo.Product' `
    -ColumnName 'Metadata' -ScriptBlock {
        @{
            version   = "1.$(Get-Random -Max 9)"
            weight_kg = [math]::Round((Get-Random -Minimum 1 -Maximum 500) / 10, 2)
            tags      = @('electronics','sale') | Get-Random -Count (Get-Random -Min 1 -Max 2)
            warehouse = "WH-$(Get-Random -Min 1 -Max 5)"
        } | ConvertTo-Json -Compress
    }
```

### Per-Purpose Model for Structured Values

For better JSON/XML quality, use a code-focused model:

```powershell
Set-SldgAIProvider -Provider Ollama -Model 'llama3' -EnableAIGeneration
Set-SldgAIProvider -Provider Ollama -Model 'codellama' -Purpose 'structured-value'
```

---

## Locales

### Setting the Locale

```powershell
Set-SldgAIProvider -Provider Ollama -Model 'llama3' -EnableAIGeneration -EnableAILocale -Locale 'cs-CZ'
```

### Built-in Locales

Two locales are available without AI:

| Locale | Content |
|---|---|
| `en-US` | English names, US addresses, US phone format, USD currency |
| `cs-CZ` | Czech names, Czech streets, PSC format, +420 phones, s.r.o./a.s. suffixes |

### AI-Generated Locales

Generate a complete locale for any culture code:

```powershell
Register-SldgLocale -Name 'de-DE' -UseAI -PoolSize 50
Register-SldgLocale -Name 'ja-JP' -UseAI -PoolSize 30 `
    -CustomInstructions 'Use Hiragana for names, include Tokyo/Osaka/Kyoto addresses'
```

### Mixed Locales

Combine categories from different cultures:

```powershell
Register-SldgLocale -Name 'mixed-international' -MixFrom @{
    PersonNames = 'cs-CZ'
    Addresses   = 'de-DE'
    Companies   = 'en-US'
    Identifiers = 'cs-CZ'
}
```

If a source locale is not registered yet, the system generates it via AI automatically (when `EnableAILocale` is on).

### Fallback Chain

1. **Registered static pack** — `Register-SldgLocale -Data` or built-in cs-CZ/en-US
2. **AI cache** — previously generated locale data (in-memory)
3. **AI generation** — real-time AI generation (if `EnableAILocale` is on)
4. **en-US fallback** — always available

See [Extending — Custom Locale](extending.md#custom-locale) for registering locales with your own static data.

---

## Scenario Mode

Built-in scenario templates define table roles and row multipliers for common industries:

```powershell
$plan = New-SldgGenerationPlan -Schema $analyzed -Mode Scenario `
    -ScenarioName Auto -RowCount 100
```

| Scenario | Tables Recognized | Example Value Rules |
|---|---|---|
| **eCommerce** | Customer, Product, Order, OrderDetail, Category | OrderStatus: Pending/Shipped/Delivered |
| **Healthcare** | Patient, Visit, Diagnosis, Doctor, Department | Priority: Low/Medium/High/Critical |
| **HR** | Employee, Department, Salary, Leave, Training | LeaveStatus: Pending/Approved/Rejected |
| **Finance** | Account, Transaction, Ledger, Branch, Currency | TransactionType: Credit/Debit/Transfer |
| **Education** | Student, Course, Enrollment, Grade, Teacher | EnrollmentStatus: Active/Completed/Withdrawn |

Auto-detection requires 3+ table name matches against the scenario patterns.

---

## Prompt Customization

All AI prompts are externalized as `.prompt` template files with YAML front matter. You can inspect, modify, or override any prompt without editing module code.

### Template Structure

```
---
purpose: column-analysis
description: Classifies database columns by semantic type
version: 2
---
You are a database schema analyst. Given the following table schema...
{{SchemaJson}}
...return a JSON array of column classifications.
```

- **YAML front matter** — metadata (purpose, description, version)
- **`{{Variable}}` placeholders** — substituted at runtime
- **Variant system** — `purpose.variant.prompt` naming (e.g., `column-analysis.default.prompt`, `column-analysis.ollama.prompt`)

### Managing Prompts

```powershell
# List all prompts
Get-SldgPromptTemplate

# View content
Get-SldgPromptTemplate -Purpose column-analysis -IncludeContent

# Create a custom override
Set-SldgPromptTemplate -Purpose 'structured-value' -Content $myPrompt -Description 'Custom JSON generator'

# Copy built-in and modify
$template = Get-SldgPromptTemplate -Purpose structured-value -IncludeContent
$modified = $template.Content -replace 'Generate 10', 'Generate 20'
Set-SldgPromptTemplate -Purpose structured-value -Content $modified -Force

# Create provider-specific override
Set-SldgPromptTemplate -Purpose column-analysis -Variant ollama -FilePath '.\my-ollama-prompt.txt'

# Remove custom override (falls back to built-in)
Remove-SldgPromptTemplate -Purpose 'structured-value'
```

### Resolution Order

1. Custom override for the specific provider variant (e.g., `column-analysis.ollama.prompt` in AI.PromptPath)
2. Custom override for the default variant (e.g., `column-analysis.default.prompt` in AI.PromptPath)
3. Built-in provider variant (e.g., `column-analysis.ollama.prompt` in module internals)
4. Built-in default variant (e.g., `column-analysis.default.prompt` in module internals)

### Available Prompt Purposes

| Purpose | Used By |
|---|---|
| `column-analysis` | `Get-SldgColumnAnalysis -UseAI` |
| `batch-generation` | `Invoke-SldgDataGeneration` (AI mode) |
| `plan-advice` | `New-SldgGenerationPlan -UseAI` |
| `structured-value` | JSON/XML value generation |
| `structured-value-contextual` | Context-dependent JSON/XML (uses `-CrossColumnDependency`) |
| `locale-data` | `Register-SldgLocale -UseAI` |
| `locale-category` | Locale category generation |

---

## Walkthrough: Project Database with OpenAI

End-to-end example — SQL Server database with 6 tables, JSON and XML columns, OpenAI GPT-4o.

### Database Schema

```sql
CREATE TABLE dbo.Department (
    Id            INT PRIMARY KEY IDENTITY(1,1),
    Name          NVARCHAR(100)  NOT NULL,
    Code          VARCHAR(10)    NOT NULL UNIQUE,
    ManagerName   NVARCHAR(100)  NULL,
    Budget        DECIMAL(12,2)  NULL,
    IsActive      BIT            NOT NULL DEFAULT 1
);

CREATE TABLE dbo.Employee (
    Id            INT PRIMARY KEY IDENTITY(1,1),
    FirstName     NVARCHAR(50)   NOT NULL,
    LastName      NVARCHAR(50)   NOT NULL,
    Email         NVARCHAR(100)  NOT NULL UNIQUE,
    Phone         VARCHAR(20)    NULL,
    HireDate      DATE           NOT NULL,
    Salary        DECIMAL(10,2)  NULL,
    DepartmentId  INT            NOT NULL REFERENCES dbo.Department(Id),
    IsActive      BIT            NOT NULL DEFAULT 1
);

CREATE TABLE dbo.Project (
    Id            INT PRIMARY KEY IDENTITY(1,1),
    Name          NVARCHAR(200)  NOT NULL,
    Code          VARCHAR(20)    NOT NULL UNIQUE,
    Description   NVARCHAR(500)  NULL,
    StartDate     DATE           NOT NULL,
    EndDate       DATE           NULL,
    Status        VARCHAR(20)    NOT NULL DEFAULT 'Planning',
    DepartmentId  INT            NOT NULL REFERENCES dbo.Department(Id),
    Settings      NVARCHAR(MAX)  NULL       -- JSON
);

CREATE TABLE dbo.Task (
    Id            INT PRIMARY KEY IDENTITY(1,1),
    Title         NVARCHAR(200)  NOT NULL,
    Description   NVARCHAR(MAX)  NULL,
    Priority      VARCHAR(10)    NOT NULL DEFAULT 'Medium',
    Status        VARCHAR(20)    NOT NULL DEFAULT 'New',
    EstimatedHours DECIMAL(6,1)  NULL,
    ProjectId     INT            NOT NULL REFERENCES dbo.Project(Id),
    AssigneeId    INT            NULL       REFERENCES dbo.Employee(Id),
    CreatedAt     DATETIME       NOT NULL DEFAULT GETDATE(),
    MetadataXml   XML            NULL       -- XML
);

CREATE TABLE dbo.TimeEntry (
    Id            INT PRIMARY KEY IDENTITY(1,1),
    TaskId        INT            NOT NULL REFERENCES dbo.Task(Id),
    EmployeeId    INT            NOT NULL REFERENCES dbo.Employee(Id),
    EntryDate     DATE           NOT NULL,
    Hours         DECIMAL(4,1)   NOT NULL,
    Note          NVARCHAR(500)  NULL
);

CREATE TABLE dbo.AuditLog (
    Id            INT PRIMARY KEY IDENTITY(1,1),
    TableName     VARCHAR(50)    NOT NULL,
    RecordId      INT            NOT NULL,
    Action        VARCHAR(10)    NOT NULL,
    ChangedBy     NVARCHAR(100)  NOT NULL,
    ChangedAt     DATETIME       NOT NULL DEFAULT GETDATE(),
    Changes       NVARCHAR(MAX)  NULL       -- JSON
);
```

| Table | JSON/XML | Purpose |
|---|---|---|
| `dbo.Department` | — | Simple lookup |
| `dbo.Employee` | — | Standard master table |
| `dbo.Project` | `Settings` (JSON) | Projects with configuration |
| `dbo.Task` | `MetadataXml` (XML) | Tasks with XML metadata |
| `dbo.TimeEntry` | — | Simple transaction table |
| `dbo.AuditLog` | `Changes` (JSON) | Audit trail with JSON diffs |

### Step 1 — Connect and Configure

```powershell
Connect-SldgDatabase -ServerInstance 'localhost' -Database 'ProjectDB'

Set-SldgAIProvider -Provider OpenAI `
    -Model 'gpt-4o' `
    -ApiKey $env:OPENAI_API_KEY `
    -EnableAIGeneration `
    -EnableAILocale `
    -Locale 'cs-CZ'

Test-SldgAIProvider
```

### Step 2 — Discover and Analyze

```powershell
$schema   = Get-SldgDatabaseSchema
$analyzed = Get-SldgColumnAnalysis -Schema $schema -UseAI -Locale 'cs-CZ'
```

GPT-4o classifies each column:

| Table | Column | Semantic Type | PII |
|---|---|---|---|
| dbo.Employee | FirstName | FirstName | Yes |
| dbo.Employee | LastName | LastName | Yes |
| dbo.Employee | Email | Email | Yes |
| dbo.Employee | Salary | Money | No |
| dbo.Project | Settings | **Json** | No |
| dbo.Task | MetadataXml | **Xml** | No |
| dbo.AuditLog | Changes | **Json** | No |

FK columns (`DepartmentId`, `ProjectId`, `AssigneeId`, `TaskId`, `EmployeeId`) are automatically skipped — they get filled from parent table values.

### Step 3 — Plan with AI

```powershell
$plan = New-SldgGenerationPlan -Schema $analyzed -RowCount 100 -UseAI
```

AI suggests:

| Table | Rows | Type |
|---|---|---|
| dbo.Department | 8 | Lookup |
| dbo.Employee | 100 | Master |
| dbo.Project | 25 | Master |
| dbo.Task | 200 | Transaction |
| dbo.TimeEntry | 600 | Detail |
| dbo.AuditLog | 150 | Log |

### Step 4 — Custom Rules

```powershell
# --- Simple tables ---
Set-SldgGenerationRule -Plan $plan -TableName 'dbo.Department' `
    -ColumnName 'Name' -ValueList @(
        'Engineering', 'Marketing', 'Sales', 'Finance',
        'HR', 'Legal', 'Operations', 'Support', 'R&D', 'QA'
    )

Set-SldgGenerationRule -Plan $plan -TableName 'dbo.Employee' `
    -ColumnName 'Email' -Generator 'Email' `
    -GeneratorParams @{ Domain = 'projectcorp.com' }

Set-SldgGenerationRule -Plan $plan -TableName 'dbo.Project' `
    -ColumnName 'Status' -ValueList @('Planning', 'Active', 'OnHold', 'Completed', 'Cancelled')

Set-SldgGenerationRule -Plan $plan -TableName 'dbo.Task' `
    -ColumnName 'Status' -ValueList @('New', 'InProgress', 'Review', 'Done', 'Blocked')

Set-SldgGenerationRule -Plan $plan -TableName 'dbo.Task' `
    -ColumnName 'Priority' -ValueList @('Low', 'Medium', 'High', 'Critical')

# --- JSON: Project Settings ---
Set-SldgGenerationRule -Plan $plan -TableName 'dbo.Project' `
    -ColumnName 'Settings' -ScriptBlock {
        @{
            notifications = @{
                email   = @($true, $false) | Get-Random
                slack   = @($true, $false) | Get-Random
                channel = @('#proj-general', '#proj-updates', '#proj-alerts') | Get-Random
            }
            visibility   = @('public', 'team', 'private') | Get-Random
            tags         = @('backend','frontend','api','mobile','infra','devops') |
                           Get-Random -Count (Get-Random -Minimum 1 -Maximum 4)
            sprintLength = @(7, 14, 21) | Get-Random
        } | ConvertTo-Json -Depth 3 -Compress
    }

# --- XML: Task Metadata ---
Set-SldgGenerationRule -Plan $plan -TableName 'dbo.Task' `
    -ColumnName 'MetadataXml' -ScriptBlock {
        $labels   = @('bug','feature','improvement','tech-debt','security','ux')
        $selected = $labels | Get-Random -Count (Get-Random -Minimum 1 -Maximum 3)
        $labelXml = ($selected | ForEach-Object { "    <Label>$_</Label>" }) -join "`n"
        $envs     = @('Development','Staging','Production')
        @"
<TaskMetadata>
  <Labels>
$labelXml
  </Labels>
  <CustomFields>
    <Field name="Environment" type="String">$($envs | Get-Random)</Field>
    <Field name="StoryPoints" type="Integer">$(Get-Random -Minimum 1 -Maximum 13)</Field>
    <Field name="Billable" type="Boolean">$(@('true','false') | Get-Random)</Field>
  </CustomFields>
</TaskMetadata>
"@
    }

# --- JSON: Audit Changes ---
Set-SldgGenerationRule -Plan $plan -TableName 'dbo.AuditLog' `
    -ColumnName 'Action' -ValueList @('INSERT', 'UPDATE', 'DELETE')

Set-SldgGenerationRule -Plan $plan -TableName 'dbo.AuditLog' `
    -ColumnName 'Changes' -ScriptBlock {
        $fields = @(
            @{ field = 'Status';   old = 'New';      new = 'InProgress' },
            @{ field = 'Priority'; old = 'Medium';   new = 'High' },
            @{ field = 'Salary';   old = '45000';    new = '52000' },
            @{ field = 'IsActive'; old = 'true';     new = 'false' }
        )
        $count   = Get-Random -Minimum 1 -Maximum 3
        $changes = @{}
        $fields | Get-Random -Count $count | ForEach-Object {
            $changes[$_.field] = @{ old = $_.old; new = $_.new }
        }
        $changes | ConvertTo-Json -Compress
    }
```

### Step 5 — Generate

```powershell
$result = Invoke-SldgDataGeneration -Plan $plan
$result.Tables | Format-Table TableName, RowCount, Success -AutoSize
```

```
TableName        RowCount Success
---------        -------- -------
dbo.Department         10    True
dbo.Employee          100    True
dbo.Project            25    True
dbo.Task              200    True
dbo.TimeEntry        1000    True
dbo.AuditLog          150    True
```

Generation order follows FK dependencies:

1. `dbo.Department` — no dependencies
2. `dbo.Employee` — depends on Department
3. `dbo.Project` — depends on Department
4. `dbo.Task` — depends on Project and Employee
5. `dbo.TimeEntry` — depends on Task and Employee
6. `dbo.AuditLog` — no FK dependencies

### Step 6 — Validate and Inspect

```powershell
Test-SldgGeneratedData -Schema $analyzed
```

```
TableName        Checks   Passed  Failed
---------        ------   ------  ------
dbo.Department        5        5       0
dbo.Employee          7        7       0
dbo.Project           6        6       0
dbo.Task              8        8       0
dbo.TimeEntry         5        5       0
dbo.AuditLog          4        4       0
```

Sample data:

```powershell
$result = Invoke-SldgDataGeneration -Plan $plan -NoInsert -PassThru
$employees = ($result.Tables | Where-Object TableName -eq 'dbo.Employee').DataTable
$employees | Select-Object FirstName, LastName, Email, Salary -First 3
```

```
FirstName  LastName     Email                               Salary
---------  --------     -----                               ------
Martin     Prochazka    martin.prochazka@projectcorp.com    62000.00
Katerina   Dvorakova    katerina.dvorakova@projectcorp.com  58500.00
Tomas      Novotny      tomas.novotny@projectcorp.com       71200.00
```

### Step 7 — Export Profile

```powershell
Export-SldgGenerationProfile -Plan $plan -Path '.\projectdb-profile.json' -IncludeSemanticAnalysis
Disconnect-SldgDatabase
```

---

## Walkthrough: Czech Healthcare Database

A more complex example with Czech column names, multiple locales, JSON/XML columns, and Scenario mode.

### Database Schema

```sql
CREATE TABLE dbo.Oddeleni (        -- Department
    Id INT PRIMARY KEY IDENTITY,
    Nazev NVARCHAR(100),           -- Name
    Kod VARCHAR(10),               -- Code
    Aktivni BIT                    -- IsActive
);

CREATE TABLE dbo.Lekar (           -- Doctor
    Id INT PRIMARY KEY IDENTITY,
    Jmeno NVARCHAR(50),           -- FirstName
    Prijmeni NVARCHAR(50),        -- LastName
    Titul VARCHAR(20),            -- Title
    Email NVARCHAR(100),
    Telefon VARCHAR(20),          -- Phone
    OddeleniId INT REFERENCES dbo.Oddeleni(Id),
    Specialization NVARCHAR(max)  -- JSON: certifications, languages
);

CREATE TABLE dbo.Pacient (         -- Patient
    Id INT PRIMARY KEY IDENTITY,
    Jmeno NVARCHAR(50),
    Prijmeni NVARCHAR(50),
    RodneCislo VARCHAR(11),       -- National ID
    DatumNarozeni DATE,           -- BirthDate
    Email NVARCHAR(100),
    Telefon VARCHAR(20),
    Adresa NVARCHAR(200),         -- Address
    Preference NVARCHAR(max)      -- JSON: language, notifications
);

CREATE TABLE dbo.Navsteva (        -- Visit
    Id INT PRIMARY KEY IDENTITY,
    PacientId INT REFERENCES dbo.Pacient(Id),
    LekarId INT REFERENCES dbo.Lekar(Id),
    DatumNavstevy DATETIME,       -- VisitDate
    Stav VARCHAR(20),             -- Status
    Diagnoza NVARCHAR(500),       -- Diagnosis
    Poznamky NVARCHAR(max),       -- Notes (XML)
    Cena DECIMAL(10,2)            -- Price
);
```

### Step 1 — Setup

```powershell
Connect-SldgDatabase -ServerInstance 'localhost' -Database 'NemocniceDB'

# Ollama for general tasks, GPT-4o for batch generation
Set-SldgAIProvider -Provider Ollama -Model 'llama3' `
    -EnableAIGeneration -EnableAILocale -Locale 'cs-CZ'
Set-SldgAIProvider -Provider OpenAI -Model 'gpt-4o' `
    -ApiKey $env:OPENAI_API_KEY -Purpose 'batch-generation'
```

### Step 2 — Discover and Analyze

```powershell
$schema   = Get-SldgDatabaseSchema
$analyzed = Get-SldgColumnAnalysis -Schema $schema -UseAI -Locale 'cs-CZ'
```

AI classifies Czech column names:

- `Jmeno` → FirstName (PII), `Prijmeni` → LastName (PII)
- `RodneCislo` → NationalId (PII), `DatumNarozeni` → BirthDate (PII)
- `Telefon` → Phone (PII), `Adresa` → Address (PII)
- `Stav` → Status, `Diagnoza` → MediumString, `Cena` → Money
- `Specialization`, `Preference` → Json, `Poznamky` → Xml

### Step 3 — Plan with Healthcare Scenario

```powershell
$plan = New-SldgGenerationPlan -Schema $analyzed -Mode Scenario `
    -ScenarioName 'Healthcare' -RowCount 200 -UseAI -IndustryHint 'Healthcare CZ'
```

| Table | Role | Rows |
|---|---|---|
| dbo.Oddeleni | Lookup | 10 |
| dbo.Lekar | Reference | 20 |
| dbo.Pacient | Master | 200 |
| dbo.Navsteva | Transaction | 1000 |

### Step 4 — Custom Rules

```powershell
Set-SldgGenerationRule -Plan $plan -TableName 'dbo.Oddeleni' `
    -ColumnName 'Nazev' -ValueList @(
        'Kardiologie', 'Neurologie', 'Ortopedie', 'Chirurgie',
        'Interna', 'Pediatrie', 'Onkologie', 'Urologie',
        'Gynekologie', 'Anesteziologie'
    )

Set-SldgGenerationRule -Plan $plan -TableName 'dbo.Navsteva' `
    -ColumnName 'Stav' -ValueList @(
        'Planovana', 'Probihajici', 'Dokoncena', 'Zrusena', 'Neodstavena'
    )

Set-SldgGenerationRule -Plan $plan -TableName 'dbo.Lekar' `
    -ColumnName 'Titul' -ValueList @('MUDr.', 'doc. MUDr.', 'prof. MUDr.', 'MDDr.')

# Doctor specialization — JSON
Set-SldgGenerationRule -Plan $plan -TableName 'dbo.Lekar' `
    -ColumnName 'Specialization' -ScriptBlock {
        $certs = @('Atestace I.','Atestace II.','PhD.','MBA') | Get-Random -Count (Get-Random -Min 1 -Max 3)
        $langs = @('cestina','anglictina','nemcina','rustina') | Get-Random -Count (Get-Random -Min 1 -Max 3)
        @{
            certifications    = $certs
            languages         = $langs
            yearsOfExperience = Get-Random -Minimum 1 -Maximum 35
        } | ConvertTo-Json -Compress
    }

# Patient preferences — JSON
Set-SldgGenerationRule -Plan $plan -TableName 'dbo.Pacient' `
    -ColumnName 'Preference' -ScriptBlock {
        @{
            jazyk       = @('cs','en','de','sk') | Get-Random
            notifikace  = @{
                email = (Get-Random -Max 2) -eq 1
                sms   = (Get-Random -Max 2) -eq 1
            }
            pojistovna  = @('VZP','CPZP','OZP','ZPMV','VoZP') | Get-Random
        } | ConvertTo-Json -Compress
    }

# Visit notes — XML
Set-SldgGenerationRule -Plan $plan -TableName 'dbo.Navsteva' `
    -ColumnName 'Poznamky' -ScriptBlock {
        $codes = @('J06.9','I10','E11','M54.5','K21.0','J45','F32') | Get-Random -Count 2
        @"
<Zaznam>
  <Anamneza>Pacient se dostavil k planovane kontrole.</Anamneza>
  <Vysetreni>
    <MKN10>$($codes[0])</MKN10>
    <MKN10>$($codes[1])</MKN10>
  </Vysetreni>
  <Zaver>Doporucena kontrola za 3 mesice.</Zaver>
</Zaznam>
"@
    }
```

### Step 5 — Generate and Export

```powershell
$result = Invoke-SldgDataGeneration -Plan $plan
$result | Format-Table TableName, RowCount, Success
```

```
TableName       RowCount Success
---------       -------- -------
dbo.Oddeleni          10    True
dbo.Lekar             20    True
dbo.Pacient          200    True
dbo.Navsteva        1000    True
```

```powershell
# Save profile for the team
Export-SldgGenerationProfile -Plan $plan -Path '.\nemocnice-profile.json' -IncludeSemanticAnalysis
Disconnect-SldgDatabase
```

---

## Custom Model Training for Ollama

For maximum quality and speed, you can fine-tune a custom Ollama model specifically for SqlLabDataGenerator tasks.

### Why Train a Custom Model?

| Aspect | General Model (llama3) | Fine-Tuned Model |
|---|---|---|
| Response format | Sometimes needs prompting for JSON | Consistently outputs clean JSON |
| Domain knowledge | General understanding | Knows DB patterns, column semantics |
| Speed | Full reasoning per request | Faster — learned patterns |
| Locale quality | Good for major languages | Excellent for your target locales |

### Step 1: Generate Training Data

Run SqlLabDataGenerator against real (anonymized) databases to collect prompt/response pairs:

```powershell
$VerbosePreference = 'Continue'
Connect-SldgDatabase -ServerInstance 'localhost' -Database 'AdventureWorks'
$schema = Get-SldgDatabaseSchema
$analyzed = Get-SldgColumnAnalysis -Schema $schema -UseAI -Locale 'cs-CZ'
$plan = New-SldgGenerationPlan -Schema $analyzed -UseAI -IndustryHint 'Retail'
Invoke-SldgDataGeneration -Plan $plan -NoInsert
```

Collect prompt/response pairs from verbose output for:

1. **Column classification** — schema in → semantic types out (JSON array)
2. **Plan advice** — schema in → row counts, rules, table types (JSON)
3. **Batch generation** — column defs + locale in → data rows (JSON array)
4. **Locale generation** — culture code in → locale data pack (JSON)

### Step 2: Create Training Dataset

Format as JSONL:

```jsonl
{"messages": [{"role": "system", "content": "You are a database column classifier..."}, {"role": "user", "content": "Analyze this schema: ..."}, {"role": "assistant", "content": "[{\"TableName\": \"dbo.Customer\", ...}]"}]}
```

Recommended minimum: 50+ classification, 30+ plan advice, 100+ batch generation, 20+ locale examples.

### Step 3: Fine-Tune

**Option A — Ollama native:**

```bash
cat > Modelfile << 'EOF'
FROM llama3
SYSTEM """You are SqlLabDataGenerator AI assistant. Analyze database schemas,
classify columns, generate test data, create locale packs.
Always respond with valid JSON. No markdown."""
PARAMETER temperature 0.2
PARAMETER top_p 0.9
PARAMETER num_predict 4096
EOF

ollama create sldg-base -f Modelfile

ollama train sldg-v1 \
    --base sldg-base \
    --dataset training-data.jsonl \
    --epochs 3 \
    --learning-rate 1e-5
```

**Option B — Unsloth + import to Ollama:**

```bash
pip install unsloth

python fine_tune.py \
    --base_model "unsloth/llama-3-8b-Instruct" \
    --dataset training-data.jsonl \
    --output_dir ./sldg-model \
    --epochs 3 --lora_r 16 --lora_alpha 32

python -m unsloth.save \
    --model ./sldg-model \
    --output ./sldg-v1.gguf \
    --quantization q4_k_m

cat > Modelfile << EOF
FROM ./sldg-v1.gguf
SYSTEM """You are SqlLabDataGenerator AI assistant. Respond with valid JSON only."""
PARAMETER temperature 0.2
PARAMETER num_predict 4096
EOF

ollama create sldg-v1 -f Modelfile
```

### Step 4: Use the Custom Model

```powershell
Set-SldgAIProvider -Provider Ollama -Model 'sldg-v1' -EnableAIGeneration -EnableAILocale -Locale 'cs-CZ'
Test-SldgAIProvider
```

### Training Tips

| Tip | Details |
|---|---|
| JSON consistency | Train to output raw JSON without markdown code blocks |
| Column name variety | Include Czech, German, English, mixed-language columns |
| Schema diversity | Mix small (5 tables) and large (50+ tables) schemas |
| Temperature | Use 0.2 for fine-tuned models |
| Quantization | `q4_k_m` balances speed and quality for 8B models |

---

## Performance Tuning

### Caching

The module caches AI responses at multiple levels:

| Cache | Key | Cleared By |
|---|---|---|
| `AIValueCache` | Table + column signatures + locale + context value | `Set-SldgAIProvider`, module reimport |
| `AILocaleCache` | Culture code | `Set-SldgAIProvider`, module reimport |
| `AILocaleCategoryCache` | Language + category | `Set-SldgAIProvider`, module reimport |

### Token Limits

If AI responses are truncated, increase `MaxTokens`:

```powershell
Set-SldgAIProvider -Provider Ollama -Model 'llama3' -MaxTokens 8192
```

### Temperature

| Value | Effect | Use Case |
|---|---|---|
| 0.0 | Deterministic | Reproducible test data |
| 0.2 | Mostly consistent | Fine-tuned models |
| 0.3 | Default — good variety | General use |
| 0.7+ | Creative | Exploration, stress testing |

---

## Troubleshooting

### Test-SldgAIProvider returns NoResponse

```powershell
# Check Ollama is running
ollama list

# Check endpoint
Invoke-RestMethod -Uri 'http://localhost:11434/api/tags'

# Check model exists
ollama show llama3
```

### AI returns invalid JSON

- Increase `MaxTokens` — response may be truncated
- Lower `Temperature` — more deterministic output
- Use a larger model (llama3 8B → 70B, or gpt-4o)
- Train a custom model (see [Custom Model Training](#custom-model-training-for-ollama))

### Slow AI responses

- Use a quantized model (q4_k_m instead of f16)
- Enable GPU acceleration in Ollama
- Cached results make the second run instant
- Reduce batch size for large tables

### API key issues (OpenAI / Azure OpenAI)

```powershell
# Verify key is set
(Get-SldgAIProvider).ApiKeySet  # Should be True

# Test with direct call
$headers = @{ 'Authorization' = "Bearer $env:OPENAI_API_KEY"; 'Content-Type' = 'application/json' }
$body = @{ model = 'gpt-4o'; messages = @(@{ role = 'user'; content = 'Say OK' }) } | ConvertTo-Json
Invoke-RestMethod -Uri 'https://api.openai.com/v1/chat/completions' -Method Post -Headers $headers -Body $body
```