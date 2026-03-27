function Invoke-McpResourcesRead {
	<#
	.SYNOPSIS
		Handles the resources/read MCP request.

	.DESCRIPTION
		Reads the content of a specific resource by URI.
	#>
	[CmdletBinding()]
	param (
		[Parameter(Mandatory)]
		$Params
	)

	$uri = $Params.uri

	$data = switch ($uri) {
		'sldg://health' {
			Get-SldgHealth | ConvertTo-Json -Depth 5
		}
		'sldg://providers' {
			$providers = @{}
			foreach ($key in $script:SldgState.Providers.Keys) {
				$providers[$key] = @{
					Functions = @($script:SldgState.Providers[$key].FunctionMap.Keys)
				}
			}
			$providers | ConvertTo-Json -Depth 5
		}
		'sldg://ai-config' {
			$config = Get-SldgAIProvider
			$config | ConvertTo-Json -Depth 5
		}
		'sldg://locales' {
			$locales = @{}
			foreach ($key in $script:SldgState.Locales.Keys) {
				$locale = $script:SldgState.Locales[$key]
				$locales[$key] = @{
					Categories = @($locale.Keys)
				}
			}
			$locales | ConvertTo-Json -Depth 5
		}
		'sldg://schema' {
			if (-not $script:SldgState.ActiveConnection) {
				'{"error": "No active database connection. Call Connect-SldgDatabase first."}'
			}
			else {
				try {
					$schema = Get-SldgDatabaseSchema
					$schema | ConvertTo-Json -Depth 10
				}
				catch {
					[PSCustomObject]@{ error = $_.Exception.Message } | ConvertTo-Json -Compress
				}
			}
		}
		default {
			$null
		}
	}

	if ($null -eq $data) {
		return [ordered]@{
			contents = @([ordered]@{
				uri      = $uri
				mimeType = 'text/plain'
				text     = "Unknown resource: $uri"
			})
		}
	}

	[ordered]@{
		contents = @([ordered]@{
			uri      = $uri
			mimeType = 'application/json'
			text     = $data
		})
	}
}
