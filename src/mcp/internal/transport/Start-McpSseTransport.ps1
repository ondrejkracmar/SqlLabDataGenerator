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

		[string]$LogPath
	)

	$prefix = "http://localhost:$Port/"
	$listener = [System.Net.HttpListener]::new()
	$listener.Prefixes.Add($prefix)

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

			$path = $request.Url.AbsolutePath.TrimEnd('/')
			$method = $request.HttpMethod

			if ($method -eq 'GET' -and $path -eq '/sse') {
				# SSE connection — assign session ID
				$sessionId = [guid]::NewGuid().ToString('N')
				$queue = [System.Collections.Concurrent.BlockingCollection[string]]::new()
				$sessions[$sessionId] = $queue

				$response.ContentType = 'text/event-stream'
				$response.Headers.Add('Cache-Control', 'no-cache')
				$response.Headers.Add('Connection', 'keep-alive')
				$response.Headers.Add('Access-Control-Allow-Origin', '*')

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
					if ($queue) { $queue.Add($json) }
				}

				# HTTP response is 202 Accepted
				$response.StatusCode = 202
				$response.Close()
			}
			elseif ($method -eq 'OPTIONS') {
				# CORS preflight
				$response.Headers.Add('Access-Control-Allow-Origin', '*')
				$response.Headers.Add('Access-Control-Allow-Methods', 'GET, POST, OPTIONS')
				$response.Headers.Add('Access-Control-Allow-Headers', 'Content-Type')
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
		foreach ($queue in $sessions.Values) {
			$queue.CompleteAdding()
			$queue.Dispose()
		}
		$listener.Stop()
		$listener.Close()
		Write-Host 'MCP SSE server stopped.' -ForegroundColor Yellow
	}
}
