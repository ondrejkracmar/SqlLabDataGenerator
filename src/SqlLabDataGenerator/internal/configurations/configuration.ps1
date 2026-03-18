<#
SqlLabDataGenerator Configuration
Handles module settings, runtime state initialization, and provider registration.
#>

# Register custom PSF validation scriptblocks
Register-PSFConfigValidation -Name 'SqlLabDataGenerator.GenerationMode' -ScriptBlock {
	param ($Value)
	$validModes = @('Synthetic', 'Masking', 'Scenario')
	if ($Value -in $validModes) { return [PSCustomObject]@{ Success = $true; Value = $Value; Message = '' } }
	[PSCustomObject]@{ Success = $false; Value = $Value; Message = "Invalid generation mode '$Value'. Valid values: $($validModes -join ', ')" }
}

Register-PSFConfigValidation -Name 'SqlLabDataGenerator.AIProvider' -ScriptBlock {
	param ($Value)
	$validProviders = @('None', 'OpenAI', 'AzureOpenAI', 'Ollama')
	if ($Value -in $validProviders) { return [PSCustomObject]@{ Success = $true; Value = $Value; Message = '' } }
	[PSCustomObject]@{ Success = $false; Value = $Value; Message = "Invalid AI provider '$Value'. Valid values: $($validProviders -join ', ')" }
}

# Module runtime state
$script:SldgState = @{
	Providers              = @{}
	ActiveConnection       = $null
	ActiveProvider         = $null
	GenerationPlans        = @{}
	GeneratedData          = @{}
	Locales                = @{}
	Transformers           = @{}
	AILocaleCache          = @{}
	AILocaleCategoryCache  = @{}
	AIValueCache           = @{}
	AIRequestTimestamps    = [System.Collections.Generic.List[datetime]]::new()
	CacheTimestamps        = @{}
}

# Import behavior
Set-PSFConfig -Module 'SqlLabDataGenerator' -Name 'Import.DoDotSource' -Value $false -Initialize -Validation 'bool' -Description "Whether the module files should be dotsourced on import. By default, the files of this module are read as string value and invoked, which is faster but worse on debugging."
Set-PSFConfig -Module 'SqlLabDataGenerator' -Name 'Import.IndividualFiles' -Value $false -Initialize -Validation 'bool' -Description "Whether the module files should be imported individually. During the module build, all module code is compiled into few files, which are imported instead by default. Loading the compiled versions is faster, using the individual files is easier for debugging and testing out adjustments."

# AI Provider settings
Set-PSFConfig -Module 'SqlLabDataGenerator' -Name 'AI.Provider' -Value 'None' -Initialize -Validation 'SqlLabDataGenerator.AIProvider' -Description "AI provider to use for semantic column analysis: None, OpenAI, AzureOpenAI, Ollama"
Set-PSFConfig -Module 'SqlLabDataGenerator' -Name 'AI.ApiKey' -Value $null -Initialize -Description "API key for the AI provider (not required for Ollama). Stored as SecureString when possible."
Set-PSFConfig -Module 'SqlLabDataGenerator' -Name 'AI.Endpoint' -Value '' -Initialize -Validation 'string' -Description "Endpoint URL for AI provider (required for AzureOpenAI, optional for Ollama - defaults to http://localhost:11434)"
Set-PSFConfig -Module 'SqlLabDataGenerator' -Name 'AI.Model' -Value 'gpt-4' -Initialize -Validation 'string' -Description "AI model to use for semantic analysis (e.g., gpt-4, llama3, mistral, codellama)"
Set-PSFConfig -Module 'SqlLabDataGenerator' -Name 'AI.MaxTokens' -Value 4096 -Initialize -Validation 'integer' -Description "Maximum tokens for AI responses"

# AI request resilience
Set-PSFConfig -Module 'SqlLabDataGenerator' -Name 'AI.RetryCount' -Value 3 -Initialize -Validation 'integerpositive' -Description "Number of retry attempts for failed AI requests before giving up."
Set-PSFConfig -Module 'SqlLabDataGenerator' -Name 'AI.RetryDelaySeconds' -Value 2 -Initialize -Validation 'integerpositive' -Description "Base delay in seconds between AI request retries (doubles on each retry — exponential backoff)."
Set-PSFConfig -Module 'SqlLabDataGenerator' -Name 'AI.TimeoutSeconds' -Value 120 -Initialize -Validation 'integerpositive' -Description "Timeout in seconds for individual AI HTTP requests."
Set-PSFConfig -Module 'SqlLabDataGenerator' -Name 'AI.RateLimitPerMinute' -Value 30 -Initialize -Validation 'integerpositive' -Description "Maximum number of AI requests per minute (0 = unlimited)."

