<#
.SYNOPSIS
	Starts the SqlLabDataGenerator MCP (Model Context Protocol) server.

.DESCRIPTION
	Exposes all SqlLabDataGenerator cmdlets as MCP tools for AI agents (Claude, Copilot, etc.).
	Supports two transport modes:
	- stdio: reads JSON-RPC from stdin, writes to stdout (for local agent integration)
	- sse: HTTP server with Server-Sent Events (for remote/web agent integration)

.PARAMETER Transport
	Transport mode: 'stdio' or 'sse'. Default: stdio.

.PARAMETER Port
	HTTP port for SSE transport. Default: 8080. Ignored in stdio mode.

.PARAMETER LogPath
	Optional path to a log file for diagnostic messages.

.EXAMPLE
	pwsh -NoProfile -File Start-SldgMcpServer.ps1

	Starts the MCP server in stdio mode (default).

.EXAMPLE
	pwsh -NoProfile -File Start-SldgMcpServer.ps1 -Transport sse -Port 3001

	Starts the MCP server as an HTTP SSE server on port 3001.
#>
[CmdletBinding()]
param (
	[ValidateSet('stdio', 'sse')]
	[string]$Transport = 'stdio',

	[int]$Port = 8080,

	[string]$LogPath
)

$ErrorActionPreference = 'Stop'

# Resolve paths
$script:McpRoot = $PSScriptRoot
try {
	$script:McpModuleRoot = Resolve-Path -Path "$PSScriptRoot\..\SqlLabDataGenerator" -ErrorAction Stop
}
catch {
	$msg = "SqlLabDataGenerator module directory not found at '$PSScriptRoot\..\SqlLabDataGenerator': $($_.Exception.Message)"
	if ($Transport -eq 'stdio') { [Console]::Error.WriteLine($msg) } else { Write-Error $msg }
	exit 1
}

# Load the SqlLabDataGenerator module
try {
	Import-Module "$script:McpModuleRoot\SqlLabDataGenerator.psd1" -Force -ErrorAction Stop
}
catch {
	$msg = "Failed to load SqlLabDataGenerator module: $($_.Exception.Message)"
	if ($Transport -eq 'stdio') {
		[Console]::Error.WriteLine($msg)
	}
	else {
		Write-Error $msg
	}
	exit 1
}

# Dot-source all MCP internal functions
foreach ($file in (Get-ChildItem -Path "$script:McpRoot\internal" -Recurse -Filter '*.ps1' -ErrorAction SilentlyContinue)) {
	try { . $file.FullName }
	catch {
		$msg = "Failed to load MCP function '$($file.Name)': $($_.Exception.Message)"
		if ($Transport -eq 'stdio') {
			[Console]::Error.WriteLine($msg)
		}
		else {
			Write-Warning $msg
		}
	}
}

# Validate critical MCP functions loaded successfully
foreach ($criticalFunc in @('Read-McpMessage', 'Write-McpMessage', 'Invoke-McpRequestHandler')) {
	if (-not (Get-Command $criticalFunc -ErrorAction SilentlyContinue)) {
		$critMsg = "Critical MCP function '$criticalFunc' failed to load. Server cannot start."
		if ($Transport -eq 'stdio') { [Console]::Error.WriteLine($critMsg) } else { Write-Error $critMsg }
		exit 1
	}
}

# Register all module cmdlets as MCP tools
$script:McpTools = Register-McpTools

$toolCount = $script:McpTools.Count
if ($Transport -eq 'stdio') {
	[Console]::Error.WriteLine("MCP: Registered $toolCount tools from SqlLabDataGenerator")
}
else {
	Write-Host "Registered $toolCount tools from SqlLabDataGenerator" -ForegroundColor Cyan
}

# Configure logging
if ($LogPath) {
	$logDir = Split-Path -Path $LogPath -Parent
	if ($logDir -and -not (Test-Path $logDir)) {
		New-Item -Path $logDir -ItemType Directory -Force | Out-Null
	}
}

# Start the appropriate transport
switch ($Transport) {
	'stdio' {
		Start-McpStdioTransport
	}
	'sse' {
		# Generate a one-time auth token for SSE transport security
		$script:McpAuthToken = [guid]::NewGuid().ToString('N')
		Write-Host "MCP Auth Token: $($script:McpAuthToken)" -ForegroundColor Magenta
		Write-Host 'Clients must send this token in the Authorization header: Bearer <token>' -ForegroundColor DarkGray

		Start-McpSseTransport -Port $Port -LogPath $LogPath -AuthToken $script:McpAuthToken
	}
}
