# This is where the strings go, that are written by
# Write-PSFMessage, Stop-PSFFunction or the PSFramework validation scriptblocks
@{
	# Provider
	'Provider.Register'                      = 'Registering provider: {0}'
	'Provider.NotFound'                      = 'Provider "{0}" is not registered. Available: {1}'
	'Provider.MissingFunction'               = 'Provider "{0}" is missing required function mapping: {1}'

	# Connection
	'Connect.Connecting'                     = 'Connecting to {0} database "{1}" on "{2}"'
	'Connect.Success'                        = 'Successfully connected to {0}://{1}/{2}'
	'Connect.Failed'                         = 'Failed to connect to {0} "{1}" database "{2}": {3}'
	'Disconnect.Disconnecting'               = 'Disconnecting from {0}://{1}/{2}'
	'Disconnect.NoActive'                    = 'No active database connection to disconnect'

	# Schema Discovery
	'Schema.Discovering'                     = 'Discovering schema for database "{0}"'
	'Schema.Found'                           = 'Found {0} tables with {1} total columns'
	'Schema.NoTables'                        = 'No tables found matching the specified filters'
	'Schema.ForeignKeys'                     = 'Discovered {0} foreign key relationships'

	# Semantic Analysis
	'Semantic.Analyzing'                     = 'Analyzing column semantics for {0} columns across {1} tables'
	'Semantic.PatternMatch'                  = 'Column "{0}.{1}" classified as {2} (pattern match, confidence: {3:P0})'
	'Semantic.AIAnalysis'                    = 'Requesting AI semantic analysis for {0} tables'
	'Semantic.AINotConfigured'               = 'AI provider not configured, using pattern-based classification only'
	'Semantic.PIIDetected'                   = 'PII detected in column "{0}.{1}" ({2})'
	'Semantic.ViewOverride'                  = 'View analysis overrides column "{0}.{1}" to {2} (active function detection)'

	# Generation
	'Generation.CreatingPlan'                = 'Creating generation plan for {0} tables'
	'Generation.TableOrder'                  = 'Table insertion order resolved: {0}'
	'Generation.CyclicDependency'            = 'Circular FK dependencies detected for: {0}. These will be appended at the end.'
	'Generation.Starting'                    = 'Starting data generation: {0} tables, mode: {1}'
	'Generation.Table'                       = 'Generating {0} rows for [{1}].[{2}]'
	'Generation.TableComplete'               = 'Completed {0}: {1} rows inserted'
	'Generation.Complete'                    = 'Data generation complete: {0} tables, {1} total rows'
	'Generation.Failed'                      = 'Data generation failed for [{0}].[{1}]: {2}'
	'Generation.SkippingComputed'            = 'Skipping computed/identity column: {0}.{1}'
	'Generation.SkippingSpatial'             = 'Skipping spatial/UDT column: {0}.{1}'
	'Generation.SkippedDueToParent'          = 'Skipping table {0} — parent table(s) failed: {1}'
	'Generation.FKFallbackLoaded'            = 'FK fallback: loaded {1} existing values for {0}'
	'Generation.FKFallbackFailed'            = 'FK fallback: could not read existing values for {0}: {1}'
	'Generation.BulkCopyFallback'            = 'BulkCopy failed for {0} ({1}), falling back to row-by-row insert'
	'Generation.RowsSkipped'                 = '{0} rows skipped due to constraint violations in {1}'

	# Validation
	'Validation.Starting'                    = 'Validating generated data for {0} tables'
	'Validation.FKCheck'                     = 'Checking foreign key integrity for [{0}].[{1}]'
	'Validation.FKViolation'                 = 'FK violation: [{0}].[{1}].{2} references [{3}].[{4}].{5} - {6} orphaned rows'
	'Validation.UniqueCheck'                 = 'Checking unique constraints for [{0}].[{1}]'
	'Validation.UniqueViolation'             = 'Unique constraint violation on [{0}].[{1}].{2}: {3} duplicate values'
	'Validation.Complete'                    = 'Validation complete: {0} checks passed, {1} warnings, {2} errors'

	# Profile
	'Profile.Importing'                      = 'Importing generation profile from: {0}'
	'Profile.Exporting'                      = 'Exporting generation profile to: {0}'
	'Profile.RuleCount'                      = 'Profile contains {0} table rules with {1} column overrides'

	# AI
	'AI.RequestFailed'                       = 'AI request failed after all retries: {0}'
	'AI.RetryAttempt'                        = 'AI request failed (attempt {0}/{1}), retrying in {2}s: {3}'
	'AI.RateLimitWaiting'                    = 'AI rate limit reached, waiting {0}s before next request'
	'AI.ParseFailed'                         = 'Failed to parse AI response: {0}'
	'AI.UnknownProvider'                     = 'Unknown AI provider: {0}. Supported: OpenAI, AzureOpenAI, Ollama'
	'AI.UnexpectedResponse'                  = 'Unexpected response format from AI provider: {0}'
	'AI.BatchGenerating'                     = 'AI generating {1} rows for table "{0}" (locale: {2})'
	'AI.BatchGenerated'                      = 'AI generated {1} rows for table "{0}"'
	'AI.BatchParseFailed'                    = 'Failed to parse AI-generated batch for table "{0}": {1}'
	'AI.PlanAdviceRequesting'                = 'Requesting AI plan advice for {0} tables'
	'AI.PlanAdviceReceived'                  = 'AI plan advice received: {0} table suggestions, {1} custom rules'
	'AI.PlanAdviceFailed'                    = 'Failed to parse AI plan advice: {0}'
	'AI.PlanAdviceApplying'                  = 'Applying AI advice: {0} table row counts, {1} custom rules'
	'AI.ProviderConfigured'                  = 'AI provider configured: {0} (model: {1})'
	'AI.ProviderNotConfigured'               = 'No AI provider configured. Use Set-SldgAIProvider to configure one.'
	'AI.TestStarting'                        = 'Testing AI provider: {0} (model: {1})'
	'AI.TestSuccess'                         = 'AI provider {0} ({1}) is reachable — response in {2}ms'
	'AI.TestNoResponse'                      = 'AI provider returned no response. Check model name and endpoint.'
	'AI.TestFailed'                          = 'AI provider {0} test failed: {1}'

	# Structured Data (JSON/XML)
	'StructuredData.AIGenerating'            = 'AI generating {0} structure for table "{1}" column "{2}"'
	'StructuredData.AIGenerated'             = 'AI generated {1} {0} templates for {2}.{3}'
	'StructuredData.AIFailed'                = 'AI {0} generation failed for {1}.{2}: {3}'

	# Locale
	'Locale.Register'                        = 'Registering locale: {0}'
	'Locale.Registered'                      = 'Locale "{0}" registered successfully'
	'Locale.NotFound'                        = 'Locale "{0}" is not registered. Use Register-SldgLocale to add it, or enable Generation.AILocale for automatic AI generation.'
	'Locale.Fallback'                        = 'Locale "{0}" not found, falling back to "{1}"'
	'Locale.MissingKey'                      = 'Locale "{0}" is missing required data key: {1}'
	'Locale.AIGenerating'                    = 'Generating locale "{0}" via AI ({1})... This may take a moment.'
	'Locale.AIGenerated'                     = 'AI-generated locale "{0}" ready and cached'
	'Locale.AICacheHit'                      = 'Using cached AI-generated locale: {0}'
	'Locale.AINotConfigured'                 = 'Cannot generate locale "{0}" via AI: No AI provider configured. Set SqlLabDataGenerator.AI.Provider first.'
	'Locale.AIFailed'                        = 'AI failed to generate locale "{0}". Check AI provider configuration.'
	'Locale.AIParseFailed'                   = 'Failed to parse AI-generated locale data for "{0}": {1}'
	'Locale.AIMissingKey'                    = 'AI-generated locale "{0}" is missing key "{1}" - using empty array'
	'Locale.AIFallback'                      = 'Locale "{0}" not registered, attempting AI generation via {1}'
	'Locale.AIFallbackFailed'                = 'AI locale generation failed for "{0}": {1}. Falling back to en-US.'
	'Locale.AIMixGenerating'                 = 'Generating mixed locale "{0}" from categories: {1}'
	'Locale.AICategoryGenerating'            = 'Generating {0} data for language: {1}'
	'Locale.AICategoryGenerated'             = 'AI-generated {0} data for "{1}" ready and cached'
	'Locale.AICategoryFailed'                = 'AI failed to generate {0} data for "{1}"'

	# Transform
	'Transform.Register'                     = 'Registering transformer: {0}'
	'Transform.NotFound'                     = 'Transformer "{0}" is not registered. Available: {1}'
	'Transform.Starting'                     = 'Transforming {1} rows using transformer "{0}"'
	'Transform.Complete'                     = 'Transformation "{0}" complete: {1} objects created'
	'Transform.Exported'                     = 'Transformed data exported to: {0} ({1} objects)'

	# Masking
	'Generation.MaskingStarting'             = 'Starting data masking: reading {0} rows from [{1}].[{2}]'
	'Generation.MaskingComplete'             = 'Masking complete for [{0}].[{1}]: {2} rows masked'
	'Generation.MaskingNotSupported'         = 'Masking mode requires an active connection with ReadData support.'

	# Connection health
	'Connect.HealthCheckFailed'              = 'Connection health check failed for {0}://{1}/{2}: connection is not in Open state'

	# Audit
	'Audit.Written'                          = 'Audit log entry written to: {0}'
	'Audit.WriteFailed'                      = 'Failed to write audit log entry: {0}'

	# Scenario
	'Scenario.AutoDetected'                  = 'Auto-detected scenario template: {0} (matched {1} tables)'
	'Scenario.NotFound'                      = 'Scenario template "{0}" not found. Available: {1}'
	'Scenario.Applying'                      = 'Applying scenario template: {0} — {1}'
	'Scenario.FallbackSynthetic'             = 'No matching scenario template found. Generating with default row counts.'

	# Parallel
	'Generation.ParallelStarting'            = 'Parallel generation: {0} dependency levels, throttle limit: {1}'

	# Streaming
	'Generation.StreamingStarting'           = 'Streaming generation for {0}: {1} rows in chunks of {2}'

	# Invoke-PSFProtectedCommand action strings
	'Generation.MaskingTable'                = 'Masking {0} rows in [{1}].[{2}]'
	'Generation.InsertingTable'              = 'Generating {0} rows for [{1}].[{2}]'

	# Generation Rule
	'GenerationRule.TableNotFound'           = "Table '{0}' not found in plan. Rule stored but may not be applied during generation."
	'GenerationRule.ColumnNotFound'          = "Column '{0}' not found in table '{1}'. Rule stored but may not be applied during generation."

	# Profile Import
	'Profile.ScriptBlockSkipped'             = "Profile '{0}': column '{1}' in table '{2}' contains a 'scriptBlock' key — skipped for security."
	'Profile.UnknownGenerator'               = "Profile '{0}': column '{1}' in table '{2}' specifies unknown generator '{3}' — skipped. Known generators: {4}"
	'Profile.ColumnNotFound'                 = "Profile '{2}': column '{0}' not found in table '{1}' — skipped."
	'Profile.Exported'                       = 'Profile exported to: {0}'
	'Profile.ExportPathInvalid'              = 'Invalid export path (contains relative segments): {0}'

	# Prompt Template Management
	'Prompt.PurposeRequired'                 = 'Purpose is required. Use -Purpose or pipe from Get-SldgPromptTemplate.'
	'Prompt.FileNotFound'                    = 'File not found: {0}'
	'Prompt.ContentEmpty'                    = 'Prompt content cannot be empty. Use -Content, -FilePath, or pipe from Get-SldgPromptTemplate -IncludeContent.'
	'Prompt.PromptPathAutoconfigured'        = 'AI.PromptPath not configured. Set to: {0}'
	'Prompt.DirectoryCreated'                = 'Created custom prompt directory: {0}'
	'Prompt.Saved'                           = 'Custom prompt saved: {0}'
	'Prompt.SkippingBuiltIn'                 = "Skipping built-in template '{0}.{1}' — only custom overrides can be removed."
	'Prompt.CustomNotFound'                  = 'Custom prompt not found: {0}'
	'Prompt.Removed'                         = 'Custom prompt removed: {0}'
	'Prompt.NoCustomPath'                    = 'No custom prompt path configured or directory does not exist.'
	'Prompt.TemplateNotFound'                = "Prompt template not found for purpose '{0}' (variant: {1}). Searched: {2}"
	'Prompt.TemplateResolved'                = 'Resolved prompt template: {0}'
	'Prompt.ResolveFailed'                   = 'Failed to resolve {0} prompt template.'

	# AI Provider
	'AI.OverrideSet'                         = "AI model override set for purpose '{0}': {1} / {2}"
	'AI.TLSDisabledWarning'                  = 'TLS certificate validation is disabled for the AI endpoint. This is insecure and should only be used in development environments with self-signed certificates.'
	'AI.ModelOverrideUsing'                  = "Using AI model override for purpose '{0}': {1} / {2}"
	'AI.ApiKeyFailed'                        = 'Failed to retrieve API key: {0}'
	'AI.TLSSkipBlocked'                      = 'TLS certificate validation skip requested for Ollama but blocked. Set environment variable SLDG_ALLOW_SKIP_TLS=1 to allow this in development environments.'
	'AI.TLSSkipActive'                       = 'TLS certificate validation is disabled for Ollama (SLDG_ALLOW_SKIP_TLS is set). This should NEVER be used in production environments.'
	'AI.PlanAdviceSkipped'                   = "AI plan advice skipped: AI provider is 'None'."
	'AI.PlanAdviceNoResponse'                = 'AI plan advice returned no response.'
	'AI.SchemaAnalysisSkipped'               = "AI schema analysis skipped: AI provider is 'None'."
	'AI.SchemaAnalysisNoResponse'            = 'AI schema analysis returned no response.'
	'AI.SchemaAnalysisRequesting'            = 'Requesting AI schema analysis with sample data for {0} tables'
	'AI.SchemaAnalysisReceived'              = 'AI schema analysis received: {0} table generation notes'
	'AI.SchemaAnalysisFailed'                = 'Failed to parse AI schema analysis: {0}'
	'AI.SchemaAnalysisApplying'              = 'Applying schema analysis notes for {0} tables (two-tier AI)'
	'AI.BatchSkipped'                        = "AI batch generation skipped for table '{0}': AI provider is 'None'."
	'AI.BatchNoResponse'                     = "AI batch generation for table '{0}' returned no response."
	'AI.BatchFallbackWarning'                = "AI generation failed for table '{0}'. Falling back to pattern-based generators - data quality may be reduced."
	'AI.CircuitBreakerOpen'                  = 'AI circuit breaker is OPEN after {0} consecutive failures. AI calls will be skipped for {1}s. Pattern-based generators will be used instead.'
	'AI.CircuitBreakerReset'                 = 'AI circuit breaker reset after cooldown period. Retrying AI requests.'
	'AI.BatchNotArray'                       = 'AI response is not an array'
	'AI.AnalysisBatch'                       = 'AI analysis batch {0}/{1}: {2}'
	'AI.LocaleMultiple'                      = 'Multiple locales specified: {0}. Distribute rows roughly evenly across these locales. Each row must be culturally consistent within its locale — a person from one culture must have names, addresses, phone numbers, and other values matching that same culture. Do NOT mix languages within a single row.'
	'AI.LocaleSingle'                        = 'Generate all data in the native language and cultural conventions of {0}.'
	'AI.IndustryContext'                     = 'Industry context: {0} — use industry-specific terminology and realistic values.'
	'AI.IndustryAnalysisContext'             = 'The database is from the {0} industry. Use industry-specific terminology, common patterns, realistic value ranges, and domain knowledge for generation hints.'
	'AI.BatchUserMessage'                    = 'Generate {0} rows of test data for table {1} with locale {2}. Return ONLY the JSON array.'
	'AI.AnalysisUserMessage'                 = 'Analyze this database schema and provide detailed semantic classification for every column:'

	# Connection (provider-specific)
	'Connect.SqlServer.Connected'            = "Connected to SQL Server '{0}' database '{1}'"
	'Connect.SqlServer.Disconnected'         = "Disconnected from SQL Server '{0}'"
	'Connect.SQLite.Connected'               = "Connected to SQLite database '{0}'"
	'Connect.SQLite.Disconnected'            = "Disconnected from SQLite database '{0}'"
	'Connect.SQLite.DisconnectFailed'        = 'Error disconnecting from SQLite: {0}'
	'Connect.SQLite.RollbackFailed'          = 'SQLite transaction rollback failed: {0}'
	'Connect.NoActiveConnection'             = 'No active database connection. Use Connect-SldgDatabase first.'
	'Connect.NoActiveConnectionOrNoInsert'   = 'No active database connection. Use Connect-SldgDatabase first, or use -NoInsert.'

	# Schema (provider-specific)
	'Schema.SqlServer.Retrieved'             = 'Retrieved: {0} tables, {1} columns, {2} FK relationships'
	'Schema.SqlServer.Inserted'              = 'Inserted {0} rows into {1}'
	'Schema.SqlServer.Read'                  = 'Read {0} rows from {1}'

	# Generation (extended)
	'Generation.AuditStart'                  = 'Generation audit: user={0}, database={1}, tables={2}, mode={3}'
	'Generation.TransactionStarted'          = 'Transaction started for data generation (provider: {0})'
	'Generation.MaskingTransactionStarted'   = 'Transaction auto-started for masking mode (destructive DELETE+INSERT requires atomicity)'
	'Generation.FKDisabledPragma'            = 'Disabled FK constraints (PRAGMA) for {0} circular dependency tables'
	'Generation.FKDisablePragmaFailed'       = 'Could not disable FK constraints (PRAGMA): {0}'
	'Generation.FKDisabledTable'             = 'Disabled FK constraints for circular dependency table {0}'
	'Generation.FKDisableTableFailed'        = 'Could not disable FK constraints for {0}: {1}'
	'Generation.MaskingNoRows'               = 'No rows read from {0} — skipping masking to prevent data loss'
	'Generation.RollingBack'                 = 'Rolling back transaction due to failure in {0}'
	'Generation.RollbackCritical'            = 'CRITICAL: Transaction rollback failed — database may be in inconsistent state: {0}'
	'Generation.MaskingRollingBack'          = 'Rolling back transaction due to masking failure in {0}'
	'Generation.MaskingRollbackCritical'     = 'CRITICAL: Transaction rollback failed for masking operation — database may be in inconsistent state: {0}'
	'Generation.MaskingRolledBack'           = 'Masking rolled back due to failure in {0}'
	'Generation.DataRolledBack'              = 'Data generation rolled back due to failure in {0}'
	'Generation.FKReenabledPragma'           = 'Re-enabled FK constraints (PRAGMA) for circular dependency tables'
	'Generation.FKReenablePragmaFailed'      = 'Could not re-enable FK constraints (PRAGMA): {0}'
	'Generation.FKReenabledTable'            = 'Re-enabled FK constraints for {0}'
	'Generation.FKReenableTableFailed'       = 'Could not re-enable FK constraints for {0}: {1}'
	'Generation.TransactionCommitted'        = 'Transaction committed successfully'
	'Generation.CommitFailed'                = 'Transaction commit failed, rolling back: {0}'
	'Generation.CommitRollbackCritical'      = 'CRITICAL: Transaction rollback after commit failure also failed — database may be in inconsistent state: {0}'
	'Generation.AuditComplete'               = 'Generation audit complete: user={0}, rows={1}, duration={2}s, failed={3}'
	'Generation.AuditWritten'                = 'Audit log entry written to: {0}'
	'Generation.AuditWriteFailed'            = 'Failed to write audit log entry: {0}'
	'Generation.StreamingChunk'              = 'Streaming chunk {0}/{1}: generating {2} rows for {3}'
	'Generation.StreamingChunkFailed'        = 'Streaming chunk {0}/{1} write failed for {2}: {3}'

	# Table Dependency Grouping
	'Generation.LevelComputationStopped'     = 'Level computation stopped after {0} iterations — possible circular FK dependency. Results may be approximate.'
	'Generation.DependencyLevels'            = 'Table dependency levels: {0} levels, max parallelism at level 0: {1} tables'

	# Scenario
	'Scenario.NoMatch'                       = 'No scenario template matched the schema (best score: {0}). Returning null.'

	# Locale (extended)
	'Locale.UnknownCategory'                 = "Unknown category '{0}'. Valid: {1}"
	'Locale.PromptResolveFailed'             = "Failed to resolve locale-data prompt template for locale '{0}'."
	'Locale.CategoryPromptResolveFailed'     = "Failed to resolve locale-category prompt template for '{0}/{1}'."

	# Provider Registration (extended)
	'Provider.FunctionNotExists'             = "Provider '{0}' references function '{1}' for '{2}' but it does not exist."
	'Provider.MissingParameter'              = "Provider '{0}': function '{1}' for '{2}' is missing required parameter '-{3}'."

	# Cache Eviction
	'Cache.TTLEvicted'                       = "Cache '{0}': TTL-evicted {1} expired entries"
	'Cache.SizeEvicted'                      = "Cache '{0}': size-evicted {1} entries (max: {2})"

	# Column Analysis
	'Semantic.PromptResolveFailed'           = 'Failed to resolve column-analysis prompt template.'

	# Cache Management
	'Cache.Cleared'                          = 'Cleared {0} entries from {1}.'
	'Cache.ClearedAll'                       = 'Cleared {0} entries from all AI caches.'

	# Session Management
	'Session.ClosingConnection'              = 'Closing active connection to {0}/{1}'
	'Session.ResetComplete'                  = 'Session reset: closed connection, cleared {0} providers, {1} locales, {2} cached items.'

	# Generation (hardcoded fixes)
	'Generation.ParallelRollbackFailed'      = 'Parallel rollback failed: {0}'
	'Generation.MaxPKQueryFailed'            = 'Could not query MAX PK for {0}: {1}'
	'Generation.PostInsertPKCollected'       = 'Post-insert PK collection: {0} = {1} values'
	'Generation.PostInsertPKFailed'          = 'Could not collect post-insert PK for {0}: {1}'
	'Generation.FKReenableRollbackFailed'    = 'FK re-enable rollback failed: {0}'
	'Generation.FKReenableCritical'          = 'CRITICAL: FK constraints could not be re-enabled on: {0}. Manual intervention required.'

	# Profile Import (hardcoded fixes)
	'Profile.FileTooLarge'                   = "Profile file '{0}' is {1} MB, exceeding the {2} MB limit."
	'Profile.InvalidRowCount'               = "Profile: Invalid rowCount '{0}' for table '{1}' — skipping override."

	# Generation Rule
	'GenerationRule.FKValueListWarning'      = "Column '{0}' in '{1}' has a foreign key to '{2}.{3}'. ValueList values may cause FK violations if they don't exist in the parent table."

	# AI Provider Validation
	'AI.EndpointCredentialsForbidden'        = 'Endpoint URI must not contain embedded credentials. Use -ApiKey or -Credential instead.'
	'AI.EndpointHttpsForbidden'              = 'Endpoint for {0} must use HTTPS. Got: {1}://{2}'
	'AI.EndpointInvalidUri'                  = 'Invalid endpoint URI for {0}.'

	# Locale (hardcoded fixes)
	'Locale.AIGenerationFailed'              = "AI locale generation failed for '{0}': {1}. Falling back to en-US."
	'Locale.AICategoryMixFailed'             = "AI locale category '{0}' generation failed for '{1}': {2}. Keeping base locale data for this category."
	'Locale.MixMissingKeys'                  = "Mixed locale '{0}' is missing required keys: {1}. Generation may fail for some semantic types."

	# Internal: RowSet Generation
	'RowSet.CircularDependency'              = "Circular cross-column dependency detected for column '{0}' in '{1}'. Dependency chain will be broken."
	'RowSet.CompositePKCapped'               = "Requested {0} rows for '{1}' but only {2} unique FK combinations exist. Capping to {2}."
	'RowSet.FKExhausted'                     = "All FK values exhausted for unique column '{0}' in '{1}'. Cannot generate more unique rows."
	'RowSet.ValueTruncated'                  = "Truncating value for column '{0}' from {1} to {2} characters."
	'RowSet.UniqueRetriesExhausted'          = "Row {0} for '{1}' skipped: could not generate unique values after {2} retries."

	# Internal: FK Context-Aware Batch
	'FKContext.ParentCountExceedsLimit'      = "FK parent count ({0}) exceeds limit ({1}) for '{2}'. Using flat batch."
	'FKContext.GroupingRows'                 = "FK-context-aware generation for '{0}': grouping {1} rows by '{2}' ({3} parent values)"
	'FKContext.MultiFKGrouping'             = "Multi-FK context-aware generation for '{0}': grouping {1} rows by primary FK '{2}' + secondary FK '{3}'"

	# Internal: AI Batch Generation
	'AI.BatchMissingColumns'                 = "AI response for '{0}' missing columns: {1}. Using NULL for missing values."
	'AI.BatchRowCountMismatch'               = "AI batch for '{0}': received {1} of {2} requested rows. AI may have hit output limit."

	# Internal: Generated Value
	'Generation.FKParentValuesNotFound'      = "No parent values found for FK column '{0}' referencing '{1}'. Parent table may not have been populated."

	# Internal: Existing Unique Values
	'Generation.UniqueQueryFailed'           = "Could not query existing unique values for {0}: {1}"

	# Internal: Schema Analysis
	'AI.SchemaAnalysisSampleFailed'          = "Could not query sample data for {0}: {1}"

	# Internal: Parallel Generation
	'Generation.ParallelMaxPKQueryFailed'    = 'Could not query MAX PK for {0}: {1}'

	# Internal: Schema Conversion
	'Schema.ViewRegexTimeout'                = "Regex timeout while parsing view definition for table '{0}'. View hints skipped for this view."

	# Internal: Write Providers
	'Write.BulkCopyDisposeFailed'            = 'BulkCopy dispose failed: {0}'
	'Write.IdentityInsertOffFailed'          = 'IDENTITY_INSERT OFF failed after fallback: {0}'
	'Write.SQLiteConstraintViolations'       = "SQLite INSERT: {0} of {1} rows ignored due to constraint violations in table '{2}'."

	# Internal: Locale Registration
	'Locale.KeyNullValue'                    = "Locale '{0}': key '{1}' has a `$null value. Each required key must contain a non-empty array or string."
	'Locale.KeyEmptyArray'                   = "Locale '{0}': key '{1}' is an empty array. At least one value is required."

	# Internal: AI Batch Max Iterations
	'AI.BatchMaxIterations'                  = "AI batch generation for '{0}' stopped after {1} iterations with {2} rows still remaining."

	# Profile: Invalid JSON
	'Profile.InvalidJson'                    = "Profile '{0}' contains invalid JSON: {1}"

	# Connect: SQL Server credential warning
	'Connect.SqlServer.CredentialWarning'    = 'SQL authentication extracts password to plaintext for connection string. Consider using Integrated Security where possible.'
}