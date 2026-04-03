using System;
using System.Collections;
using System.Data;

namespace SqlLabDataGenerator
{
    /// <summary>
    /// Represents a set of generated rows for a table.
    /// </summary>
    public sealed class RowSet : IDisposable
    {
        /// <summary>The table info for which rows were generated.</summary>
        public object TableInfo { get; set; }

        /// <summary>The generated data table.</summary>
        public DataTable DataTable { get; set; }

        /// <summary>Number of rows generated.</summary>
        public int RowCount { get; set; }

        /// <summary>Generated PK/Unique values for cross-table reference (key = "schema.table.column").</summary>
        public Hashtable GeneratedValues { get; set; }

        /// <summary>Initializes a new instance of the <see cref="RowSet"/> class.</summary>
        public RowSet() { }

        /// <summary>Disposes the contained DataTable.</summary>
        public void Dispose()
        {
            DataTable?.Dispose();
            DataTable = null;
            GC.SuppressFinalize(this);
        }
    }
}
