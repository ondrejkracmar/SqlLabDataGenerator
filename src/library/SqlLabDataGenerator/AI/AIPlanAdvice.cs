using System;
using System.Collections;

namespace SqlLabDataGenerator
{
    /// <summary>
    /// Represents AI-generated advice for a generation plan.
    /// </summary>
    public class AIPlanAdvice
    {
        /// <summary>Per-table advice (key = FullName, value = { RowCount, TableType, Notes }).</summary>
        public Hashtable Tables { get; set; }

        /// <summary>Custom generation rules suggested by AI.</summary>
        public Hashtable[] CustomRules { get; set; }

        /// <summary>Cross-table relationship rules.</summary>
        public Hashtable[] CrossTableRules { get; set; }

        /// <summary>Per-table generation notes produced by schema analysis (key = FullName, value = notes string).</summary>
        public Hashtable TableGenerationNotes { get; set; }

        /// <summary>The AI provider that generated this advice.</summary>
        public string Source { get; set; }

        /// <summary>When the advice was generated.</summary>
        public DateTime GeneratedAt { get; set; }

        /// <summary>Initializes a new instance of the <see cref="AIPlanAdvice"/> class.</summary>
        public AIPlanAdvice() { }
    }
}
