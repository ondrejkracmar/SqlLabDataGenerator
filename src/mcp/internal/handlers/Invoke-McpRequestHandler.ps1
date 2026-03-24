function Invoke-McpRequestHandler {
	<#
	.SYNOPSIS
		Routes an MCP JSON-RPC request to the appropriate handler.

	.DESCRIPTION
		Central dispatcher that maps JSON-RPC method names to handler functions.
	#>
	[CmdletBinding()]
	param (
		[Parameter(Mandatory)]
		$Message
	)

	if (-not $Message.IsValid) {
		return New-McpError -Id $Message.Id -Code $Message.Code -Message $Message.Error
	}

	try {
		$result = switch ($Message.Method) {
			'initialize'     { Invoke-McpInitialize -Params $Message.Params }
			'ping'           { [ordered]@{} }
			'tools/list'     { Invoke-McpToolsList -Params $Message.Params }
			'tools/call'     { Invoke-McpToolsCall -Params $Message.Params }
			'resources/list' { Invoke-McpResourcesList -Params $Message.Params }
			'resources/read' { Invoke-McpResourcesRead -Params $Message.Params }
			default {
				return New-McpError -Id $Message.Id -Code -32601 -Message "Method not found: $($Message.Method)"
			}
		}

		New-McpResponse -Id $Message.Id -Result $result
	}
	catch {
		New-McpError -Id $Message.Id -Code -32603 -Message $_.Exception.Message
	}
}
