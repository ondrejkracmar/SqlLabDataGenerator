using System.Collections;

namespace SqlLabDataGenerator
{
    /// <summary>
    /// Represents a scenario template for guided data generation.
    /// </summary>
    public class ScenarioTemplate
    {
        /// <summary>Template name (e.g., 'eCommerce', 'Healthcare').</summary>
        public string Name { get; set; }

        /// <summary>Human-readable description of the scenario.</summary>
        public string Description { get; set; }

        /// <summary>Table role patterns with row count multipliers.</summary>
        public Hashtable TableRoles { get; set; }

        /// <summary>Column pattern to value rules mapping.</summary>
        public Hashtable ValueRules { get; set; }

        /// <summary>Initializes a new instance of the <see cref="ScenarioTemplate"/> class.</summary>
        public ScenarioTemplate() { }
    }
}
