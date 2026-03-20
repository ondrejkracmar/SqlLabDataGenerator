# AI Configuration & Custom Model Training

SqlLabDataGenerator uses AI at three levels:

1. **Semantic Analysis** — classifying what each column means (FirstName, Email, Money, …)
2. **Data Generation** — generating entire rows of realistic, consistent values
3. **Locale Generation** — creating culture-specific data pools for any language

All three levels are optional. Without AI the module falls back to pattern matching and static generators.

---

## Table of Contents

- [Supported AI Providers](#supported-ai-providers)
- [Quick Setup](#quick-setup)
- [Configuration Details](#configuration-details)
- [How AI Is Used in the Pipeline](#how-ai-is-used-in-the-pipeline)
- [Walkthrough: Company Project Database with OpenAI](#walkthrough-company-project-database-with-openai)
- [JSON and XML Column Configuration](#json-and-xml-column-configuration)
- [Generation Profiles (JSON Export / Import)](#generation-profiles-json-export--import)
- [Language and Locale Configuration](#language-and-locale-configuration)
- [Walkthrough: Multi-Language Healthcare Database](#walkthrough-multi-language-healthcare-database)
- [Scenario Mode — Industry Templates](#scenario-mode--industry-templates)
- [Advanced Features](#advanced-features)
  - [Parallel Generation and Streaming](#parallel-generation-and-streaming)
  - [Data Masking (PII Anonymization)](#data-masking-pii-anonymization)
  - [Export to External Systems (Entra ID / Graph API)](#export-to-external-systems-entra-id--graph-api)
- [Prompt Customization](#prompt-customization)
- [Custom Model Training for Ollama](#custom-model-training-for-ollama)
- [Performance Tuning](#performance-tuning)
- [Troubleshooting](#troubleshooting)

---

## Supported AI Providers

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

# 3. Configure in SqlLabDataGenerator
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

## Configuration Details

### Management Cmdlets

| Cmdlet | Purpose |
|---|---|
| `Set-SldgAIProvider` | Configure provider, model, endpoint, enable features, and per-purpose overrides |
| `Get-SldgAIProvider` | Display current configuration and active model overrides |
| `Test-SldgAIProvider` | Test connectivity and measure response time |
| `Get-SldgPromptTemplate` | List or read AI prompt templates (built-in and custom) |
| `Set-SldgPromptTemplate` | Create or update a custom prompt template override |
| `Remove-SldgPromptTemplate` | Remove a custom prompt override (falls back to built-in) |

### Set-SldgAIProvider Parameters

```powershell
Set-SldgAIProvider
    -Provider <None|OpenAI|AzureOpenAI|Ollama>    # Required
    [-Model <string>]                               # e.g. 'llama3', 'gpt-4o', 'mistral'
    [-Endpoint <string>]                            # URL (auto for OpenAI/Ollama localhost)
    [-ApiKey <string>]                              # Required for OpenAI/AzureOpenAI
    [-MaxTokens <int>]                              # Default: 4096
    [-Temperature <double>]                         # Ollama: 0.0–1.0, default 0.3
    [-EnableAIGeneration]                           # Turn on AI row generation
    [-EnableAILocale]                               # Turn on AI locale generation
    [-SkipCertificateCheck]                         # Ollama dev servers with self-signed certs
    [-Locale <string>]                              # e.g. 'cs-CZ', 'de-DE'
    [-Credential <PSCredential>]                    # Alternative to -ApiKey
    [-Purpose <string>]                             # Per-purpose model override
```

### Per-Purpose AI Model Overrides

Use `-Purpose` to assign a different AI model for specific tasks:

```powershell
# Global: GPT-4o for all tasks
Set-SldgAIProvider -Provider OpenAI -Model 'gpt-4o' -ApiKey $key

# Override: Ollama llama3 for batch data generation (faster, local, free)
Set-SldgAIProvider -Provider Ollama -Model 'llama3' -Purpose 'batch-generation'

# Override: codellama for structured JSON/XML value generation
Set-SldgAIProvider -Provider Ollama -Model 'codellama' -Purpose 'structured-value'
```

Available purposes:

| Purpose | Description |
|---|---|
| `column-analysis` | Semantic column classification |
| `batch-generation` | AI row generation (entire rows of data) |
| `plan-advice` | AI plan advisor (row counts, rules) |
| `structured-value` | Structured JSON/XML value generation |
| `locale-data` | AI locale data pack generation |
| `locale-category` | AI locale category generation |

View active overrides:

```powershell
(Get-SldgAIProvider).ModelOverrides
```

---

## How AI Is Used in the Pipeline

### 1. Semantic Analysis (`Get-SldgColumnAnalysis -UseAI`)

AI receives the full database schema as a structured prompt and returns:

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
# AI might suggest: dbo.PatientStatus → 5 rows, dbo.Patient → 500, dbo.Visit → 2000
```

### 3. Data Generation (`Generation.AIGeneration = $true`)

When enabled, `Invoke-SldgDataGeneration` uses AI to generate entire rows at once:

- AI receives column definitions, semantic types, locale, cross-column dependencies
- Generates batches of 50 rows as JSON arrays
- Ensures cross-column consistency (Email matches Name, Address is coherent, etc.)
- Falls back to static generators for columns with FK constraints or when AI is unavailable
- Results are cached per table/column signature

### 4. Locale Generation (`Generation.AILocale = $true`)

AI generates locale data pools on-the-fly for any culture code:

```powershell
# AI generates everything — Czech names, addresses, phone formats, companies…
Register-SldgLocale -Name 'cs-CZ' -UseAI -PoolSize 50

# Mix languages — Czech names, German addresses, English companies
Register-SldgLocale -Name 'mixed' -MixFrom @{
    PersonNames = 'cs-CZ'
    Addresses   = 'de-DE'
    Companies   = 'en-US'
}
```

Fallback chain: registered static pack → AI cache → AI generation → en-US.

---

## Walkthrough: Company Project Database with OpenAI

This walkthrough covers a complete scenario — from creating the database schema in SQL, through AI configuration with OpenAI, to generating data for all tables including those with JSON/XML columns.

This example uses a database `ProjectDB` with 6 tables. Some tables store only simple scalar data, others contain JSON or XML columns. The example uses **OpenAI GPT-4o** as the AI provider.

### Database Schema (SQL Server)

Run this SQL to create the database structure:

```sql
-- ============================================================
-- Database: ProjectDB
-- 6 tables, FK relationships, JSON and XML columns
-- ============================================================

-- 1) Departments — simple lookup table (no JSON/XML)
CREATE TABLE dbo.Department (
    Id            INT PRIMARY KEY IDENTITY(1,1),
    Name          NVARCHAR(100)  NOT NULL,
    Code          VARCHAR(10)    NOT NULL UNIQUE,
    ManagerName   NVARCHAR(100)  NULL,
    Budget        DECIMAL(12,2)  NULL,
    IsActive      BIT            NOT NULL DEFAULT 1
);

-- 2) Employees — standard table (no JSON/XML)
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

-- 3) Projects — contains JSON column (Settings)
CREATE TABLE dbo.Project (
    Id            INT PRIMARY KEY IDENTITY(1,1),
    Name          NVARCHAR(200)  NOT NULL,
    Code          VARCHAR(20)    NOT NULL UNIQUE,
    Description   NVARCHAR(500)  NULL,
    StartDate     DATE           NOT NULL,
    EndDate       DATE           NULL,
    Status        VARCHAR(20)    NOT NULL DEFAULT 'Planning',
    DepartmentId  INT            NOT NULL REFERENCES dbo.Department(Id),
    Settings      NVARCHAR(MAX)  NULL       -- JSON: notifications, visibility, tags
);

-- 4) Tasks — contains XML column (MetadataXml)
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
    MetadataXml   XML            NULL       -- XML: labels, custom fields, history
);

-- 5) TimeEntries — simple transaction table (no JSON/XML)
CREATE TABLE dbo.TimeEntry (
    Id            INT PRIMARY KEY IDENTITY(1,1),
    TaskId        INT            NOT NULL REFERENCES dbo.Task(Id),
    EmployeeId    INT            NOT NULL REFERENCES dbo.Employee(Id),
    EntryDate     DATE           NOT NULL,
    Hours         DECIMAL(4,1)   NOT NULL,
    Note          NVARCHAR(500)  NULL
);

-- 6) AuditLog — contains JSON column (Changes)
CREATE TABLE dbo.AuditLog (
    Id            INT PRIMARY KEY IDENTITY(1,1),
    TableName     VARCHAR(50)    NOT NULL,
    RecordId      INT            NOT NULL,
    Action        VARCHAR(10)    NOT NULL,   -- INSERT, UPDATE, DELETE
    ChangedBy     NVARCHAR(100)  NOT NULL,
    ChangedAt     DATETIME       NOT NULL DEFAULT GETDATE(),
    Changes       NVARCHAR(MAX)  NULL        -- JSON: {field: {old, new}} diff
);
```

Table summary:

| Table | JSON/XML | Purpose |
|---|---|---|
| `dbo.Department` | — | Simple lookup (departments) |
| `dbo.Employee` | — | Standard master table (people) |
| `dbo.Project` | `Settings` (JSON) | Projects with configuration JSON |
| `dbo.Task` | `MetadataXml` (XML) | Tasks with XML metadata |
| `dbo.TimeEntry` | — | Simple transaction table (hours) |
| `dbo.AuditLog` | `Changes` (JSON) | Audit trail with JSON change diff |

### Step 1 — Connect to Database and Configure OpenAI

```powershell
# Connect to the database
Connect-SldgDatabase -ServerInstance 'localhost' -Database 'ProjectDB'

# Configure OpenAI as the AI provider
Set-SldgAIProvider -Provider OpenAI `
    -Model 'gpt-4o' `
    -ApiKey $env:OPENAI_API_KEY `
    -EnableAIGeneration `
    -EnableAILocale `
    -Locale 'cs-CZ'

# Verify connectivity
Test-SldgAIProvider
```

**Output:**
```
Provider   : OpenAI
Model      : gpt-4o
Status     : Connected
ResponseMs : 487
```

### Step 2 — Discover and Analyze Schema

```powershell
# Extract full schema — tables, columns, FKs, PKs, unique constraints
$schema = Get-SldgDatabaseSchema

# AI classifies every column semantically
$analyzed = Get-SldgColumnAnalysis -Schema $schema -UseAI -Locale 'cs-CZ'
```

GPT-4o classifies each column:

**dbo.Department** (no JSON/XML):
| Column | Semantic Type | PII |
|---|---|---|
| Name | ShortString | No |
| Code | Identifier | No |
| ManagerName | FullName | Yes |
| Budget | Money | No |
| IsActive | Boolean | No |

**dbo.Employee** (no JSON/XML):
| Column | Semantic Type | PII |
|---|---|---|
| FirstName | FirstName | Yes |
| LastName | LastName | Yes |
| Email | Email | Yes |
| Phone | Phone | Yes |
| HireDate | Date | No |
| Salary | Money | No |
| DepartmentId | _(FK — skipped)_ | — |

**dbo.Project** (has JSON):
| Column | Semantic Type | PII |
|---|---|---|
| Name | ShortString | No |
| Code | Identifier | No |
| Description | MediumString | No |
| StartDate | Date | No |
| EndDate | Date | No |
| Status | Status | No |
| Settings | **Json** | No |

**dbo.Task** (has XML):
| Column | Semantic Type | PII |
|---|---|---|
| Title | ShortString | No |
| Description | LongString | No |
| Priority | Status | No |
| Status | Status | No |
| EstimatedHours | Decimal | No |
| CreatedAt | DateTime | No |
| MetadataXml | **Xml** | No |

**dbo.TimeEntry** (no JSON/XML):
| Column | Semantic Type | PII |
|---|---|---|
| EntryDate | Date | No |
| Hours | Decimal | No |
| Note | MediumString | No |

**dbo.AuditLog** (has JSON):
| Column | Semantic Type | PII |
|---|---|---|
| TableName | ShortString | No |
| RecordId | Integer | No |
| Action | Status | No |
| ChangedBy | FullName | Yes |
| ChangedAt | DateTime | No |
| Changes | **Json** | No |

FK columns (`DepartmentId`, `ProjectId`, `AssigneeId`, `TaskId`, `EmployeeId`) are automatically skipped by AI — they will be filled from parent table values during generation.

### Step 3 — Create Generation Plan with AI Row Counts

```powershell
# AI analyzes the schema and suggests realistic row counts per table
$plan = New-SldgGenerationPlan -Schema $analyzed -RowCount 100 -UseAI
```

AI suggests:

| Table | AI-Suggested Rows | Table Type |
|---|---|---|
| dbo.Department | 8 | Lookup |
| dbo.Employee | 100 | Master |
| dbo.Project | 25 | Master |
| dbo.Task | 200 | Transaction |
| dbo.TimeEntry | 600 | Detail |
| dbo.AuditLog | 150 | Log |

You can also override specific tables:

```powershell
$plan = New-SldgGenerationPlan -Schema $analyzed -RowCount 100 -UseAI `
    -TableRowCounts @{
        'dbo.Department' = 10
        'dbo.TimeEntry'  = 1000
    }
```

### Step 4 — Custom Rules for Simple Tables (no JSON/XML)

```powershell
# --- dbo.Department ---
Set-SldgGenerationRule -Plan $plan -TableName 'dbo.Department' `
    -ColumnName 'Name' -ValueList @(
        'Engineering', 'Marketing', 'Sales', 'Finance',
        'HR', 'Legal', 'Operations', 'Support', 'R&D', 'QA'
    )

Set-SldgGenerationRule -Plan $plan -TableName 'dbo.Department' `
    -ColumnName 'Code' -ValueList @(
        'ENG', 'MKT', 'SAL', 'FIN', 'HR', 'LEG', 'OPS', 'SUP', 'RND', 'QA'
    )

# --- dbo.Employee ---
# Email domain — all company emails
Set-SldgGenerationRule -Plan $plan -TableName 'dbo.Employee' `
    -ColumnName 'Email' -Generator 'Email' `
    -GeneratorParams @{ Domain = 'projectcorp.com' }

# --- dbo.TimeEntry ---
# Hours worked per entry — 0.5 to 8
Set-SldgGenerationRule -Plan $plan -TableName 'dbo.TimeEntry' `
    -ColumnName 'Hours' -ScriptBlock {
        [math]::Round((Get-Random -Minimum 5 -Maximum 80) / 10, 1)
    }
```

### Step 5 — Custom Rules for JSON/XML Tables

#### dbo.Project — `Settings` column (JSON)

The `Settings` column stores project configuration as JSON. AI generates contextual documents automatically based on the column/table name, but you can define exactly what you want:

```powershell
# Option A: Let AI generate (simplest — AI reads "Settings" + "Project" and infers structure)
# Nothing to do — AI handles it. Typical AI output:
# {"notifications":{"email":true,"slack":false},"visibility":"team","tags":["backend","v2"],"sprintLength":14}

# Option B: ScriptBlock for full control over JSON structure
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
            codeReview   = @{
                required  = @($true, $false) | Get-Random
                approvers = Get-Random -Minimum 1 -Maximum 3
            }
        } | ConvertTo-Json -Depth 3 -Compress
    }
```

Example output values:

```json
{"notifications":{"email":true,"slack":false,"channel":"#proj-updates"},"visibility":"team","tags":["backend","api"],"sprintLength":14,"codeReview":{"required":true,"approvers":2}}
{"notifications":{"email":false,"slack":true,"channel":"#proj-alerts"},"visibility":"private","tags":["mobile"],"sprintLength":7,"codeReview":{"required":false,"approvers":1}}
```

#### dbo.Task — `MetadataXml` column (XML)

The `MetadataXml` column stores task metadata as XML:

```powershell
Set-SldgGenerationRule -Plan $plan -TableName 'dbo.Task' `
    -ColumnName 'MetadataXml' -ScriptBlock {
        $labels   = @('bug','feature','improvement','tech-debt','security','ux')
        $selected = $labels | Get-Random -Count (Get-Random -Minimum 1 -Maximum 3)
        $labelXml = ($selected | ForEach-Object { "    <Label>$_</Label>" }) -join "`n"
        $envs     = @('Development','Staging','Production')
        $types    = @('String','Integer','Boolean','DateTime')
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
  <History>
    <Event date="$(Get-Date -Format 'yyyy-MM-dd')" user="system">Task created</Event>
  </History>
</TaskMetadata>
"@
    }
```

Example output:

```xml
<TaskMetadata>
  <Labels>
    <Label>feature</Label>
    <Label>security</Label>
  </Labels>
  <CustomFields>
    <Field name="Environment" type="String">Staging</Field>
    <Field name="StoryPoints" type="Integer">5</Field>
    <Field name="Billable" type="Boolean">true</Field>
  </CustomFields>
  <History>
    <Event date="2026-03-20" user="system">Task created</Event>
  </History>
</TaskMetadata>
```

#### dbo.AuditLog — `Changes` column (JSON)

The `Changes` column stores a diff of field changes:

```powershell
Set-SldgGenerationRule -Plan $plan -TableName 'dbo.AuditLog' `
    -ColumnName 'Action' -ValueList @('INSERT', 'UPDATE', 'DELETE')

Set-SldgGenerationRule -Plan $plan -TableName 'dbo.AuditLog' `
    -ColumnName 'TableName' -ValueList @(
        'Department', 'Employee', 'Project', 'Task', 'TimeEntry'
    )

Set-SldgGenerationRule -Plan $plan -TableName 'dbo.AuditLog' `
    -ColumnName 'Changes' -ScriptBlock {
        $fields = @(
            @{ field = 'Status';   old = 'New';      new = 'InProgress' },
            @{ field = 'Status';   old = 'InProgress'; new = 'Done' },
            @{ field = 'Priority'; old = 'Medium';   new = 'High' },
            @{ field = 'Title';    old = 'Draft';    new = 'Final version' },
            @{ field = 'Salary';   old = '45000';    new = '52000' },
            @{ field = 'IsActive'; old = 'true';     new = 'false' },
            @{ field = 'Email';    old = 'old@x.com'; new = 'new@x.com' }
        )
        $count   = Get-Random -Minimum 1 -Maximum 3
        $changes = @{}
        $fields | Get-Random -Count $count | ForEach-Object {
            $changes[$_.field] = @{ old = $_.old; new = $_.new }
        }
        $changes | ConvertTo-Json -Compress
    }
```

Example output:

```json
{"Status":{"old":"New","new":"InProgress"},"Priority":{"old":"Medium","new":"High"}}
{"Salary":{"old":"45000","new":"52000"}}
```

### Step 6 — Status and Priority Rules

```powershell
Set-SldgGenerationRule -Plan $plan -TableName 'dbo.Project' `
    -ColumnName 'Status' -ValueList @('Planning', 'Active', 'OnHold', 'Completed', 'Cancelled')

Set-SldgGenerationRule -Plan $plan -TableName 'dbo.Task' `
    -ColumnName 'Status' -ValueList @('New', 'InProgress', 'Review', 'Done', 'Blocked')

Set-SldgGenerationRule -Plan $plan -TableName 'dbo.Task' `
    -ColumnName 'Priority' -ValueList @('Low', 'Medium', 'High', 'Critical')
```

### Step 7 — Generate All Data

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

Generation order (respects FK dependencies):
1. `dbo.Department` — no dependencies
2. `dbo.Employee` — depends on Department
3. `dbo.Project` — depends on Department
4. `dbo.Task` — depends on Project and Employee
5. `dbo.TimeEntry` — depends on Task and Employee
6. `dbo.AuditLog` — no FK dependencies (can run at any level)

FK columns are populated automatically — e.g., every `Employee.DepartmentId` references a real `Department.Id` value generated in step 1.

### Step 8 — Validate and Inspect

```powershell
# Validate FK integrity, unique constraints, NOT NULL
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

Inspect sample data:

```powershell
$result = Invoke-SldgDataGeneration -Plan $plan -NoInsert -PassThru

# Simple table — Employee
$employees = ($result.Tables | Where-Object TableName -eq 'dbo.Employee').DataTable
$employees | Select-Object FirstName, LastName, Email, Salary -First 3
```

```
FirstName  LastName    Email                          Salary
---------  --------    -----                          ------
Martin     Procházka   martin.prochazka@projectcorp.com  62000.00
Kateřina   Dvořáková   katerina.dvorakova@projectcorp.com 58500.00
Tomáš      Novotný     tomas.novotny@projectcorp.com     71200.00
```

```powershell
# JSON table — Project
$projects = ($result.Tables | Where-Object TableName -eq 'dbo.Project').DataTable
$projects | Select-Object Name, Status, Settings -First 2
```

```
Name                    Status    Settings
----                    ------    --------
Platform Redesign       Active    {"notifications":{"email":true,"slack":false,"channel":"#proj-updates"},...}
API Migration v2        Planning  {"notifications":{"email":false,"slack":true,"channel":"#proj-alerts"},...}
```

```powershell
# XML table — Task
$tasks = ($result.Tables | Where-Object TableName -eq 'dbo.Task').DataTable
$tasks | Select-Object Title, Priority, Status, MetadataXml -First 1
```

```
Title                 Priority  Status      MetadataXml
-----                 --------  ------      -----------
Fix login redirect    High      InProgress  <TaskMetadata><Labels><Label>bug</Label>...
```

### Step 9 — Export Profile for Team

```powershell
Export-SldgGenerationProfile -Plan $plan -Path '.\projectdb-profile.json' -IncludeSemanticAnalysis
```

The exported JSON preserves all row counts, semantic types, and custom rules. Anyone on the team can re-generate the same data:

```powershell
# On another machine
Connect-SldgDatabase -ServerInstance 'dev-server' -Database 'ProjectDB'
$schema = Get-SldgDatabaseSchema
$plan   = New-SldgGenerationPlan -Schema $schema -RowCount 10
Import-SldgGenerationProfile -Path '.\projectdb-profile.json' -Plan $plan
Invoke-SldgDataGeneration -Plan $plan
```

### Step 10 — Disconnect

```powershell
Disconnect-SldgDatabase
```

---

## JSON and XML Column Configuration

Columns classified as `Json` or `Xml` (typically `nvarchar(max)`, `text`, `xml`) get structured values automatically. The system uses column and table names to infer what kind of document to generate.

### Context-Dependent Structured Data Generation

When a JSON/XML column should produce **different structures depending on another column's value**, use `-AIGenerationHint` and `-CrossColumnDependency` on `Set-SldgGenerationRule`.

**Use case**: A `dbo.UsageReport` table has `ReportType` (e.g., `'UserActivity'`, `'MailboxUsage'`, `'TeamsDeviceUsage'`) and `ReportData` (JSON). Each report type should produce a different JSON schema.

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
        UserActivity → sessions, actions, lastLogin;
        MailboxUsage → storage, itemCount, quotaUsed;
        OneDriveUsage → filesCount, storageUsed, sharedFiles;
        TeamsDeviceUsage → deviceType, usageMinutes, lastActivity;
        SharePointSiteUsage → siteUrl, pageViews, storageUsed.' `
    -CrossColumnDependency 'ReportType'
```

**How it works:**

1. The module reorders columns so `ReportType` is generated **before** `ReportData`.
2. For each row, after generating `ReportType` (e.g., `'MailboxUsage'`), the value is stored in `$rowContext`.
3. When generating `ReportData`, the engine detects `-CrossColumnDependency` and passes `ContextColumn = 'ReportType'`, `ContextValue = 'MailboxUsage'` to the AI prompt.
4. AI uses the **`structured-value-contextual`** prompt template, which instructs it to vary the document structure based on the context value.
5. Cache key includes the context value (`StructuredData|dbo.UsageReport|ReportData|Json|ctx:MailboxUsage`), so each report type gets its own pool of 10 AI-generated JSON documents.

**Result**: `UserActivity` rows get `{"sessions":12,"actions":["login","viewReport"],"lastLogin":"2026-03-18"}` while `MailboxUsage` rows get `{"storage":"4.2 GB","itemCount":1247,"quotaUsed":0.42}`.

You can also provide `-ValueExamples` to guide AI output format:

```powershell
Set-SldgGenerationRule -Plan $plan -TableName 'dbo.UsageReport' `
    -ColumnName 'ReportData' `
    -Generator 'Json' `
    -AIGenerationHint 'M365 usage report data, structure varies by report type' `
    -CrossColumnDependency 'ReportType' `
    -ValueExamples @(
        '{"sessions":5,"actions":["login","viewDashboard"],"lastLogin":"2026-03-15"}',
        '{"storage":"2.1 GB","itemCount":843,"quotaUsed":0.21}'
    )
```

**Multiple context-dependent JSON columns per table** are fully supported — each column can have its own `-CrossColumnDependency` (even to the same driving column), and each gets its own AI cache.

### How JSON Values Are Generated

The generation engine follows this resolution chain:

1. **Custom rule** — if you set a `ValueList`, `StaticValue`, or `ScriptBlock`, that wins
2. **AI structured-value** — if AI is enabled, it generates 10 realistic JSON documents based on column/table context, caches them, and picks randomly
3. **Static heuristic fallback** — pattern-matches column name to a template category

Static fallback categories:

| Column Name Pattern | Generated JSON |
|---|---|
| `setting`, `config`, `preference`, `option` | `{"theme":"dark","language":"cs","notifications":true,"itemsPerPage":25}` |
| `metadata`, `property`, `attribute` | `{"version":"2.1","tags":["important"],"source":"import","author":"system"}` |
| `address`, `location`, `geo` | `{"street":"Hlavní 15","city":"Praha","zip":"110 00","lat":50.08,"lon":14.43}` |
| `payload`, `data`, `content`, `body` | `{"orderId":"ORD-4521","items":3,"amount":1250.00,"status":"processed"}` |
| _(anything else)_ | Generic key-value pairs |

### Example: Configuring JSON for a Settings Column

```powershell
# Option A: Let AI generate contextual JSON (recommended)
# Just enable AI — the structured-value prompt infers from column+table name
Set-SldgAIProvider -Provider Ollama -Model 'llama3' -EnableAIGeneration

# Option B: Override with a custom prompt for this purpose
$customPrompt = @'
Generate {{Format}} documents for column "{{ColumnName}}" in table "{{TableName}}".
Each document should be a user preference object with keys:
theme (dark/light/auto), language (cs/en/de), notifications (bool), pageSize (int 10-100).
Return a JSON array of 10 string values. No markdown.
'@
Set-SldgPromptTemplate -Purpose 'structured-value' -Content $customPrompt

# Option C: Static value — same JSON for every row
Set-SldgGenerationRule -Plan $plan -TableName 'dbo.Customer' `
    -ColumnName 'Preferences' `
    -StaticValue '{"theme":"light","language":"cs","notifications":true}'

# Option D: Value list — pick from predefined JSON documents
Set-SldgGenerationRule -Plan $plan -TableName 'dbo.Customer' `
    -ColumnName 'Preferences' -ValueList @(
        '{"theme":"dark","language":"cs","notifications":true,"pageSize":25}',
        '{"theme":"light","language":"en","notifications":false,"pageSize":50}',
        '{"theme":"auto","language":"de","notifications":true,"pageSize":10}'
    )

# Option E: ScriptBlock — programmatic JSON with variability
Set-SldgGenerationRule -Plan $plan -TableName 'dbo.Product' `
    -ColumnName 'Metadata' -ScriptBlock {
        @{
            version     = "1.$(Get-Random -Max 9)"
            weight_kg   = [math]::Round((Get-Random -Minimum 1 -Maximum 500) / 10, 2)
            tags        = @('electronics','sale') | Get-Random -Count (Get-Random -Min 1 -Max 2)
            warehouse   = "WH-$(Get-Random -Min 1 -Max 5)"
        } | ConvertTo-Json -Compress
    }
```

### Example: XML Columns

XML columns work the same way — the engine detects `xml` data type or `Xml` semantic type:

```powershell
# AI generates XML automatically for xml-typed columns

# Or use a ScriptBlock for full control
Set-SldgGenerationRule -Plan $plan -TableName 'dbo.Document' `
    -ColumnName 'XmlContent' -ScriptBlock {
        $id = Get-Random -Minimum 1000 -Maximum 9999
        @"
<Document>
  <Header>
    <DocId>DOC-$id</DocId>
    <Created>$(Get-Date -Format 'yyyy-MM-dd')</Created>
    <Author>System</Author>
  </Header>
  <Body>
    <Section title="Summary">Generated test content</Section>
  </Body>
</Document>
"@
    }
```

### Per-Purpose Model Override for Structured Values

For better JSON/XML quality, use a code-focused model just for structured-value generation:

```powershell
# Global: llama3 for everything
Set-SldgAIProvider -Provider Ollama -Model 'llama3' -EnableAIGeneration

# Override: codellama for JSON/XML generation (better at structured output)
Set-SldgAIProvider -Provider Ollama -Model 'codellama' -Purpose 'structured-value'
```

---

## Generation Profiles (JSON Export / Import)

Profiles let you save the entire generation configuration as JSON and replay it later — on the same or different database.

### Exported Profile Structure

```powershell
Export-SldgGenerationProfile -Plan $plan -Path '.\profile.json' -IncludeSemanticAnalysis
```

Produces a JSON file like:

```json
{
  "database": "ShopDB",
  "mode": "Scenario",
  "exportedAt": "2026-03-20T10:30:00",
  "tables": {
    "dbo.Category": {
      "rowCount": 5,
      "columns": {
        "Name": {
          "semanticType": "ShortString",
          "isPII": false
        },
        "IsActive": {
          "semanticType": "Boolean",
          "isPII": false
        }
      }
    },
    "dbo.Customer": {
      "rowCount": 100,
      "columns": {
        "FirstName": {
          "semanticType": "FirstName",
          "isPII": true
        },
        "LastName": {
          "semanticType": "LastName",
          "isPII": true
        },
        "Email": {
          "semanticType": "Email",
          "isPII": true,
          "generator": "Email",
          "generatorParams": { "domain": "example.cz" }
        },
        "Preferences": {
          "semanticType": "Json",
          "isPII": false
        }
      }
    },
    "dbo.Order": {
      "rowCount": 300,
      "columns": {
        "Status": {
          "valueList": ["Pending", "Processing", "Shipped", "Delivered", "Cancelled"]
        },
        "Currency": {
          "staticValue": "CZK"
        },
        "TotalAmount": {
          "semanticType": "Money",
          "isPII": false
        }
      }
    },
    "dbo.OrderItem": {
      "rowCount": 800,
      "columns": {
        "Quantity": {
          "semanticType": "Integer",
          "isPII": false
        },
        "UnitPrice": {
          "semanticType": "Money",
          "isPII": false
        },
        "ProductId": {
          "foreignKey": {
            "referencedTable": "dbo.Product",
            "referencedColumn": "Id"
          }
        }
      }
    }
  }
}
```

### Importing a Profile

```powershell
# Create a fresh plan from current schema
$schema  = Get-SldgDatabaseSchema
$plan    = New-SldgGenerationPlan -Schema $schema -RowCount 10

# Apply saved profile — overrides row counts and rules
Import-SldgGenerationProfile -Path '.\profile.json' -Plan $plan

# Generate with the imported configuration
Invoke-SldgDataGeneration -Plan $plan
```

The import applies:
- **Row counts** — each table gets the count from the profile
- **ValueList** rules — saved value lists become `Set-SldgGenerationRule` calls
- **StaticValue** rules — constant values are applied
- **Generator** overrides — specific generator + params are restored
- **Security**: `scriptBlock` keys are **rejected** during import to prevent code injection

### Editing a Profile by Hand

You can edit the JSON directly. Common tweaks:

```json
{
  "tables": {
    "dbo.Customer": {
      "rowCount": 5000,
      "columns": {
        "Status": { "valueList": ["VIP", "Standard", "Trial"] },
        "Country": { "staticValue": "CZ" },
        "Email": {
          "generator": "Email",
          "generatorParams": { "domain": "firma.cz" }
        }
      }
    }
  }
}
```

Share profiles with your team in version control — everyone generates the same test data.

---

## Language and Locale Configuration

The locale system controls what language and cultural formats are used for generated values — Czech names, German addresses, Japanese phone numbers, etc.

### Built-in Locales

Two locales are available out of the box (no AI needed):

| Locale | Content |
|---|---|
| `en-US` | English names, US addresses, US phone format `(201) 555-1234`, USD currency |
| `cs-CZ` | Czech names (Jan, Petr, Jana, Tereza), Czech streets (Hlavní, Masarykova), PSČ format, +420 phones, s.r.o./a.s. company suffixes, rodné číslo format |

```powershell
# Use Czech locale for all generation
Set-SldgAIProvider -Provider Ollama -Model 'llama3' -EnableAIGeneration -Locale 'cs-CZ'

# Or set directly
Set-PSFConfig -FullName 'SqlLabDataGenerator.Generation.Locale' -Value 'cs-CZ'
```

### AI-Generated Locales

Generate a complete locale for **any** culture code — the AI creates names, addresses, phone formats, and more in the target language:

```powershell
# Enable AI locale generation
Set-SldgAIProvider -Provider Ollama -Model 'llama3' -EnableAILocale

# Generate German locale with 50 values per category
Register-SldgLocale -Name 'de-DE' -UseAI -PoolSize 50

# Generate Japanese locale with specific instructions
Register-SldgLocale -Name 'ja-JP' -UseAI -PoolSize 30 `
    -CustomInstructions 'Use Hiragana for names, include Tokyo/Osaka/Kyoto addresses'

# Generate French locale
Register-SldgLocale -Name 'fr-FR' -UseAI

# Now use it
$plan = New-SldgGenerationPlan -Schema $analyzed -RowCount 100
Set-PSFConfig -FullName 'SqlLabDataGenerator.Generation.Locale' -Value 'de-DE'
Invoke-SldgDataGeneration -Plan $plan
```

The AI generates all required categories:

| Category | Examples (cs-CZ) |
|---|---|
| MaleNames | Jan, Petr, Tomáš, Jiří, František |
| FemaleNames | Jana, Marie, Tereza, Lucie, Kateřina |
| LastNames | Novák, Svoboda, Dvořák, Černý, Procházka |
| StreetNames | Hlavní, Masarykova, Husova, Nádražní |
| Locations | Praha, Brno, Ostrava, Plzeň, Olomouc |
| EmailDomains | seznam.cz, email.cz, centrum.cz |
| PhoneFormat | +420 {Area} {Exchange} {Subscriber} |
| CompanySuffixes | s.r.o., a.s., v.o.s. |
| JobTitles | Ředitel, Manažer, Analytik, Účetní |
| NationalIdFormat | Rodné číslo `{YY}{MM}{DD}/{SSSS}` |

### Mixing Languages

Combine categories from different locales — useful for international companies or testing multilingual data:

```powershell
# Czech names + German addresses + English company names
Register-SldgLocale -Name 'mixed-international' -MixFrom @{
    PersonNames = 'cs-CZ'     # Jan Novák, Tereza Dvořáková
    Addresses   = 'de-DE'     # Hauptstraße 15, 80331 München
    Companies   = 'en-US'     # Acme Corporation, Global Dynamics
    Identifiers = 'cs-CZ'     # Czech IČO, rodné číslo
}

# Use the mixed locale
Set-PSFConfig -FullName 'SqlLabDataGenerator.Generation.Locale' -Value 'mixed-international'
$result = Invoke-SldgDataGeneration -Plan $plan
```

If a source locale is not registered yet, the system generates it via AI automatically (when `EnableAILocale` is on).

### Locale Fallback Chain

When generating a value, the module resolves locale data in this order:

1. **Registered static pack** — `Register-SldgLocale -Data` or built-in cs-CZ/en-US
2. **AI cache** — previously generated locale data (in-memory)
3. **AI generation** — real-time AI generation (if `EnableAILocale` is on)
4. **en-US fallback** — always available as a last resort

### Automatic Locale Detection

AI column analysis recognizes column names in **any language** without explicit locale configuration:

```powershell
# Czech columns
# Jmeno        → FirstName
# Prijmeni     → LastName
# Telefon      → Phone
# PSC          → ZipCode
# DatumNarozeni→ BirthDate
# Oddeleni     → Department

# German columns
# Vorname      → FirstName
# Nachname     → LastName
# Strasse      → Street
# PLZ          → ZipCode
# Geburtsdatum → BirthDate
# Abteilung    → Department

$analyzed = Get-SldgColumnAnalysis -Schema $schema -UseAI -Locale 'cs-CZ'
# AI recognizes Czech column names and classifies them correctly
```

---

## Walkthrough: Multi-Language Healthcare Database

A more complex example with a Czech healthcare database, multiple locales, custom JSON columns, and profile export.

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
    RodneCislo VARCHAR(11),       -- National ID (birth number)
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

# Ollama for general tasks, GPT-4o for batch generation quality
Set-SldgAIProvider -Provider Ollama -Model 'llama3' `
    -EnableAIGeneration -EnableAILocale -Locale 'cs-CZ'
Set-SldgAIProvider -Provider OpenAI -Model 'gpt-4o' `
    -ApiKey $env:OPENAI_API_KEY -Purpose 'batch-generation'
```

### Step 2 — Schema Discovery and AI Analysis

```powershell
$schema   = Get-SldgDatabaseSchema
$analyzed = Get-SldgColumnAnalysis -Schema $schema -UseAI -Locale 'cs-CZ'
```

AI classifies Czech column names:
- `Jmeno` → FirstName (PII), `Prijmeni` → LastName (PII)
- `RodneCislo` → NationalId (PII), `DatumNarozeni` → BirthDate (PII)
- `Telefon` → Phone (PII), `Email` → Email (PII), `Adresa` → Address (PII)
- `Stav` → Status, `Diagnoza` → MediumString, `Cena` → Money
- `Specialization`, `Preference` → Json, `Poznamky` → Xml

### Step 3 — Plan with Healthcare Scenario

```powershell
$plan = New-SldgGenerationPlan -Schema $analyzed -Mode Scenario `
    -ScenarioName 'Healthcare' -RowCount 200 -UseAI -IndustryHint 'Healthcare CZ'
```

AI + scenario produce:

| Table | Role | Rows |
|---|---|---|
| dbo.Oddeleni | Lookup | 10 |
| dbo.Lekar | Reference | 20 |
| dbo.Pacient | Master | 200 |
| dbo.Navsteva | Transaction | 1000 |

### Step 4 — Custom Rules for Czech Context

```powershell
# Department codes
Set-SldgGenerationRule -Plan $plan -TableName 'dbo.Oddeleni' `
    -ColumnName 'Nazev' -ValueList @(
        'Kardiologie', 'Neurologie', 'Ortopedie', 'Chirurgie',
        'Interna', 'Pediatrie', 'Onkologie', 'Urologie',
        'Gynekologie', 'Anesteziologie'
    )

Set-SldgGenerationRule -Plan $plan -TableName 'dbo.Oddeleni' `
    -ColumnName 'Kod' -ValueList @(
        'KAR', 'NEU', 'ORT', 'CHI', 'INT', 'PED', 'ONK', 'URO', 'GYN', 'ANE'
    )

# Visit status in Czech
Set-SldgGenerationRule -Plan $plan -TableName 'dbo.Navsteva' `
    -ColumnName 'Stav' -ValueList @(
        'Planovana', 'Probihajici', 'Dokoncena', 'Zrusena', 'Neodstavena'
    )

# Doctor titles
Set-SldgGenerationRule -Plan $plan -TableName 'dbo.Lekar' `
    -ColumnName 'Titul' -ValueList @('MUDr.', 'doc. MUDr.', 'prof. MUDr.', 'MDDr.')

# Doctor specialization — JSON with certifications
Set-SldgGenerationRule -Plan $plan -TableName 'dbo.Lekar' `
    -ColumnName 'Specialization' -ScriptBlock {
        $certs = @('Atestace I.','Atestace II.','PhD.','MBA') | Get-Random -Count (Get-Random -Min 1 -Max 3)
        $langs = @('čeština','angličtina','němčina','ruština') | Get-Random -Count (Get-Random -Min 1 -Max 3)
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
            pojistovna  = @('VZP','ČPZP','OZP','ZPMV','VoZP') | Get-Random
        } | ConvertTo-Json -Compress
    }

# Visit notes — XML with diagnosis detail
Set-SldgGenerationRule -Plan $plan -TableName 'dbo.Navsteva' `
    -ColumnName 'Poznamky' -ScriptBlock {
        $codes = @('J06.9','I10','E11','M54.5','K21.0','J45','F32') | Get-Random -Count 2
        @"
<Zaznam>
  <Anamneza>Pacient se dostavil k plánované kontrole.</Anamneza>
  <Vysetreni>
    <MKN10>$($codes[0])</MKN10>
    <MKN10>$($codes[1])</MKN10>
  </Vysetreni>
  <Zaver>Doporučena kontrola za 3 měsíce.</Zaver>
</Zaznam>
"@
    }
```

### Step 5 — Generate and Export

```powershell
# Generate data
$result = Invoke-SldgDataGeneration -Plan $plan
$result | Format-Table TableName, RowCount, Success

# Save profile for the team
Export-SldgGenerationProfile -Plan $plan -Path '.\nemocnice-profile.json' `
    -IncludeSemanticAnalysis
```

```
TableName       RowCount Success
---------       -------- -------
dbo.Oddeleni          10    True
dbo.Lekar             20    True
dbo.Pacient          200    True
dbo.Navsteva        1000    True
```

### Step 6 — Colleague Imports the Profile

```powershell
# On a different machine / database
Connect-SldgDatabase -ServerInstance 'dev-server' -Database 'NemocniceDB_Test'
$schema = Get-SldgDatabaseSchema
$plan   = New-SldgGenerationPlan -Schema $schema -RowCount 10
Import-SldgGenerationProfile -Path '.\nemocnice-profile.json' -Plan $plan
Invoke-SldgDataGeneration -Plan $plan
```

---

## Scenario Mode — Industry Templates

Built-in scenario templates define table roles and row multipliers for common industries:

```powershell
# Auto-detect scenario from table names
$plan = New-SldgGenerationPlan -Schema $analyzed -Mode Scenario `
    -ScenarioName Auto -RowCount 100
# If tables are Customer, Product, Order, OrderDetail → auto-detects eCommerce
```

| Scenario | Tables Recognized | Status/Type Value Rules |
|---|---|---|
| **eCommerce** | Customer, Product, Order, OrderDetail, Category | OrderStatus: Pending/Shipped/Delivered; PaymentStatus: Pending/Completed/Failed |
| **Healthcare** | Patient, Visit, Diagnosis, Doctor, Department, Prescription | VisitStatus: Scheduled/InProgress/Completed; Priority: Low/Medium/High/Critical |
| **HR** | Employee, Department, Salary, Attendance, Leave, Training | LeaveStatus: Pending/Approved/Rejected; EmploymentType: FullTime/PartTime/Contract |
| **Finance** | Account, Transaction, Ledger, Branch, Currency | TransactionType: Credit/Debit/Transfer; AccountStatus: Active/Closed/Frozen |
| **Education** | Student, Course, Enrollment, Grade, Semester, Teacher | EnrollmentStatus: Active/Completed/Withdrawn; GradeType: A/B/C/D/F |

Auto-detection requires ≥3 table name matches against the scenario patterns.

---

## Advanced Features

These features extend the core generation pipeline for enterprise-scale workloads, PII anonymization, and integration with external systems.

### Parallel Generation and Streaming

For large databases, combine parallel execution with streaming:

```powershell
# Parallel: independent tables generated concurrently (PS 7+ only)
$result = Invoke-SldgDataGeneration -Plan $plan -Parallel -ThrottleLimit 4

# Streaming: large tables generated in chunks to keep memory bounded
Set-PSFConfig -FullName 'SqlLabDataGenerator.Generation.StreamingThreshold' -Value 50000
Set-PSFConfig -FullName 'SqlLabDataGenerator.Generation.StreamingChunkSize'  -Value 5000

# Combined: parallel + streaming for tables > 50k rows
$plan = New-SldgGenerationPlan -Schema $analyzed -RowCount 10000
$result = Invoke-SldgDataGeneration -Plan $plan -Parallel
```

Tables are grouped by FK dependency level — tables at the same level run in parallel, then move to the next level. Streaming kicks in automatically for tables exceeding the threshold.

### Data Masking (PII Anonymization)

Use the same engine to anonymize PII in existing production data:

```powershell
Connect-SldgDatabase -ServerInstance 'localhost' -Database 'ProdCopy'
$schema   = Get-SldgDatabaseSchema
$analyzed = Get-SldgColumnAnalysis -Schema $schema -UseAI
# AI detects PII columns: FirstName, LastName, Email, Phone, SSN, BirthDate…

$plan = New-SldgGenerationPlan -Schema $analyzed -Mode Masking
# Masking mode: reads existing data → replaces PII columns → writes back
# Non-PII columns are preserved as-is

$result = Invoke-SldgDataGeneration -Plan $plan
# Automatically uses transactions (rollback on failure)
```

### Export to External Systems (Entra ID / Graph API)

Transform generated data into Graph API payloads:

```powershell
# Generate user data
$result = Invoke-SldgDataGeneration -Plan $plan -NoInsert -PassThru

# Transform to Entra ID user format
$customerTable = ($result.Tables | Where-Object TableName -eq 'dbo.Customer').DataTable

Export-SldgTransformedData -DataTable $customerTable `
    -TransformerName 'EntraIdUser' `
    -Path '.\entra-users.json'
```

Output (`entra-users.json`):

```json
{
  "value": [
    {
      "displayName": "Jan Novák",
      "givenName": "Jan",
      "surname": "Novák",
      "mail": "jan.novak@firma.cz",
      "mobilePhone": "+420 601 234 567",
      "accountEnabled": true,
      "userPrincipalName": "jan.novak@firma.onmicrosoft.com"
    },
    {
      "displayName": "Tereza Dvořáková",
      "givenName": "Tereza",
      "surname": "Dvořáková",
      "mail": "tereza.dvorakova@firma.cz",
      "mobilePhone": "+420 702 345 678",
      "accountEnabled": true,
      "userPrincipalName": "tereza.dvorakova@firma.onmicrosoft.com"
    }
  ]
}
```

---

## Prompt Customization

All AI prompts are externalized as `.prompt` template files with YAML front matter. You can inspect, modify, or override any prompt without editing module internals.

### Prompt Template Structure

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
- **`{{Variable}}` placeholders** — substituted at runtime with actual values
- **Variant system** — `purpose.variant.prompt` naming (e.g., `column-analysis.default.prompt`, `column-analysis.ollama.prompt`)

### Managing Prompts

```powershell
# List all available prompts
Get-SldgPromptTemplate

# View a specific prompt with content
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

# Remove all custom overrides
Get-SldgPromptTemplate | Where-Object IsCustom | Remove-SldgPromptTemplate
```

### Resolution Order

When an AI task runs, the prompt is resolved in this order:
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
| `structured-value` | Structured JSON/XML value generation |
| `structured-value-contextual` | Context-dependent JSON/XML generation (uses `-CrossColumnDependency`) |
| `locale-data` | `Register-SldgLocale -UseAI` |
| `locale-category` | Locale category generation |

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
| Token usage | More tokens for instructions | Compact responses |

### Step 1: Generate Training Data

Run SqlLabDataGenerator against real (anonymized) databases to collect prompt/response pairs:

```powershell
# Connect to your databases and collect AI interactions
# The module logs all AI prompts and responses when verbose

$VerbosePreference = 'Continue'
Connect-SldgDatabase -ServerInstance 'localhost' -Database 'AdventureWorks'
$schema = Get-SldgDatabaseSchema
$analyzed = Get-SldgColumnAnalysis -Schema $schema -UseAI -Locale 'cs-CZ'
$plan = New-SldgGenerationPlan -Schema $analyzed -UseAI -IndustryHint 'Retail'
Invoke-SldgDataGeneration -Plan $plan -NoInsert
```

Collect the prompt/response pairs from verbose output for these task types:

1. **Column classification** — schema in → semantic types out (JSON array)
2. **Plan advice** — schema in → row counts, rules, table types out (JSON)
3. **Batch generation** — column defs + locale in → data rows out (JSON array)
4. **Locale generation** — culture code in → locale data pack out (JSON)

### Step 2: Create Training Dataset

Format as JSONL for Ollama fine-tuning:

```jsonl
{"messages": [{"role": "system", "content": "You are a database column classifier..."}, {"role": "user", "content": "Analyze this schema: ..."}, {"role": "assistant", "content": "[{\"TableName\": \"dbo.Customer\", ...}]"}]}
{"messages": [{"role": "system", "content": "You are a test data generator..."}, {"role": "user", "content": "Generate 50 rows for table Customer..."}, {"role": "assistant", "content": "[{\"FirstName\": \"Jan\", ...}]"}]}
```

Recommended minimum:
- 50+ column classification examples (diverse schemas, multiple languages)
- 30+ plan advice examples (different database sizes and industries)
- 100+ batch generation examples (various table structures, locales)
- 20+ locale generation examples (different cultures)

### Step 3: Fine-Tune with Ollama

```bash
# Create a Modelfile
cat > Modelfile << 'EOF'
FROM llama3

# System prompt baked into the model
SYSTEM """You are SqlLabDataGenerator AI assistant. You analyze database schemas,
classify columns semantically, generate realistic test data, and create locale data packs.
Always respond with valid JSON. No markdown, no explanations — just JSON."""

# Optimal parameters for structured output
PARAMETER temperature 0.2
PARAMETER top_p 0.9
PARAMETER num_predict 4096
PARAMETER stop ["```"]
EOF

# Create the base model
ollama create sldg-base -f Modelfile

# Fine-tune with your training data (requires Ollama 0.5+)
ollama train sldg-v1 \
    --base sldg-base \
    --dataset training-data.jsonl \
    --epochs 3 \
    --learning-rate 1e-5
```

> **Note**: Ollama fine-tuning API may differ by version. Check [Ollama docs](https://ollama.com/docs) for the latest syntax. Alternative: fine-tune with [Unsloth](https://github.com/unslothai/unsloth) or [LLaMA-Factory](https://github.com/hiyouga/LLaMA-Factory) and import the GGUF into Ollama.

### Step 4: Alternative — Fine-Tune with Unsloth + Import to Ollama

For more control over the training process:

```bash
# 1. Install Unsloth
pip install unsloth

# 2. Fine-tune (Python)
python fine_tune.py \
    --base_model "unsloth/llama-3-8b-Instruct" \
    --dataset training-data.jsonl \
    --output_dir ./sldg-model \
    --epochs 3 \
    --lora_r 16 \
    --lora_alpha 32

# 3. Export to GGUF
python -m unsloth.save \
    --model ./sldg-model \
    --output ./sldg-v1.gguf \
    --quantization q4_k_m

# 4. Create Ollama model from GGUF
cat > Modelfile << EOF
FROM ./sldg-v1.gguf

SYSTEM """You are SqlLabDataGenerator AI assistant. Respond with valid JSON only."""

PARAMETER temperature 0.2
PARAMETER num_predict 4096
EOF

ollama create sldg-v1 -f Modelfile
```

### Step 5: Use the Custom Model

```powershell
Set-SldgAIProvider -Provider Ollama -Model 'sldg-v1' -EnableAIGeneration -EnableAILocale -Locale 'cs-CZ'
Test-SldgAIProvider
```

### Step 6: Iterative Improvement

1. Run the module against test databases, collect failures (parse errors, incorrect classifications)
2. Fix the training data — add corrected examples for failure cases
3. Re-train with the expanded dataset
4. Repeat until the model consistently produces valid JSON responses

### Training Tips

| Tip | Details |
|---|---|
| **JSON consistency** | Train the model to always output raw JSON without markdown code blocks |
| **Column name variety** | Include Czech, German, English, mixed-language column names |
| **Schema diversity** | Mix small (5 tables) and large (50+ tables) schemas |
| **Locale coverage** | Include all your target locales in training data |
| **Edge cases** | Include tables with circular FKs, computed columns, weird data types |
| **Temperature** | Use 0.2 for the fine-tuned model — lower than general-purpose 0.3 |
| **Quantization** | `q4_k_m` is a good balance of speed and quality for 8B models |

---

## Performance Tuning

### Caching

The module caches AI responses at multiple levels:

| Cache | Key | Cleared By |
|---|---|---|
| `AIValueCache` | Table + column signatures + locale (+ context value for cross-column dependencies) | `Set-SldgAIProvider`, module reimport |
| `AILocaleCache` | Culture code | `Set-SldgAIProvider`, module reimport |
| `AILocaleCategoryCache` | Language + category | `Set-SldgAIProvider`, module reimport |

Caches are automatically cleared when you change the AI provider via `Set-SldgAIProvider`.

### Batch Size

AI generates data in batches (default: 50 rows per request). For tables with many columns, reduce the batch size via the internal `New-SldgAIGeneratedBatch -BatchSize` parameter.

### Token Limits

If AI responses are truncated, increase `MaxTokens`:

```powershell
Set-SldgAIProvider -Provider Ollama -Model 'llama3' -MaxTokens 8192
```

### Temperature

| Value | Effect | Use Case |
|---|---|---|
| 0.0 | Deterministic — same input → same output | Reproducible test data |
| 0.2 | Mostly consistent, slight variation | Fine-tuned models |
| 0.3 | Default — good variety with consistency | General use |
| 0.7+ | Creative — high variety | Exploration, stress testing |

---

## Troubleshooting

### Test-SldgAIProvider returns NoResponse

```powershell
# Check Ollama is running
ollama list

# Check endpoint is reachable
Invoke-RestMethod -Uri 'http://localhost:11434/api/tags'

# Check model exists
ollama show llama3
```

### AI returns invalid JSON

- Increase `MaxTokens` — response may be truncated
- Lower `Temperature` — more deterministic output
- Use a larger model (llama3 8B → 70B, or gpt-4o)
- Train a custom model (see above)

### Slow AI responses

- Use a quantized model (q4_k_m instead of f16)
- Enable GPU acceleration in Ollama
- Use cached results — second run is instant
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
