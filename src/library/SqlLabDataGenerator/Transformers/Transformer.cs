namespace SqlLabDataGenerator
{
    /// <summary>
    /// Represents a registered data transformer.
    /// </summary>
    public class Transformer
    {
        /// <summary>Transformer name.</summary>
        public string Name { get; set; }

        /// <summary>Human-readable description.</summary>
        public string Description { get; set; }

        /// <summary>Name of the PowerShell function to invoke.</summary>
        public string TransformFunction { get; set; }

        /// <summary>Semantic types required by this transformer.</summary>
        public string[] RequiredSemanticTypes { get; set; }

        /// <summary>PSTypeName of the output objects.</summary>
        public string OutputType { get; set; }

        /// <summary>Initializes a new instance of the <see cref="Transformer"/> class.</summary>
        public Transformer() { }
    }
}
