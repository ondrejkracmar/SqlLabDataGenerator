using System;
using System.Data.Common;

namespace SqlLabDataGenerator
{
    /// <summary>
    /// Represents an active database connection.
    /// </summary>
    public class Connection : IDisposable
    {
        /// <summary>The underlying database connection object.</summary>
        public DbConnection DbConnection { get; set; }

        /// <summary>The server instance (hostname or 'localhost' for SQLite).</summary>
        public string ServerInstance { get; set; }

        /// <summary>The database name or file path.</summary>
        public string Database { get; set; }

        /// <summary>The database provider ('SQLite' or 'SqlServer').</summary>
        public string Provider { get; set; }

        /// <summary>When the connection was established.</summary>
        public DateTime ConnectedAt { get; set; }

        /// <summary>Initializes a new instance of the <see cref="Connection"/> class.</summary>
        public Connection() { }

        /// <summary>
        /// Validates that the connection has the minimum required state.
        /// Returns true if DbConnection and Provider are set.
        /// </summary>
        public bool IsValid =>
            DbConnection != null &&
            !string.IsNullOrWhiteSpace(Provider) &&
            !string.IsNullOrWhiteSpace(Database);

        /// <summary>Whether the underlying connection is currently open.</summary>
        public bool IsOpen =>
            DbConnection != null &&
            !_disposed &&
            DbConnection.State == System.Data.ConnectionState.Open;

        private bool _disposed;

        /// <summary>Disposes the underlying database connection.</summary>
        public void Dispose()
        {
            Dispose(true);
            GC.SuppressFinalize(this);
        }

        /// <summary>Releases resources used by the connection.</summary>
        protected virtual void Dispose(bool disposing)
        {
            if (_disposed) return;
            if (disposing)
            {
                DbConnection?.Dispose();
            }
            _disposed = true;
        }
    }
}
