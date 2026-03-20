using System;
using System.Collections;

namespace SqlLabDataGenerator
{
    /// <summary>
    /// Represents a registered database provider.
    /// </summary>
    public class Provider
    {
        /// <summary>Provider name ('SQLite', 'SqlServer').</summary>
        public string Name { get; set; }

        /// <summary>Function map (keys: Connect, GetSchema, WriteData, ReadData, Disconnect, optional DeleteData).</summary>
        public Hashtable FunctionMap { get; set; }

        /// <summary>When the provider was registered.</summary>
        public DateTime Registered { get; set; }

        /// <summary>Initializes a new instance of the <see cref="Provider"/> class.</summary>
        public Provider() { }
    }
}
