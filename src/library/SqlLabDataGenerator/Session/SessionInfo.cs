using System;
using System.Collections.Generic;

namespace SqlLabDataGenerator
{
    /// <summary>
    /// Summary snapshot of the current session state returned by Get-SldgSession.
    /// </summary>
    public class SessionInfo
    {
        /// <summary>Unique identifier of the session.</summary>
        public Guid SessionId { get; set; }

        /// <summary>When the session was created (UTC).</summary>
        public DateTime CreatedAt { get; set; }

        /// <summary>Connection summary, or null when disconnected.</summary>
        public ConnectionSummary Connection { get; set; }

        /// <summary>AI provider configuration summary.</summary>
        public AIProviderSummary AIProvider { get; set; }

        /// <summary>Names of registered database providers.</summary>
        public string[] RegisteredProviders { get; set; }

        /// <summary>Names of registered data transformers.</summary>
        public string[] RegisteredTransformers { get; set; }

        /// <summary>Names of registered locale packs.</summary>
        public string[] RegisteredLocales { get; set; }

        /// <summary>Number of entries in each AI cache.</summary>
        public CacheSummary CacheSizes { get; set; }

        /// <summary>Names of active generation plans.</summary>
        public string[] GenerationPlans { get; set; }

        /// <summary>Per-database generation history entries.</summary>
        public GenerationHistoryEntry[] GenerationHistory { get; set; }
    }

    /// <summary>
    /// Summarises the active database connection.
    /// </summary>
    public class ConnectionSummary
    {
        /// <summary>The database provider ('SqlServer' or 'SQLite').</summary>
        public string Provider { get; set; }

        /// <summary>The server instance or hostname.</summary>
        public string ServerInstance { get; set; }

        /// <summary>The database name or file path.</summary>
        public string Database { get; set; }

        /// <summary>Current connection state ('Open', 'Closed', 'Disposed').</summary>
        public string State { get; set; }
    }

    /// <summary>
    /// Summarises the AI provider configuration.
    /// </summary>
    public class AIProviderSummary
    {
        /// <summary>The active AI provider name (e.g. 'AzureOpenAI', 'Ollama', 'None').</summary>
        public string Provider { get; set; }

        /// <summary>The active AI model name.</summary>
        public string Model { get; set; }

        /// <summary>Per-purpose model overrides (key = purpose, value = "Provider/Model").</summary>
        public Dictionary<string, string> Overrides { get; set; }
    }

    /// <summary>
    /// Number of cached entries in each AI cache.
    /// </summary>
    public class CacheSummary
    {
        /// <summary>AI-generated column value cache size.</summary>
        public int AIValueCache { get; set; }

        /// <summary>AI-generated locale data cache size.</summary>
        public int AILocaleCache { get; set; }

        /// <summary>AI-generated locale category data cache size.</summary>
        public int AILocaleCategoryCache { get; set; }

        /// <summary>Total number of cache timestamp entries.</summary>
        public int CacheTimestamps { get; set; }
    }

    /// <summary>
    /// One entry in the per-database generation history.
    /// </summary>
    public class GenerationHistoryEntry
    {
        /// <summary>The database name or path.</summary>
        public string Database { get; set; }

        /// <summary>Number of tables in the generation result.</summary>
        public int Tables { get; set; }
    }
}
