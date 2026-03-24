using System;
using System.Collections;

namespace SqlLabDataGenerator
{
    /// <summary>
    /// Represents the generation plan for a single column.
    /// </summary>
    public class ColumnPlan
    {
        /// <summary>The column name.</summary>
        public string ColumnName { get; set; }

        /// <summary>The SQL data type.</summary>
        public string DataType { get; set; }

        /// <summary>The resolved semantic type.</summary>
        public string SemanticType { get; set; }

        /// <summary>The generator function name, or 'Fallback'.</summary>
        public string Generator { get; set; }

        /// <summary>Whether the column contains personally identifiable information.</summary>
        public bool IsPII { get; set; }

        /// <summary>Whether the column is part of the primary key.</summary>
        public bool IsPrimaryKey { get; set; }

        /// <summary>Whether the column has a unique constraint.</summary>
        public bool IsUnique { get; set; }

        /// <summary>Whether the column allows NULL values.</summary>
        public bool IsNullable { get; set; }

        /// <summary>Maximum character length, if applicable.</summary>
        public int? MaxLength { get; set; }

        /// <summary>Foreign key reference, if any.</summary>
        public ForeignKeyRef ForeignKey { get; set; }

        /// <summary>Schema hint for generation.</summary>
        public string SchemaHint { get; set; }

        /// <summary>Whether to skip generation (identity/computed/timestamp).</summary>
        public bool Skip { get; set; }

        /// <summary>Whether this is an identity (auto-increment) column.</summary>
        public bool IsIdentity { get; set; }

        /// <summary>Whether this is a computed column.</summary>
        public bool IsComputed { get; set; }

        /// <summary>Custom generation rule, if set.</summary>
        public object CustomRule { get; set; }

        /// <summary>Initializes a new instance of the <see cref="ColumnPlan"/> class.</summary>
        public ColumnPlan() { }
    }
}
