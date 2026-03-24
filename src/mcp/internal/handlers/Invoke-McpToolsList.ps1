function Invoke-McpToolsList {
	<#
	.SYNOPSIS
		Handles the tools/list MCP request.

	.DESCRIPTION
		Returns all registered MCP tools with their JSON Schema input definitions.
	#>
	[CmdletBinding()]
	param (
		$Params
	)

	[ordered]@{
		tools = @($script:McpTools)
	}
}
