using System;
using System.Collections;

namespace SqlLabDataGenerator
{
    /// <summary>
    /// Represents a registered database provider (SQL Server, SQLite, etc.).
    /// </summary>
    public class SqlProvider
    {
        /// <summary>Provider name ('SQLite', 'SqlServer').</summary>
        public string Name { get; set; }

        /// <summary>Function map (keys: Connect, GetSchema, WriteData, ReadData, Disconnect, optional DeleteData).</summary>
        public Hashtable FunctionMap { get; set; }

        /// <summary>When the provider was registered.</summary>
        public DateTime Registered { get; set; }

        /// <summary>Initializes a new instance of the <see cref="SqlProvider"/> class.</summary>
        public SqlProvider() { }
    }
}
