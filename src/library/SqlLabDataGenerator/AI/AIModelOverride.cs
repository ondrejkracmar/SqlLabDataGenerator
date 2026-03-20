namespace SqlLabDataGenerator
{
    /// <summary>
    /// Represents a per-purpose AI model override configuration.
    /// </summary>
    public class AIModelOverride
    {
        /// <summary>The purpose this override applies to.</summary>
        public string Purpose { get; set; }

        /// <summary>The AI provider for this purpose.</summary>
        public string Provider { get; set; }

        /// <summary>The model name for this purpose.</summary>
        public string Model { get; set; }

        /// <summary>The API endpoint for this purpose.</summary>
        public string Endpoint { get; set; }

        /// <summary>Maximum tokens for this purpose.</summary>
        public int? MaxTokens { get; set; }

        /// <summary>Initializes a new instance of the <see cref="AIModelOverride"/> class.</summary>
        public AIModelOverride() { }
    }
}
