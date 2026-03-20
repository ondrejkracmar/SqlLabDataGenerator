namespace SqlLabDataGenerator
{
    /// <summary>
    /// Represents the result of a data validation check.
    /// </summary>
    public class ValidationResult
    {
        /// <summary>Type of validation check ('NotNull', 'RowCount', 'ForeignKey', 'PrimaryKey', 'UniqueConstraint').</summary>
        public string CheckType { get; set; }

        /// <summary>Fully qualified table name.</summary>
        public string TableName { get; set; }

        /// <summary>Constraint or check name.</summary>
        public string ConstraintName { get; set; }

        /// <summary>Column name, or null for table-level checks.</summary>
        public string Column { get; set; }

        /// <summary>Referenced table for FK checks.</summary>
        public string ReferencedTable { get; set; }

        /// <summary>Referenced column for FK checks.</summary>
        public string ReferencedColumn { get; set; }

        /// <summary>Whether the check passed.</summary>
        public bool Passed { get; set; }

        /// <summary>Severity level ('OK', 'Error', 'Warning').</summary>
        public string Severity { get; set; }

        /// <summary>Human-readable details about the check result.</summary>
        public string Details { get; set; }

        /// <summary>Initializes a new instance of the <see cref="ValidationResult"/> class.</summary>
        public ValidationResult() { }
    }
}
