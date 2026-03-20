namespace SqlLabDataGenerator
{
    /// <summary>
    /// Represents a foreign key reference from a column to a referenced table/column.
    /// </summary>
    public class ForeignKeyRef
    {
        /// <summary>The name of the foreign key constraint.</summary>
        public string ForeignKeyName { get; set; }

        /// <summary>The schema of the referenced table.</summary>
        public string ReferencedSchema { get; set; }

        /// <summary>The name of the referenced table.</summary>
        public string ReferencedTable { get; set; }

        /// <summary>The name of the referenced column.</summary>
        public string ReferencedColumn { get; set; }

        /// <summary>Initializes a new instance of the <see cref="ForeignKeyRef"/> class.</summary>
        public ForeignKeyRef() { }
    }
}
