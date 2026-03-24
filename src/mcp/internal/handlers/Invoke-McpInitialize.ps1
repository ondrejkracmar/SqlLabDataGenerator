function Invoke-McpInitialize {
	<#
	.SYNOPSIS
		Handles the MCP initialize request.

	.DESCRIPTION
		Returns server capabilities and info per MCP protocol specification.
	#>
	[CmdletBinding()]
	param (
		[Parameter(Mandatory)]
		$Params
	)

	$moduleInfo = Import-PowerShellDataFile -Path "$script:McpModuleRoot\SqlLabDataGenerator.psd1"

	[ordered]@{
		protocolVersion = '2024-11-05'
		capabilities    = [ordered]@{
			tools     = [ordered]@{
				listChanged = $false
			}
			resources = [ordered]@{
				subscribe   = $false
				listChanged = $false
			}
		}
		serverInfo      = [ordered]@{
			name    = 'SqlLabDataGenerator'
			version = $moduleInfo.ModuleVersion
		}
	}
}
