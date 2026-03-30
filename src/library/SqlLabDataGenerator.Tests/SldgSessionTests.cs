using System;
using Xunit;

namespace SqlLabDataGenerator.Tests
{
    public class SldgSessionTests
    {
        [Fact]
        public void NewSession_HasUniqueId()
        {
            using var session1 = new SldgSession();
            using var session2 = new SldgSession();

            Assert.NotEqual(Guid.Empty, session1.SessionId);
            Assert.NotEqual(session1.SessionId, session2.SessionId);
        }

        [Fact]
        public void NewSession_HasCreatedAtTimestamp()
        {
            var before = DateTime.UtcNow;
            using var session = new SldgSession();
            var after = DateTime.UtcNow;

            Assert.InRange(session.CreatedAt, before, after);
        }

        [Fact]
        public void NewSession_CollectionsAreEmpty()
        {
            using var session = new SldgSession();

            Assert.Empty(session.Providers);
            Assert.Empty(session.Transformers);
            Assert.Empty(session.GenerationPlans);
            Assert.Empty(session.GeneratedData);
            Assert.Empty(session.Locales);
            Assert.Empty(session.AIValueCache);
            Assert.Empty(session.AILocaleCache);
            Assert.Empty(session.AILocaleCategoryCache);
            Assert.Empty(session.CacheTimestamps);
            Assert.Empty(session.AIModelOverrides);
            Assert.Null(session.ActiveConnection);
            Assert.Null(session.ActiveProvider);
        }

        [Fact]
        public void ClearCaches_ClearsOnlyAICaches()
        {
            using var session = new SldgSession();
            session.AIValueCache.TryAdd("key1", "value1");
            session.AILocaleCache.TryAdd("key2", "value2");
            session.AILocaleCategoryCache.TryAdd("key3", "value3");
            session.CacheTimestamps.TryAdd("key4", DateTime.UtcNow);
            session.Providers.TryAdd("provider1", "value");
            session.Locales.TryAdd("en-US", "value");

            session.ClearCaches();

            Assert.Empty(session.AIValueCache);
            Assert.Empty(session.AILocaleCache);
            Assert.Empty(session.AILocaleCategoryCache);
            Assert.Empty(session.CacheTimestamps);
            // Non-cache collections should remain
            Assert.Single(session.Providers);
            Assert.Single(session.Locales);
        }

        [Fact]
        public void Reset_ClearsEverything()
        {
            using var session = new SldgSession();
            session.Providers.TryAdd("SqlServer", "value");
            session.Transformers.TryAdd("EntraId", "value");
            session.GenerationPlans.TryAdd("db1", "value");
            session.GeneratedData.TryAdd("db1", "value");
            session.Locales.TryAdd("en-US", "value");
            session.AIModelOverrides.TryAdd("batch-generation", "value");
            session.AIValueCache.TryAdd("cache1", "value");
            session.AIRequestTimestamps.Enqueue(DateTime.UtcNow);

            session.Reset();

            Assert.Empty(session.Providers);
            Assert.Empty(session.Transformers);
            Assert.Empty(session.GenerationPlans);
            Assert.Empty(session.GeneratedData);
            Assert.Empty(session.Locales);
            Assert.Empty(session.AIModelOverrides);
            Assert.Empty(session.AIValueCache);
            Assert.Empty(session.AIRequestTimestamps);
            Assert.Null(session.ActiveConnection);
            Assert.Null(session.ActiveProvider);
        }

        [Fact]
        public async System.Threading.Tasks.Task ActiveConnection_IsThreadSafe()
        {
            using var session = new SldgSession();
            var connection = new Connection
            {
                ServerInstance = "localhost",
                Database = "TestDb",
                Provider = "SqlServer",
                ConnectedAt = DateTime.UtcNow
            };

            // Set and get from different threads should not throw
            var tasks = new System.Threading.Tasks.Task[10];
            for (int i = 0; i < tasks.Length; i++)
            {
                var idx = i;
                tasks[i] = System.Threading.Tasks.Task.Run(() =>
                {
                    if (idx % 2 == 0)
                        session.ActiveConnection = connection;
                    else
                        _ = session.ActiveConnection;
                });
            }

            await System.Threading.Tasks.Task.WhenAll(tasks);
            // No deadlock or exception means thread-safe access works
        }

        [Fact]
        public void Dispose_CleansUpConnection()
        {
            var session = new SldgSession();
            var connection = new Connection
            {
                ServerInstance = "localhost",
                Database = "TestDb",
                Provider = "SqlServer",
                ConnectedAt = DateTime.UtcNow
            };
            session.ActiveConnection = connection;

            session.Dispose();

            Assert.Null(session.ActiveConnection);
        }

        [Fact]
        public void Dispose_IsIdempotent()
        {
            var session = new SldgSession();

            // Should not throw on multiple dispose calls
            session.Dispose();
            session.Dispose();
        }

        [Fact]
        public void AIRateLimitQueue_SupportsEnqueueDequeue()
        {
            using var session = new SldgSession();
            var now = DateTime.UtcNow;

            session.AIRequestTimestamps.Enqueue(now);
            session.AIRequestTimestamps.Enqueue(now.AddSeconds(1));

            Assert.Equal(2, session.AIRequestTimestamps.Count);

            Assert.True(session.AIRequestTimestamps.TryDequeue(out var first));
            Assert.Equal(now, first);
        }

        [Fact]
        public async System.Threading.Tasks.Task ConcurrentDictionaries_SupportParallelAccess()
        {
            using var session = new SldgSession();
            var tasks = new System.Threading.Tasks.Task[100];

            for (int i = 0; i < tasks.Length; i++)
            {
                var idx = i;
                tasks[i] = System.Threading.Tasks.Task.Run(() =>
                {
                    session.AIValueCache.TryAdd($"key_{idx}", $"value_{idx}");
                    session.CacheTimestamps.TryAdd($"ts_{idx}", DateTime.UtcNow);
                });
            }

            await System.Threading.Tasks.Task.WhenAll(tasks);

            Assert.Equal(100, session.AIValueCache.Count);
            Assert.Equal(100, session.CacheTimestamps.Count);
        }
    }
}
