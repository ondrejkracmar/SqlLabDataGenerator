using System;
using System.Collections.Concurrent;
using System.Threading;

namespace SqlLabDataGenerator
{
    /// <summary>
    /// Encapsulates all mutable state for a SqlLabDataGenerator session.
    /// Thread-safe: uses ConcurrentDictionary/ConcurrentQueue for all collections
    /// and explicit locking for compound operations.
    /// <para>
    /// Replaces the previous <c>$script:SldgState</c> synchronized hashtable
    /// with a strongly-typed object that supports multiple parallel sessions
    /// without cross-contamination.
    /// </para>
    /// </summary>
    public sealed class SldgSession : IDisposable
    {
        /// <summary>Unique identifier for this session.</summary>
        public Guid SessionId { get; }

        /// <summary>When the session was created.</summary>
        public DateTime CreatedAt { get; }

        // ── Connection ─────────────────────────────────────────────

        private Connection _activeConnection;
        private string _activeProvider;
        private readonly object _connectionLock = new();

        /// <summary>The currently active database connection, or null.</summary>
        public Connection ActiveConnection
        {
            get { lock (_connectionLock) return _activeConnection; }
            set { lock (_connectionLock) _activeConnection = value; }
        }

        /// <summary>The name of the active database provider, or null.</summary>
        public string ActiveProvider
        {
            get { lock (_connectionLock) return _activeProvider; }
            set { lock (_connectionLock) _activeProvider = value; }
        }

        // ── Providers & Transformers ───────────────────────────────

        /// <summary>Registered database providers keyed by name.</summary>
        public ConcurrentDictionary<string, object> Providers { get; } = new();

        /// <summary>Registered data transformers keyed by name.</summary>
        public ConcurrentDictionary<string, object> Transformers { get; } = new();

        // ── Generation State ───────────────────────────────────────

        /// <summary>Active generation plans keyed by database name.</summary>
        public ConcurrentDictionary<string, object> GenerationPlans { get; } = new();

        /// <summary>Results of last generation run keyed by database name.</summary>
        public ConcurrentDictionary<string, object> GeneratedData { get; } = new();

        // ── Locale Data ────────────────────────────────────────────

        /// <summary>Static locale packs keyed by locale name (e.g. 'en-US', 'cs-CZ').</summary>
        public ConcurrentDictionary<string, object> Locales { get; } = new();

        // ── AI Caches ──────────────────────────────────────────────

        /// <summary>AI-generated locale data cache.</summary>
        public ConcurrentDictionary<string, object> AILocaleCache { get; } = new();

        /// <summary>AI-generated locale category data cache.</summary>
        public ConcurrentDictionary<string, object> AILocaleCategoryCache { get; } = new();

        /// <summary>AI-generated column value cache.</summary>
        public ConcurrentDictionary<string, object> AIValueCache { get; } = new();

        /// <summary>Timestamps for cache entries (key = "CacheName|Key").</summary>
        public ConcurrentDictionary<string, DateTime> CacheTimestamps { get; } = new();

        // ── AI Rate Limiting ───────────────────────────────────────

        /// <summary>Timestamps of recent AI requests for rate limiting.</summary>
        public ConcurrentQueue<DateTime> AIRequestTimestamps { get; } = new();

        /// <summary>Lock object for atomic rate-limit check-wait-enqueue operations.</summary>
        public object AIRateLimitLock { get; } = new();

        // ── AI Model Overrides ─────────────────────────────────────

        /// <summary>Per-purpose AI model overrides keyed by purpose name.</summary>
        public ConcurrentDictionary<string, object> AIModelOverrides { get; } = new();

        // ── Lifecycle ──────────────────────────────────────────────

        /// <summary>Creates a new session with a unique identifier.</summary>
        public SldgSession()
        {
            SessionId = Guid.NewGuid();
            CreatedAt = DateTime.UtcNow;
        }

        /// <summary>
        /// Resets all caches without touching providers, locales, or the active connection.
        /// </summary>
        public void ClearCaches()
        {
            AIValueCache.Clear();
            AILocaleCache.Clear();
            AILocaleCategoryCache.Clear();
            CacheTimestamps.Clear();
        }

        /// <summary>
        /// Resets the entire session to a clean state: disconnects, clears providers,
        /// plans, caches, locales, and transformers.
        /// </summary>
        public void Reset()
        {
            lock (_connectionLock)
            {
                _activeConnection?.Dispose();
                _activeConnection = null;
                _activeProvider = null;
            }

            Providers.Clear();
            Transformers.Clear();
            GenerationPlans.Clear();
            GeneratedData.Clear();
            Locales.Clear();
            AIModelOverrides.Clear();
            ClearCaches();

            // Drain the rate-limit queue
            while (AIRequestTimestamps.TryDequeue(out _)) { }
        }

        private bool _disposed;

        /// <summary>Disposes the session, closing the active connection.</summary>
        public void Dispose()
        {
            if (_disposed) return;
            _disposed = true;

            lock (_connectionLock)
            {
                _activeConnection?.Dispose();
                _activeConnection = null;
            }

            GC.SuppressFinalize(this);
        }
    }
}
