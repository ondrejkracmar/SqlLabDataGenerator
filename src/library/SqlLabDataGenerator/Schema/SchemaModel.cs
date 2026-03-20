using System;

namespace SqlLabDataGenerator
{
    /// <summary>
    /// Represents the complete schema model for a database.
    /// </summary>
    public class SchemaModel
    {
        /// <summary>The database name or path.</summary>
        public string Database { get; set; }

        /// <summary>All tables discovered in the schema.</summary>
        public TableInfo[] Tables { get; set; }

        /// <summary>Number of tables in the schema.</summary>
        public int TableCount { get; set; }

        /// <summary>When the schema was discovered.</summary>
        public DateTime DiscoveredAt { get; set; }

        /// <summary>Initializes a new instance of the <see cref="SchemaModel"/> class.</summary>
        public SchemaModel() { }
    }
}
