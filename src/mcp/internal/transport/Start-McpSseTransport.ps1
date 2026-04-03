function Start-McpSseTransport {
	<#
	.SYNOPSIS
		Starts the MCP server in SSE (Server-Sent Events) HTTP transport mode.

	.DESCRIPTION
		Runs an HTTP listener with two endpoints:
		- GET /sse — establishes SSE stream for server-to-client messages
		- POST /messages — receives client-to-server JSON-RPC messages

		Each SSE connection is a separate MCP session with isolated state.
	#>
	[CmdletBinding()]
	param (
		[int]$Port = 8080,

		[string]$LogPath,

		[string]$AuthToken,

		[int]$TokenExpirationMinutes = 0
	)

	$prefix = "http://localhost:$Port/"
	$listener = [System.Net.HttpListener]::new()
	$listener.Prefixes.Add($prefix)

	# Security limits — read from PSF config (set in configuration.ps1)
	$maxRequestBodyBytes = Get-PSFConfigValue -FullName 'SqlLabDataGenerator.MCP.SSE.MaxRequestBodyBytes'
	$rateLimitPerSession = Get-PSFConfigValue -FullName 'SqlLabDataGenerator.MCP.SSE.RateLimitPerSecond'
	$maxQueueDepth = Get-PSFConfigValue -FullName 'SqlLabDataGenerator.MCP.SSE.MaxQueueDepth'
	$sessionRateLimits = [System.Collections.Concurrent.ConcurrentDictionary[string, System.Collections.Generic.List[datetime]]]::new()

	# Token expiration tracking
	$tokenCreatedAt = [datetime]::UtcNow

	# Auth token validation helper
	$validateAuth = {
		param ($req, $resp)
		if (-not $AuthToken) { return $true }

		# Check token expiration
		if ($TokenExpirationMinutes -gt 0) {
			$elapsed = ([datetime]::UtcNow - $tokenCreatedAt).TotalMinutes
			if ($elapsed -gt $TokenExpirationMinutes) {
				$resp.StatusCode = 401
				$body = [System.Text.Encoding]::UTF8.GetBytes('{"error": "Token expired. Restart the server with a new token."}')
				$resp.OutputStream.Write($body, 0, $body.Length)
				$resp.Close()
				return $false
			}
		}

		$authHeader = $req.Headers['Authorization']
		if ($authHeader -and $authHeader -eq "Bearer $AuthToken") { return $true }
		$resp.StatusCode = 401
		$body = [System.Text.Encoding]::UTF8.GetBytes('{"error": "Unauthorized — provide Authorization: Bearer <token>"}')
		$resp.OutputStream.Write($body, 0, $body.Length)
		$resp.Close()
		return $false
	}

	try {
		$listener.Start()
		Write-Host "MCP SSE server listening on $prefix" -ForegroundColor Green
		Write-Host "  SSE endpoint:     GET  ${prefix}sse"
		Write-Host "  Message endpoint: POST ${prefix}messages"
		Write-Host 'Press Ctrl+C to stop.' -ForegroundColor DarkGray

		# Track active SSE sessions: sessionId → queue
		$sessions = [System.Collections.Concurrent.ConcurrentDictionary[string, System.Collections.Concurrent.BlockingCollection[string]]]::new()

		while ($listener.IsListening) {
			$contextTask = $listener.GetContextAsync()
			# Wait with cancellation support
			try { $context = $contextTask.GetAwaiter().GetResult() }
			catch [System.ObjectDisposedException] { break }

			$request = $context.Request
			$response = $context.Response

			# Validate auth token on all requests (except OPTIONS for CORS preflight)
			$path = $request.Url.AbsolutePath.TrimEnd('/')
			$method = $request.HttpMethod

			if ($method -ne 'OPTIONS' -and -not (& $validateAuth $request $response)) { continue }

			if ($method -eq 'GET' -and $path -eq '/sse') {
				# SSE connection — assign session ID
				$sessionId = [guid]::NewGuid().ToString('N')
				$queue = [System.Collections.Concurrent.BlockingCollection[string]]::new()
				$sessions[$sessionId] = $queue

				# Restrict CORS to localhost/loopback origins only
				$origin = $request.Headers['Origin']
				$isAllowed = $false
				if ($origin) {
					try {
						$originUri = [System.Uri]::new($origin)
						$isAllowed = $originUri.Host -in @('localhost', '127.0.0.1', '[::1]') -and $originUri.Scheme -in @('http', 'https')
					} catch { $isAllowed = $false }
				}
				$allowedOrigin = if ($isAllowed) { $origin } else { "http://localhost:$Port" }

				$response.ContentType = 'text/event-stream'
				$response.Headers.Add('Cache-Control', 'no-cache')
				$response.Headers.Add('Connection', 'keep-alive')
				$response.Headers.Add('Access-Control-Allow-Origin', $allowedOrigin)

				$writer = [System.IO.StreamWriter]::new($response.OutputStream, [System.Text.Encoding]::UTF8)
				$writer.AutoFlush = $true

				# Send the endpoint event — tells the client where to POST messages
				$messageUri = "${prefix}messages?sessionId=$sessionId"
				$writer.WriteLine("event: endpoint")
				$writer.WriteLine("data: $messageUri")
				$writer.WriteLine()

				# Background job to drain queue → SSE stream
				$null = [System.Threading.Tasks.Task]::Run([Action]{
					try {
						foreach ($msg in $queue.GetConsumingEnumerable()) {
							$writer.WriteLine("event: message")
							$writer.WriteLine("data: $msg")
							$writer.WriteLine()
						}
					}
					catch { }
					finally {
						$writer.Dispose()
						$response.Close()
						$sessions.TryRemove($sessionId, [ref]$null)
						$sessionRateLimits.TryRemove($sessionId, [ref]$null)
					}
				}.GetNewClosure())
			}
			elseif ($method -eq 'POST' -and $path -eq '/messages') {
				$sessionId = $request.QueryString['sessionId']

				if (-not $sessionId -or -not $sessions.ContainsKey($sessionId)) {
					$response.StatusCode = 400
					$body = [System.Text.Encoding]::UTF8.GetBytes('{"error": "Invalid or missing sessionId"}')
					$response.OutputStream.Write($body, 0, $body.Length)
					$response.Close()
					continue
				}

				# Enforce request body size limit
				if ($request.ContentLength64 -gt $maxRequestBodyBytes) {
					$response.StatusCode = 413
					$body = [System.Text.Encoding]::UTF8.GetBytes('{"error": "Request body too large"}')
					$response.OutputStream.Write($body, 0, $body.Length)
					$response.Close()
					continue
				}

				# Per-session rate limiting
				$now = [datetime]::UtcNow
				$timestamps = $sessionRateLimits.GetOrAdd($sessionId, { [System.Collections.Generic.List[datetime]]::new() })
				$windowStart = $now.AddSeconds(-1)
				$expired = @($timestamps | Where-Object { $_ -lt $windowStart })
				foreach ($ts in $expired) { [void]$timestamps.Remove($ts) }
				if ($timestamps.Count -ge $rateLimitPerSession) {
					$response.StatusCode = 429
					$body = [System.Text.Encoding]::UTF8.GetBytes('{"error": "Too many requests"}')
					$response.OutputStream.Write($body, 0, $body.Length)
					$response.Close()
					continue
				}
				$timestamps.Add($now)

				# Periodic cleanup: remove rate limit entries for disconnected sessions
				if ($sessionRateLimits.Count -gt $sessions.Count + 10) {
					$staleSessionIds = @($sessionRateLimits.Keys | Where-Object { -not $sessions.ContainsKey($_) })
					foreach ($staleId in $staleSessionIds) {
						$sessionRateLimits.TryRemove($staleId, [ref]$null)
					}
				}

				# Read request body
				$reader = [System.IO.StreamReader]::new($request.InputStream, $request.ContentEncoding)
				$requestBody = $reader.ReadToEnd()
				$reader.Dispose()

				# Process the JSON-RPC message
				$mcpMessage = Read-McpMessage -Body $requestBody
				$responseMessage = Invoke-McpRequestHandler -Message $mcpMessage

				# If it's a notification (no id), we don't send a response via SSE
				if ($null -ne $responseMessage) {
					$json = $responseMessage | ConvertTo-Json -Depth 20 -Compress
					$queue = $sessions[$sessionId]
					if ($queue) {
						# Enforce max queue depth to prevent unbounded memory growth
						if ($queue.Count -ge $maxQueueDepth) {
							Write-Warning "SSE queue for session $sessionId exceeded $maxQueueDepth messages. Dropping oldest."
							$null = $queue.TryTake([ref]$null, 0)
						}
						$queue.Add($json)
					}
				}

				# HTTP response is 202 Accepted
				$response.StatusCode = 202
				$response.Close()
			}
			elseif ($method -eq 'OPTIONS') {
				# CORS preflight — restrict to localhost/loopback origins (consistent with GET /sse handler)
				$origin = $request.Headers['Origin']
				$isAllowedOrigin = $false
				if ($origin) {
					try {
						$originUri = [System.Uri]::new($origin)
						$isAllowedOrigin = $originUri.Host -in @('localhost', '127.0.0.1', '[::1]') -and $originUri.Scheme -in @('http', 'https')
					} catch { $isAllowedOrigin = $false }
				}
				$allowedOrigin = if ($isAllowedOrigin) { $origin } else { "http://localhost:$Port" }
				$response.Headers.Add('Access-Control-Allow-Origin', $allowedOrigin)
				$response.Headers.Add('Access-Control-Allow-Methods', 'GET, POST, OPTIONS')
				$response.Headers.Add('Access-Control-Allow-Headers', 'Content-Type, Authorization')
				$response.StatusCode = 204
				$response.Close()
			}
			else {
				$response.StatusCode = 404
				$body = [System.Text.Encoding]::UTF8.GetBytes('{"error": "Not found"}')
				$response.OutputStream.Write($body, 0, $body.Length)
				$response.Close()
			}
		}
	}
	finally {
		# Cleanup
		$sessionRateLimits.Clear()
		foreach ($queue in $sessions.Values) {
			$queue.CompleteAdding()
			$queue.Dispose()
		}
		$listener.Stop()
		$listener.Close()
		Write-Host 'MCP SSE server stopped.' -ForegroundColor Yellow
	}
}
