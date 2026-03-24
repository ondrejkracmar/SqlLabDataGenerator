function ConvertTo-McpContent {
	<#
	.SYNOPSIS
		Converts PowerShell output objects to MCP tool result content blocks.

	.DESCRIPTION
		Takes one or more PowerShell objects and converts them to an array of MCP content blocks.
		Complex objects are serialized as JSON text; simple strings are returned as-is.
	#>
	[CmdletBinding()]
	param (
		[Parameter(ValueFromPipeline)]
		$InputObject,

		[switch]$IsError
	)

	begin { $collected = [System.Collections.Generic.List[object]]::new() }

	process {
		if ($null -ne $InputObject) {
			$collected.Add($InputObject)
		}
	}

	end {
		if ($collected.Count -eq 0) {
			Write-Output -NoEnumerate @(
				[ordered]@{ type = 'text'; text = 'Command completed successfully (no output).' }
			)
			return
		}

		$content = [System.Collections.Generic.List[object]]::new()

		foreach ($obj in $collected) {
			$text = if ($obj -is [string]) {
				$obj
			}
			elseif ($obj -is [System.ValueType]) {
				[string]$obj
			}
			else {
				$obj | ConvertTo-Json -Depth 10 -Compress
			}

			$content.Add([ordered]@{
				type = 'text'
				text = $text
			})
		}

		if ($IsError) {
			$content | ForEach-Object { $_['text'] = "ERROR: $($_['text'])" }
		}

		Write-Output -NoEnumerate @($content)
	}
}
