function Get-SldgOpenAICompatibleUri {
	<#
	.SYNOPSIS
		Turns an OpenAI-compatible base endpoint into its chat-completions URL.
	.DESCRIPTION
		LiteLLM, vLLM, LM Studio, Ollama's OpenAI facade and OpenAI itself all serve the same
		wire format under /v1/chat/completions, but users paste endpoints in every shape:
		'http://host:4000', 'http://host:4000/', 'http://host:4000/v1' or the full
		'.../v1/chat/completions'. Every shape resolves to exactly one request URL.
	.PARAMETER Endpoint
		The endpoint as configured (AI.Endpoint or a per-purpose override).
	.OUTPUTS
		System.String
	#>
	[OutputType([string])]
	[CmdletBinding()]
	param (
		[Parameter(Mandatory)]
		[ValidateNotNullOrEmpty()]
		[string]$Endpoint
	)

	$base = $Endpoint.Trim().TrimEnd('/')
	if ($base -match '/chat/completions$') { return $base }
	if ($base -match '/v1$') { return "$base/chat/completions" }
	"$base/v1/chat/completions"
}
