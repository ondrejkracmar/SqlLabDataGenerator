namespace SqlLabDataGenerator
{
    /// <summary>
    /// Represents the result of testing an AI provider connection.
    /// </summary>
    public class AIProviderTestResult
    {
        /// <summary>The AI provider name.</summary>
        public string Provider { get; set; }

        /// <summary>The model name.</summary>
        public string Model { get; set; }

        /// <summary>The API endpoint URL.</summary>
        public string Endpoint { get; set; }

        /// <summary>Connection status ('NotConfigured', 'Connected', 'NoResponse', 'Failed').</summary>
        public string Status { get; set; }

        /// <summary>Response time in milliseconds, or null.</summary>
        public int? ResponseMs { get; set; }

        /// <summary>Error message if the test failed.</summary>
        public string Error { get; set; }

        /// <summary>Initializes a new instance of the <see cref="AIProviderTestResult"/> class.</summary>
        public AIProviderTestResult() { }
    }
}
