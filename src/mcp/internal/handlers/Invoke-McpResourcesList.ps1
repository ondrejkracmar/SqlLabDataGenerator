function Invoke-McpResourcesList {
	<#
	.SYNOPSIS
		Handles the resources/list MCP request.

	.DESCRIPTION
		Returns available read-only resources for inspecting module state.
	#>
	[CmdletBinding()]
	param (
		$Params
	)

	[ordered]@{
		resources = @(
			[ordered]@{
				uri         = 'sldg://health'
				name        = 'Health Status'
				description = 'Module version, providers, AI config, active connection'
				mimeType    = 'application/json'
			}
			[ordered]@{
				uri         = 'sldg://providers'
				name        = 'Database Providers'
				description = 'Registered database providers (SQL Server, SQLite, custom)'
				mimeType    = 'application/json'
			}
			[ordered]@{
				uri         = 'sldg://ai-config'
				name        = 'AI Configuration'
				description = 'Current AI provider settings and per-purpose model overrides'
				mimeType    = 'application/json'
			}
			[ordered]@{
				uri         = 'sldg://locales'
				name        = 'Registered Locales'
				description = 'Available locale data packs and their categories'
				mimeType    = 'application/json'
			}
			[ordered]@{
				uri         = 'sldg://schema'
				name        = 'Database Schema'
				description = 'Current database schema (requires active connection and prior Get-SldgDatabaseSchema call)'
				mimeType    = 'application/json'
			}
		)
	}
}
