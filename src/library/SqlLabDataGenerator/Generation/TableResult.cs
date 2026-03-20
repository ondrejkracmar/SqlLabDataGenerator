using System.Data;

namespace SqlLabDataGenerator
{
    /// <summary>
    /// Represents the result of data generation for a single table.
    /// </summary>
    public class TableResult
    {
        /// <summary>Fully qualified table name.</summary>
        public string TableName { get; set; }

        /// <summary>Number of rows generated or inserted.</summary>
        public int RowCount { get; set; }

        /// <summary>Whether generation succeeded.</summary>
        public bool Success { get; set; }

        /// <summary>Error message if generation failed.</summary>
        public string Error { get; set; }

        /// <summary>Generated data table (when PassThru is used, single chunk).</summary>
        public DataTable DataTable { get; set; }

        /// <summary>Generated data tables (when PassThru is used, streaming).</summary>
        public DataTable[] DataTables { get; set; }

        /// <summary>Whether the transaction was rolled back.</summary>
        public bool RolledBack { get; set; }

        /// <summary>Initializes a new instance of the <see cref="TableResult"/> class.</summary>
        public TableResult() { }
    }
}
