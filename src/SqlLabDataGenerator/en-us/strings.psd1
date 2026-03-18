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
}