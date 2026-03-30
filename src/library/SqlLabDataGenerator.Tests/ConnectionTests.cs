using System;
using Xunit;

namespace SqlLabDataGenerator.Tests
{
    public class ConnectionTests
    {
        [Fact]
        public void NewConnection_IsNotValid_WhenEmpty()
        {
            var conn = new Connection();
            Assert.False(conn.IsValid);
        }

        [Fact]
        public void Connection_IsValid_WhenProperlyConfigured()
        {
            using var sqliteConn = new Microsoft.Data.Sqlite.SqliteConnection("Data Source=:memory:");
            var conn = new Connection
            {
                DbConnection = sqliteConn,
                ServerInstance = "localhost",
                Database = "test.db",
                Provider = "SQLite",
                ConnectedAt = DateTime.UtcNow
            };

            Assert.True(conn.IsValid);
        }

        [Fact]
        public void Connection_IsNotValid_WhenProviderMissing()
        {
            using var sqliteConn = new Microsoft.Data.Sqlite.SqliteConnection("Data Source=:memory:");
            var conn = new Connection
            {
                DbConnection = sqliteConn,
                Database = "test.db"
            };

            Assert.False(conn.IsValid);
        }

        [Fact]
        public void Connection_IsNotValid_WhenDatabaseMissing()
        {
            using var sqliteConn = new Microsoft.Data.Sqlite.SqliteConnection("Data Source=:memory:");
            var conn = new Connection
            {
                DbConnection = sqliteConn,
                Provider = "SQLite"
            };

            Assert.False(conn.IsValid);
        }

        [Fact]
        public void IsOpen_ReturnsFalse_WhenNotConnected()
        {
            using var sqliteConn = new Microsoft.Data.Sqlite.SqliteConnection("Data Source=:memory:");
            var conn = new Connection
            {
                DbConnection = sqliteConn,
                Provider = "SQLite",
                Database = "test.db"
            };

            Assert.False(conn.IsOpen);
        }

        [Fact]
        public void IsOpen_ReturnsTrue_WhenConnected()
        {
            using var sqliteConn = new Microsoft.Data.Sqlite.SqliteConnection("Data Source=:memory:");
            sqliteConn.Open();

            var conn = new Connection
            {
                DbConnection = sqliteConn,
                Provider = "SQLite",
                Database = ":memory:",
                ConnectedAt = DateTime.UtcNow
            };

            Assert.True(conn.IsOpen);
            conn.Dispose();
        }

        [Fact]
        public void Dispose_ClosesDbConnection()
        {
            var sqliteConn = new Microsoft.Data.Sqlite.SqliteConnection("Data Source=:memory:");
            sqliteConn.Open();

            var conn = new Connection
            {
                DbConnection = sqliteConn,
                Provider = "SQLite",
                Database = ":memory:"
            };

            conn.Dispose();

            Assert.False(conn.IsOpen);
        }

        [Fact]
        public void Dispose_IsIdempotent()
        {
            var sqliteConn = new Microsoft.Data.Sqlite.SqliteConnection("Data Source=:memory:");
            var conn = new Connection { DbConnection = sqliteConn };

            conn.Dispose();
            conn.Dispose(); // Should not throw
        }

        [Fact]
        public void Dispose_HandlesNullDbConnection()
        {
            var conn = new Connection();
            conn.Dispose(); // Should not throw
        }
    }
}