# Ollama-specific settings
Set-PSFConfig -Module 'SqlLabDataGenerator' -Name 'AI.Ollama.Temperature' -Value 0.3 -Initialize -Validation 'double' -Description "Temperature for Ollama model responses (0.0 = deterministic, 1.0 = creative)"
Set-PSFConfig -Module 'SqlLabDataGenerator' -Name 'AI.Ollama.SkipCertificateCheck' -Value $false -Initialize -Validation 'bool' -Description "Skip TLS certificate validation for Ollama endpoint (dev/self-signed certs)"

# Generation defaults
Set-PSFConfig -Module 'SqlLabDataGenerator' -Name 'Generation.DefaultRowCount' -Value 100 -Initialize -Validation 'integerpositive' -Description "Default number of rows to generate per table"
Set-PSFConfig -Module 'SqlLabDataGenerator' -Name 'Generation.BatchSize' -Value 1000 -Initialize -Validation 'integerpositive' -Description "Batch size for database inserts"
Set-PSFConfig -Module 'SqlLabDataGenerator' -Name 'Generation.Seed' -Value 0 -Initialize -Validation 'integer' -Description "Random seed for reproducible generation (0 = random)"
Set-PSFConfig -Module 'SqlLabDataGenerator' -Name 'Generation.Locale' -Value 'en-US' -Initialize -Validation 'string' -Description "Locale for generated data (e.g., en-US, cs-CZ, de-DE). When AILocale is enabled and AI is configured, any locale code works — AI generates the data on-the-fly."
Set-PSFConfig -Module 'SqlLabDataGenerator' -Name 'Generation.AILocale' -Value $false -Initialize -Validation 'bool' -Description "When enabled and AI is configured, automatically generate locale data for any culture code via AI. Supports any language without a pre-built data pack."
Set-PSFConfig -Module 'SqlLabDataGenerator' -Name 'Generation.AIGeneration' -Value $false -Initialize -Validation 'bool' -Description "When enabled and AI is configured, use AI to generate entire rows of contextually-consistent data. AI understands column names, relationships, and business context for more realistic data. Falls back to static generators when AI is unavailable."
Set-PSFConfig -Module 'SqlLabDataGenerator' -Name 'Generation.NullProbability' -Value 10 -Initialize -Validation 'integerpositive' -Description "Probability (0-100) that a nullable non-FK, non-PK column will get a NULL value. Default: 10 (10%)"
Set-PSFConfig -Module 'SqlLabDataGenerator' -Name 'Generation.Mode' -Value 'Synthetic' -Initialize -Validation 'SqlLabDataGenerator.GenerationMode' -Description "Default generation mode: Synthetic, Masking, or Scenario"

# Magic-number extraction — centralised thresholds and limits
Set-PSFConfig -Module 'SqlLabDataGenerator' -Name 'Generation.MaxUniqueRetries' -Value 10 -Initialize -Validation 'integerpositive' -Description "Maximum retry attempts when generating a unique value before giving up."
Set-PSFConfig -Module 'SqlLabDataGenerator' -Name 'AI.ConfidenceThreshold' -Value 0.6 -Initialize -Validation 'double' -Description "Minimum confidence score for AI semantic classification to be accepted."

# Streaming — chunked generation for tables exceeding the threshold to prevent out-of-memory
Set-PSFConfig -Module 'SqlLabDataGenerator' -Name 'Generation.StreamingThreshold' -Value 100000 -Initialize -Validation 'integer' -Description "Row count threshold above which streaming (chunked) generation is used. Set 0 to disable streaming. Default: 100000."
Set-PSFConfig -Module 'SqlLabDataGenerator' -Name 'Generation.StreamingChunkSize' -Value 10000 -Initialize -Validation 'integerpositive' -Description "Number of rows per chunk in streaming mode. Each chunk is generated, written, and disposed. Default: 10000."

# Parallel — concurrent table generation for independent tables (PS 7+)
Set-PSFConfig -Module 'SqlLabDataGenerator' -Name 'Generation.ThrottleLimit' -Value 4 -Initialize -Validation 'integerpositive' -Description "Maximum number of tables generated concurrently when -Parallel is used. Default: 4."

# Cache management
Set-PSFConfig -Module 'SqlLabDataGenerator' -Name 'Cache.MaxEntries' -Value 500 -Initialize -Validation 'integerpositive' -Description "Maximum number of entries per module cache (AILocaleCache, AIValueCache, etc.). Oldest entries are evicted when exceeded."
Set-PSFConfig -Module 'SqlLabDataGenerator' -Name 'Cache.TTLMinutes' -Value 60 -Initialize -Validation 'integerpositive' -Description "Time-to-live in minutes for cached AI responses. Expired entries are purged on next access."

# Audit logging
Set-PSFConfig -Module 'SqlLabDataGenerator' -Name 'Audit.LogPath' -Value '' -Initialize -Validation 'string' -Description "Path to a JSON-lines audit log file. Each generation run appends a JSON record with timestamp, user, database, row counts, and success status. Leave empty to disable persistent audit logging."