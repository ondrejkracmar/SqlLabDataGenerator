namespace SqlLabDataGenerator
{
    /// <summary>
    /// Represents a foreign key relationship between tables.
    /// </summary>
    public class ForeignKeyInfo
    {
        /// <summary>The name of the foreign key constraint.</summary>
        public string ForeignKeyName { get; set; }

        /// <summary>The schema of the parent (referencing) table.</summary>
        public string ParentSchema { get; set; }

        /// <summary>The name of the parent (referencing) table.</summary>
        public string ParentTable { get; set; }

        /// <summary>The name of the parent (referencing) column.</summary>
        public string ParentColumn { get; set; }

        /// <summary>The schema of the referenced table.</summary>
        public string ReferencedSchema { get; set; }

        /// <summary>The name of the referenced table.</summary>
        public string ReferencedTable { get; set; }

        /// <summary>The name of the referenced column.</summary>
        public string ReferencedColumn { get; set; }

        /// <summary>Initializes a new instance of the <see cref="ForeignKeyInfo"/> class.</summary>
        public ForeignKeyInfo() { }
    }
}
