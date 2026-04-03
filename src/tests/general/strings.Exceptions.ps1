$exceptions = @{ }

<#
A list of entries that MAY be in the language files, without causing the tests to fail.
This is commonly used in modules that generate localized messages straight from C#.
Specify the full key as it is written in the language files, do not prepend the modulename,
as you would have to in C# code.

Example:
$exceptions['LegalSurplus'] = @(
    'Exception.Streams.FailedCreate'
    'Exception.Streams.FailedDispose'
)
#>
$exceptions['LegalSurplus'] = @(
	# Module uses $script:strings.'Key' pattern which Export-PSMDString cannot detect.
	# All strings referenced via $script:strings.'X' must be listed here since the
	# static analysis tool only finds $PSLocalizedData.X or Write-PSFMessage -String patterns.

	# --- AI ---
	'AI.AnalysisBatch'
	'AI.AnalysisUserMessage'
	'AI.ApiKeyFailed'
	'AI.BatchFallbackWarning'
	'AI.BatchGenerated'
	'AI.BatchGenerating'
	'AI.BatchMaxIterations'
	'AI.BatchMissingColumns'
	'AI.BatchNoResponse'
	'AI.BatchNotArray'
	'AI.BatchParseFailed'
	'AI.BatchRowCountMismatch'
	'AI.BatchSkipped'
	'AI.BatchUserMessage'
	'AI.CircuitBreakerOpen'
	'AI.CircuitBreakerReset'
	'AI.IndustryAnalysisContext'
	'AI.IndustryContext'
	'AI.LocaleMultiple'
	'AI.LocaleSingle'
	'AI.ModelOverrideUsing'
	'AI.OverrideSet'
	'AI.ParseFailed'
	'AI.PlanAdviceApplying'
	'AI.PlanAdviceFailed'
	'AI.PlanAdviceNoResponse'
	'AI.PlanAdviceReceived'
	'AI.PlanAdviceRequesting'
	'AI.PlanAdviceSkipped'
	'AI.ProviderConfigured'
	'AI.ProviderNotConfigured'
	'AI.RateLimitWaiting'
	'AI.RequestFailed'
	'AI.RetryAttempt'
	'AI.SchemaAnalysisApplying'
	'AI.SchemaAnalysisFailed'
	'AI.SchemaAnalysisNoResponse'
	'AI.SchemaAnalysisReceived'
	'AI.SchemaAnalysisRequesting'
	'AI.SchemaAnalysisSampleFailed'
	'AI.SchemaAnalysisSkipped'
	'AI.TestFailed'
	'AI.TestNoResponse'
	'AI.TestStarting'
	'AI.TestSuccess'
	'AI.TLSDisabledWarning'
	'AI.TLSSkipActive'
	'AI.TLSSkipBlocked'
	'AI.UnexpectedResponse'
	'AI.UnknownProvider'

	# --- Audit ---
	'Audit.WriteFailed'
	'Audit.Written'

	# --- Cache ---
	'Cache.Cleared'
	'Cache.ClearedAll'
	'Cache.SizeEvicted'
	'Cache.TTLEvicted'

	# --- Connect / Disconnect ---
	'Connect.Connecting'
	'Connect.Failed'
	'Connect.HealthCheckFailed'
	'Connect.SQLite.Connected'
	'Connect.SQLite.Disconnected'
	'Connect.SQLite.DisconnectFailed'
	'Connect.SQLite.RollbackFailed'
	'Connect.SqlServer.Connected'
	'Connect.SqlServer.CredentialWarning'
	'Connect.SqlServer.Disconnected'
	'Connect.Success'
	'Disconnect.Disconnecting'
	'Disconnect.NoActive'

	# --- FK Context ---
	'FKContext.GroupingRows'
	'FKContext.MultiFKGrouping'
	'FKContext.ParentCountExceedsLimit'

	# --- Generation ---
	'Generation.AuditComplete'
	'Generation.AuditStart'
	'Generation.AuditWriteFailed'
	'Generation.AuditWritten'
	'Generation.BulkCopyFallback'
	'Generation.CommitFailed'
	'Generation.CommitRollbackCritical'
	'Generation.Complete'
	'Generation.CreatingPlan'
	'Generation.CyclicDependency'
	'Generation.DependencyLevels'
	'Generation.Failed'
	'Generation.FKDisabledPragma'
	'Generation.FKDisablePragmaFailed'
	'Generation.FKDisabledTable'
	'Generation.FKDisableTableFailed'
	'Generation.FKFallbackFailed'
	'Generation.FKFallbackLoaded'
	'Generation.FKParentValuesNotFound'
	'Generation.FKReenabledPragma'
	'Generation.FKReenablePragmaFailed'
	'Generation.FKReenabledTable'
	'Generation.FKReenableRollbackFailed'
	'Generation.FKReenableTableFailed'
	'Generation.LevelComputationStopped'
	'Generation.MaskingComplete'
	'Generation.MaskingNoRows'
	'Generation.MaskingNotSupported'
	'Generation.MaskingRollbackCritical'
	'Generation.MaskingRollingBack'
	'Generation.MaskingStarting'
	'Generation.MaskingTransactionStarted'
	'Generation.MaxPKQueryFailed'
	'Generation.ParallelMaxPKQueryFailed'
	'Generation.ParallelRollbackFailed'
	'Generation.ParallelStarting'
	'Generation.PostInsertPKCollected'
	'Generation.PostInsertPKFailed'
	'Generation.RollbackCritical'
	'Generation.RollingBack'
	'Generation.RowsSkipped'
	'Generation.SkippedDueToParent'
	'Generation.SkippingComputed'
	'Generation.SkippingSpatial'
	'Generation.Starting'
	'Generation.StreamingChunk'
	'Generation.StreamingChunkFailed'
	'Generation.StreamingStarting'
	'Generation.Table'
	'Generation.TableComplete'
	'Generation.TableOrder'
	'Generation.TransactionCommitted'
	'Generation.TransactionStarted'
	'Generation.UniqueQueryFailed'

	# --- GenerationRule ---
	'GenerationRule.ColumnNotFound'
	'GenerationRule.FKValueListWarning'
	'GenerationRule.TableNotFound'

	# --- Locale ---
	'Locale.AICacheHit'
	'Locale.AICategoryFailed'
	'Locale.AICategoryGenerated'
	'Locale.AICategoryGenerating'
	'Locale.AICategoryMixFailed'
	'Locale.AIFailed'
	'Locale.AIFallback'
	'Locale.AIFallbackFailed'
	'Locale.AIGenerated'
	'Locale.AIGenerating'
	'Locale.AIGenerationFailed'
	'Locale.AIMissingKey'
	'Locale.AIMixGenerating'
	'Locale.AINotConfigured'
	'Locale.AIParseFailed'
	'Locale.Fallback'
	'Locale.MissingKey'
	'Locale.MixMissingKeys'
	'Locale.NotFound'
	'Locale.Register'
	'Locale.Registered'
	'Locale.UnknownCategory'

	# --- Profile ---
	'Profile.ColumnNotFound'
	'Profile.Exported'
	'Profile.Exporting'
	'Profile.Importing'
	'Profile.InvalidRowCount'
	'Profile.RuleCount'
	'Profile.ScriptBlockSkipped'
	'Profile.UnknownGenerator'

	# --- Prompt ---
	'Prompt.CustomNotFound'
	'Prompt.DirectoryCreated'
	'Prompt.PromptPathAutoconfigured'
	'Prompt.Removed'
	'Prompt.ResolveFailed'
	'Prompt.Saved'
	'Prompt.SkippingBuiltIn'
	'Prompt.TemplateNotFound'
	'Prompt.TemplateResolved'

	# --- Provider ---
	'Provider.MissingFunction'
	'Provider.NotFound'
	'Provider.Register'

	# --- RowSet ---
	'RowSet.CircularDependency'
	'RowSet.CompositePKCapped'
	'RowSet.FKExhausted'
	'RowSet.UniqueRetriesExhausted'
	'RowSet.ValueTruncated'

	# --- Scenario ---
	'Scenario.Applying'
	'Scenario.AutoDetected'
	'Scenario.FallbackSynthetic'
	'Scenario.NoMatch'
	'Scenario.NotFound'

	# --- Schema ---
	'Schema.Discovering'
	'Schema.ForeignKeys'
	'Schema.Found'
	'Schema.NoTables'
	'Schema.SqlServer.Inserted'
	'Schema.SqlServer.Read'
	'Schema.SqlServer.Retrieved'
	'Schema.ViewRegexTimeout'

	# --- Semantic ---
	'Semantic.AIAnalysis'
	'Semantic.AINotConfigured'
	'Semantic.Analyzing'
	'Semantic.PatternMatch'
	'Semantic.PIIDetected'
	'Semantic.PromptResolveFailed'
	'Semantic.ViewOverride'

	# --- Session ---
	'Session.ClosingConnection'
	'Session.ResetComplete'

	# --- StructuredData ---
	'StructuredData.AIFailed'
	'StructuredData.AIGenerated'
	'StructuredData.AIGenerating'

	# --- Transform ---
	'Transform.Complete'
	'Transform.Exported'
	'Transform.NotFound'
	'Transform.Register'
	'Transform.Starting'

	# --- Validation ---
	'Validation.Complete'
	'Validation.FKCheck'
	'Validation.FKViolation'
	'Validation.Starting'
	'Validation.UniqueCheck'
	'Validation.UniqueViolation'

	# --- Write ---
	'Write.BulkCopyDisposeFailed'
	'Write.IdentityInsertOffFailed'
	'Write.SQLiteConstraintViolations'
)
<#
A list of entries that MAY be used without needing to have text defined.
This is intended for modules (re-)using strings provided by another module
#>
$exceptions['NoTextNeeded'] = @(
	'Validate.FSPath'
	'Validate.FSPath.File'
	'Validate.FSPath.FileOrParent'
	'Validate.FSPath.Folder'
	'Validate.Path'
	'Validate.Path.Container'
	'Validate.Path.Leaf'
	'Validate.TimeSpan.Positive'
	'Validate.Uri.Absolute'
	'Validate.Uri.Absolute.File'
	'Validate.Uri.Absolute.Https'
)

$exceptions