function Write-McpMessage {
	<#
	.SYNOPSIS
		Writes a JSON-RPC 2.0 message to the output stream.

	.DESCRIPTION
		Serializes a JSON-RPC response or notification and writes it to stdout (stdio mode)
		or returns the JSON string (SSE mode).
	#>
	[CmdletBinding()]
	param (
		[Parameter(Mandatory)]
		$Message,

		[switch]$Stdio
	)

	$json = $Message | ConvertTo-Json -Depth 20 -Compress

	if ($Stdio) {
		[Console]::Out.WriteLine($json)
		[Console]::Out.Flush()
	}
	else {
		$json
	}
}

function New-McpResponse {
	<#
	.SYNOPSIS
		Creates a JSON-RPC 2.0 success response.
	#>
	[CmdletBinding()]
	param (
		$Id,

		[Parameter(Mandatory)]
		$Result
	)

	[ordered]@{
		jsonrpc = '2.0'
		id      = $Id
		result  = $Result
	}
}

function New-McpError {
	<#
	.SYNOPSIS
		Creates a JSON-RPC 2.0 error response.
	#>
	[CmdletBinding()]
	param (
		$Id,

		[Parameter(Mandatory)]
		[int]$Code,

		[Parameter(Mandatory)]
		[string]$Message,

		$Data
	)

	$error_obj = [ordered]@{
		code    = $Code
		message = $Message
	}
	if ($null -ne $Data) { $error_obj['data'] = $Data }

	[ordered]@{
		jsonrpc = '2.0'
		id      = $Id
		error   = $error_obj
	}
}

function New-McpNotification {
	<#
	.SYNOPSIS
		Creates a JSON-RPC 2.0 notification (no id, no response expected).
	#>
	[CmdletBinding()]
	param (
		[Parameter(Mandatory)]
		[string]$Method,

		$Params
	)

	$msg = [ordered]@{
		jsonrpc = '2.0'
		method  = $Method
	}
	if ($null -ne $Params) { $msg['params'] = $Params }
	$msg
}
