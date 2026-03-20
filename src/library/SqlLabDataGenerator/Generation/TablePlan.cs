namespace SqlLabDataGenerator
{
    /// <summary>
    /// Represents the generation plan for a single table.
    /// </summary>
    public class TablePlan
    {
        /// <summary>Topological insertion order.</summary>
        public int Order { get; set; }

        /// <summary>The schema name.</summary>
        public string SchemaName { get; set; }

        /// <summary>The table name.</summary>
        public string TableName { get; set; }

        /// <summary>Fully qualified name in 'schema.table' format.</summary>
        public string FullName { get; set; }

        /// <summary>Number of rows to generate.</summary>
        public int RowCount { get; set; }

        /// <summary>Column generation plans.</summary>
        public ColumnPlan[] Columns { get; set; }

        /// <summary>Foreign key definitions from the schema.</summary>
        public object[] ForeignKeys { get; set; }

        /// <summary>Number of columns.</summary>
        public int ColumnCount { get; set; }

        /// <summary>Whether the table has circular FK dependencies.</summary>
        public bool HasCircularDependency { get; set; }

        /// <summary>Initializes a new instance of the <see cref="TablePlan"/> class.</summary>
        public TablePlan() { }
    }
}
