function Read-McpMessage {
	<#
	.SYNOPSIS
		Reads a JSON-RPC 2.0 message from the input stream.

	.DESCRIPTION
		Reads a single JSON-RPC message. In stdio mode, reads a line from stdin.
		In SSE mode, reads from the provided request body.
	#>
	[CmdletBinding()]
	param (
		[Parameter(Mandatory, ParameterSetName = 'Stdio')]
		[switch]$Stdio,

		[Parameter(Mandatory, ParameterSetName = 'Body')]
		[AllowEmptyString()]
		[string]$Body
	)

	$raw = if ($Stdio) {
		[Console]::In.ReadLine()
	}
	else {
		$Body
	}

	if ([string]::IsNullOrWhiteSpace($raw)) { return $null }

	try {
		$message = $raw | ConvertFrom-Json -ErrorAction Stop
	}
	catch {
		return [PSCustomObject]@{
			IsValid = $false
			Error   = 'Parse error'
			Code    = -32700
			Id      = $null
			Raw     = $raw
		}
	}

	# Validate JSON-RPC 2.0 structure
	if ($message.jsonrpc -ne '2.0') {
		return [PSCustomObject]@{
			IsValid = $false
			Error   = 'Invalid Request: missing or wrong jsonrpc version'
			Code    = -32600
			Id      = $message.id
			Raw     = $raw
		}
	}

	[PSCustomObject]@{
		IsValid = $true
		Method  = $message.method
		Params  = $message.params
		Id      = $message.id
		Raw     = $raw
	}
}
