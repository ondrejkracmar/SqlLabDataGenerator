namespace SqlLabDataGenerator
{
    /// <summary>
    /// Represents column metadata discovered from a database schema.
    /// </summary>
    public class ColumnInfo
    {
        /// <summary>The name of the column.</summary>
        public string ColumnName { get; set; }

        /// <summary>The SQL data type.</summary>
        public string DataType { get; set; }

        /// <summary>Maximum character length, if applicable.</summary>
        public int? MaxLength { get; set; }

        /// <summary>Numeric precision (SQL Server).</summary>
        public int? NumericPrecision { get; set; }

        /// <summary>Numeric scale (SQL Server).</summary>
        public int? NumericScale { get; set; }

        /// <summary>Ordinal position in the table (SQL Server).</summary>
        public int? OrdinalPosition { get; set; }

        /// <summary>Whether the column allows NULL values.</summary>
        public bool IsNullable { get; set; }

        /// <summary>Whether the column is part of the primary key.</summary>
        public bool IsPrimaryKey { get; set; }

        /// <summary>Whether the column is an identity (auto-increment) column.</summary>
        public bool IsIdentity { get; set; }

        /// <summary>Whether the column is computed.</summary>
        public bool IsComputed { get; set; }

        /// <summary>Whether the column has a unique constraint.</summary>
        public bool IsUnique { get; set; }

        /// <summary>The default value expression, if any.</summary>
        public string DefaultValue { get; set; }

        /// <summary>Foreign key reference, if this column references another table.</summary>
        public ForeignKeyRef ForeignKey { get; set; }

        /// <summary>Check constraints defined on this column.</summary>
        public string[] CheckConstraints { get; set; }

        /// <summary>Hint derived from view definitions (e.g., JSON/XML format).</summary>
        public string SchemaHint { get; set; }

        /// <summary>Detected format from view definition ('Json', 'Xml', or null).</summary>
        public string ViewDetectedFormat { get; set; }

        /// <summary>Resolved semantic type (e.g., 'person-first-name').</summary>
        public string SemanticType { get; set; }

        /// <summary>Column classification result.</summary>
        public ColumnClassification Classification { get; set; }

        /// <summary>Custom generation rule, if set.</summary>
        public object GenerationRule { get; set; }

        /// <summary>Initializes a new instance of the <see cref="ColumnInfo"/> class.</summary>
        public ColumnInfo() { }
    }
}
