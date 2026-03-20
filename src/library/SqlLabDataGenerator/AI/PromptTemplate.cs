namespace SqlLabDataGenerator
{
    /// <summary>
    /// Represents a prompt template for AI operations.
    /// </summary>
    public class PromptTemplate
    {
        /// <summary>The prompt purpose identifier.</summary>
        public string Purpose { get; set; }

        /// <summary>Provider-specific variant name.</summary>
        public string Variant { get; set; }

        /// <summary>Description from YAML front matter.</summary>
        public string Description { get; set; }

        /// <summary>Version from YAML front matter.</summary>
        public string Version { get; set; }

        /// <summary>Full path to the .prompt file.</summary>
        public string Path { get; set; }

        /// <summary>Whether this is a custom (user-overridden) template.</summary>
        public bool IsCustom { get; set; }

        /// <summary>Placeholder names extracted from {{}} tokens.</summary>
        public string[] Placeholders { get; set; }

        /// <summary>Template content (only populated with -IncludeContent).</summary>
        public string Content { get; set; }

        /// <summary>Initializes a new instance of the <see cref="PromptTemplate"/> class.</summary>
        public PromptTemplate() { }
    }
}
