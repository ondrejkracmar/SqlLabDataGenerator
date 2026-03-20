using System;
using System.Collections;

namespace SqlLabDataGenerator
{
    /// <summary>
    /// Represents the overall data generation plan for a database.
    /// </summary>
    public class GenerationPlan
    {
        /// <summary>The database name or path.</summary>
        public string Database { get; set; }

        /// <summary>Generation mode ('Synthetic', 'Masking', 'Scenario').</summary>
        public string Mode { get; set; }

        /// <summary>Table generation plans in insertion order.</summary>
        public TablePlan[] Tables { get; set; }

        /// <summary>Number of tables in the plan.</summary>
        public int TableCount { get; set; }

        /// <summary>Total rows to generate across all tables.</summary>
        public int TotalRows { get; set; }

        /// <summary>Mapping of semantic type to generator function.</summary>
        public Hashtable GeneratorMap { get; set; }

        /// <summary>When the plan was created.</summary>
        public DateTime CreatedAt { get; set; }

        /// <summary>Custom generation rules per table/column.</summary>
        public Hashtable GenerationRules { get; set; }

        /// <summary>AI-generated plan advice, if available.</summary>
        public AIPlanAdvice AIAdvice { get; set; }

        /// <summary>Initializes a new instance of the <see cref="GenerationPlan"/> class.</summary>
        public GenerationPlan() { }
    }
}
