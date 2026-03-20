namespace SqlLabDataGenerator
{
    /// <summary>
    /// Represents the classification of a database column by semantic analysis.
    /// </summary>
    public class ColumnClassification
    {
        /// <summary>The column name.</summary>
        public string ColumnName { get; set; }

        /// <summary>The fully qualified table name.</summary>
        public string TableName { get; set; }

        /// <summary>The resolved semantic type (e.g., 'person-first-name').</summary>
        public string SemanticType { get; set; }

        /// <summary>Whether the column contains personally identifiable information.</summary>
        public bool IsPII { get; set; }

        /// <summary>Confidence score (0.0 to 1.0).</summary>
        public double Confidence { get; set; }

        /// <summary>Classification source ('Pattern', 'AI', 'Cached').</summary>
        public string Source { get; set; }

        /// <summary>The rule or hint that matched.</summary>
        public string MatchedRule { get; set; }

        /// <summary>Example values suggested by AI.</summary>
        public string[] ValueExamples { get; set; }

        /// <summary>Value pattern suggested by AI (e.g., regex).</summary>
        public string ValuePattern { get; set; }

        /// <summary>Cross-column dependency hint from AI.</summary>
        public string CrossColumnDependency { get; set; }

        /// <summary>Initializes a new instance of the <see cref="ColumnClassification"/> class.</summary>
        public ColumnClassification() { }
    }
}
