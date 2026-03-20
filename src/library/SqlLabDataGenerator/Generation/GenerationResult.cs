using System;

namespace SqlLabDataGenerator
{
    /// <summary>
    /// Represents the overall result of a data generation run.
    /// </summary>
    public class GenerationResult
    {
        /// <summary>The database name or path.</summary>
        public string Database { get; set; }

        /// <summary>Generation mode.</summary>
        public string Mode { get; set; }

        /// <summary>Number of tables processed.</summary>
        public int TableCount { get; set; }

        /// <summary>Total rows generated.</summary>
        public int TotalRows { get; set; }

        /// <summary>Per-table results.</summary>
        public TableResult[] Tables { get; set; }

        /// <summary>Number of tables that succeeded.</summary>
        public int SuccessCount { get; set; }

        /// <summary>Number of tables that failed.</summary>
        public int FailureCount { get; set; }

        /// <summary>When generation started.</summary>
        public DateTime StartedAt { get; set; }

        /// <summary>When generation completed.</summary>
        public DateTime CompletedAt { get; set; }

        /// <summary>Total generation duration.</summary>
        public TimeSpan Duration { get; set; }

        /// <summary>The user who ran the generation.</summary>
        public string User { get; set; }

        /// <summary>Initializes a new instance of the <see cref="GenerationResult"/> class.</summary>
        public GenerationResult() { }
    }
}
