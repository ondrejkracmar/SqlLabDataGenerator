using System;
using System.Data.Common;

namespace SqlLabDataGenerator
{
    /// <summary>
    /// Represents an active database connection.
    /// </summary>
    public class Connection
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
    }
}
