namespace SqlLabDataGenerator
{
    /// <summary>
    /// Represents information about the configured AI provider.
    /// </summary>
    public class AIProviderInfo
    {
        /// <summary>The AI provider name ('OpenAI', 'AzureOpenAI', 'Ollama').</summary>
        public string Provider { get; set; }

        /// <summary>The model name.</summary>
        public string Model { get; set; }

        /// <summary>The API endpoint URL.</summary>
        public string Endpoint { get; set; }

        /// <summary>Whether an API key has been configured.</summary>
        public bool ApiKeySet { get; set; }

        /// <summary>Maximum tokens for AI responses.</summary>
        public int MaxTokens { get; set; }

        /// <summary>Temperature setting (Ollama).</summary>
        public double Temperature { get; set; }

        /// <summary>Whether to skip certificate checks (Ollama).</summary>
        public bool SkipCertCheck { get; set; }

        /// <summary>Whether AI-powered generation is enabled.</summary>
        public bool AIGeneration { get; set; }

        /// <summary>Whether AI locale generation is enabled.</summary>
        public bool AILocale { get; set; }

        /// <summary>The configured locale.</summary>
        public string Locale { get; set; }

        /// <summary>Purpose identifier when querying for a specific purpose.</summary>
        public string Purpose { get; set; }

        /// <summary>Whether this represents a per-purpose override vs base config.</summary>
        public bool IsOverride { get; set; }

        /// <summary>Array of per-purpose model override summaries.</summary>
        public object[] ModelOverrides { get; set; }

        /// <summary>Active database name, if connected.</summary>
        public string Database { get; set; }

        /// <summary>Active server instance, if connected.</summary>
        public string ServerInstance { get; set; }

        /// <summary>Active database provider, if connected.</summary>
        public string DatabaseProvider { get; set; }

        /// <summary>Initializes a new instance of the <see cref="AIProviderInfo"/> class.</summary>
        public AIProviderInfo() { }
    }
}
