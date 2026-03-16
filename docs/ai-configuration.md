# AI Configuration & Custom Model Training

SqlLabDataGenerator uses AI at three levels:

1. **Semantic Analysis** — classifying what each column means (FirstName, Email, Money, …)
2. **Data Generation** — generating entire rows of realistic, consistent values
3. **Locale Generation** — creating culture-specific data pools for any language

All three levels are optional. Without AI the module falls back to pattern matching and static generators.

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
| `Set-SldgAIProvider` | Configure provider, model, endpoint, and enable features |
| `Get-SldgAIProvider` | Display current configuration |
| `Test-SldgAIProvider` | Test connectivity and measure response time |

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
```

### PSFConfig Keys (Advanced)

All settings are stored via PSFramework and can also be set directly:

```powershell
Set-PSFConfig -FullName 'SqlLabDataGenerator.AI.Provider' -Value 'Ollama'
Set-PSFConfig -FullName 'SqlLabDataGenerator.AI.Model' -Value 'llama3'
Set-PSFConfig -FullName 'SqlLabDataGenerator.AI.Endpoint' -Value 'http://localhost:11434'
Set-PSFConfig -FullName 'SqlLabDataGenerator.AI.Ollama.Temperature' -Value 0.3
Set-PSFConfig -FullName 'SqlLabDataGenerator.Generation.AIGeneration' -Value $true
Set-PSFConfig -FullName 'SqlLabDataGenerator.Generation.AILocale' -Value $true
Set-PSFConfig -FullName 'SqlLabDataGenerator.Generation.Locale' -Value 'cs-CZ'
```

To persist across sessions:

```powershell
Set-PSFConfig -FullName 'SqlLabDataGenerator.AI.Provider' -Value 'Ollama' -PassThru | Register-PSFConfig
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
| `AIValueCache` | Table + column signatures + locale | `Set-SldgAIProvider`, module reimport |
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
