namespace SqlLabDataGenerator
{
    /// <summary>
    /// Represents table metadata discovered from a database schema.
    /// </summary>
    public class TableInfo
    {
        /// <summary>The schema name (e.g., 'dbo').</summary>
        public string SchemaName { get; set; }

        /// <summary>The table name.</summary>
        public string TableName { get; set; }

        /// <summary>Fully qualified name in 'schema.table' format.</summary>
        public string FullName { get; set; }

        /// <summary>Column metadata for all columns in the table.</summary>
        public ColumnInfo[] Columns { get; set; }

        /// <summary>Foreign key relationships defined on this table.</summary>
        public ForeignKeyInfo[] ForeignKeys { get; set; }

        /// <summary>Number of columns in the table.</summary>
        public int ColumnCount { get; set; }

        /// <summary>Initializes a new instance of the <see cref="TableInfo"/> class.</summary>
        public TableInfo() { }
    }
}
