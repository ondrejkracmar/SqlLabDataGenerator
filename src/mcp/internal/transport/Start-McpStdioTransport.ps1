function Start-McpStdioTransport {
	<#
	.SYNOPSIS
		Runs the MCP server in stdio transport mode.

	.DESCRIPTION
		Reads JSON-RPC messages line-by-line from stdin, processes them,
		and writes responses to stdout. Continues until stdin is closed
		or a shutdown notification is received.
	#>
	[CmdletBinding()]
	param ()

	# Ensure stderr is used for logging, not stdout (MCP protocol uses stdout)
	$originalInfo = [Console]::Error

	while ($true) {
		$message = Read-McpMessage -Stdio
		if ($null -eq $message) { break }

		if (-not $message.IsValid) {
			$errorResponse = New-McpError -Id $message.Id -Code $message.Code -Message $message.Error
			Write-McpMessage -Message $errorResponse -Stdio
			continue
		}

		# Handle notifications (no id = no response expected)
		if ($null -eq $message.Id) {
			# Process notification silently
			switch ($message.Method) {
				'notifications/initialized' { <# Client acknowledged init #> }
				'notifications/cancelled'   { <# Client cancelled a request #> }
				default {
					[Console]::Error.WriteLine("MCP: Unknown notification: $($message.Method)")
				}
			}
			continue
		}

		$response = Invoke-McpRequestHandler -Message $message
		if ($null -ne $response) {
			Write-McpMessage -Message $response -Stdio
		}
	}
}
