function Set-SldgAIProvider {
	<#
	.SYNOPSIS
		Configures the AI provider for semantic analysis and data generation.

	.DESCRIPTION
		One-command setup for the AI backend. Configures which AI provider to use
		(Ollama, OpenAI, or AzureOpenAI), the model, endpoint, and generation features.

		For Ollama, no API key is required — just specify the model name and optionally
		the endpoint (defaults to http://localhost:11434).

		Optionally enables AI-powered data generation and AI-powered locale generation.

	.PARAMETER Provider
		The AI provider: Ollama, OpenAI, AzureOpenAI, or None (to disable AI).

	.PARAMETER Model
		The model name (e.g., 'llama3', 'mistral', 'codellama', 'gpt-4', 'gpt-4o').

	.PARAMETER Endpoint
		The API endpoint URL.
		- Ollama: defaults to http://localhost:11434 if not specified
		- AzureOpenAI: required (e.g., https://myinstance.openai.azure.com)
		- OpenAI: not needed (uses api.openai.com)

	.PARAMETER ApiKey
		API key for the provider. Required for OpenAI and AzureOpenAI. Not needed for Ollama.

	.PARAMETER MaxTokens
		Maximum tokens for AI responses. Default: 4096.

	.PARAMETER Temperature
		Temperature for Ollama responses (0.0 = deterministic, 1.0 = creative). Default: 0.3.

	.PARAMETER EnableAIGeneration
		Enable AI-powered data generation. AI generates entire rows of contextually-consistent data.

	.PARAMETER EnableAILocale
		Enable AI-powered locale generation. AI creates locale data on-the-fly for any language.

	.PARAMETER SkipCertificateCheck
		Skip TLS certificate validation (for self-signed certs on Ollama dev servers).

	.PARAMETER Locale
		Set the default locale for data generation (e.g., 'cs-CZ', 'de-DE').

	.EXAMPLE
		PS C:\> Set-SldgAIProvider -Provider Ollama -Model 'llama3'

		Configures Ollama with llama3 model on default localhost endpoint.

	.EXAMPLE
		PS C:\> Set-SldgAIProvider -Provider Ollama -Model 'my-custom-model' -Endpoint 'http://gpu-server:11434' -EnableAIGeneration -EnableAILocale -Locale 'cs-CZ'

		Configures a custom Ollama model on a remote server with full AI features and Czech locale.

	.EXAMPLE
		PS C:\> Set-SldgAIProvider -Provider OpenAI -Model 'gpt-4o' -ApiKey $key -EnableAIGeneration

		Configures OpenAI GPT-4o with AI data generation enabled.

	.EXAMPLE
		PS C:\> Set-SldgAIProvider -Provider AzureOpenAI -Model 'gpt-4' -Endpoint 'https://myinstance.openai.azure.com' -ApiKey $key

		Configures Azure OpenAI.

	.EXAMPLE
		PS C:\> Set-SldgAIProvider -Provider None

		Disables AI entirely. Falls back to pattern matching and static generators.
	#>
	[CmdletBinding()]
	param (
		[Parameter(Mandatory)]
		[ValidateSet('None', 'OpenAI', 'AzureOpenAI', 'Ollama')]
		[string]$Provider,

		[string]$Model,

		[string]$Endpoint,

		[SecureString]$ApiKey,

		[PSCredential]$Credential,

		[int]$MaxTokens,

		[double]$Temperature,

		[switch]$EnableAIGeneration,

		[switch]$EnableAILocale,

		[switch]$SkipCertificateCheck,

		[string]$Locale
	)

	# Provider
	Set-PSFConfig -FullName 'SqlLabDataGenerator.AI.Provider' -Value $Provider

	# Model
	if ($Model) {
		Set-PSFConfig -FullName 'SqlLabDataGenerator.AI.Model' -Value $Model
	}
	elseif ($Provider -eq 'Ollama' -and -not (Get-PSFConfigValue -FullName 'SqlLabDataGenerator.AI.Model')) {
		Set-PSFConfig -FullName 'SqlLabDataGenerator.AI.Model' -Value 'llama3'
	}

	# Endpoint
	if ($Endpoint) {
		Set-PSFConfig -FullName 'SqlLabDataGenerator.AI.Endpoint' -Value $Endpoint
	}
	elseif ($Provider -eq 'Ollama') {
		$current = Get-PSFConfigValue -FullName 'SqlLabDataGenerator.AI.Endpoint'
		if (-not $current) {
			Set-PSFConfig -FullName 'SqlLabDataGenerator.AI.Endpoint' -Value 'http://localhost:11434'
		}
	}

	# API Key (store as SecureString)
	if ($Credential) {
		$secureKey = $Credential.Password
		Set-PSFConfig -FullName 'SqlLabDataGenerator.AI.ApiKey' -Value $secureKey
	}
	elseif ($ApiKey) {
		Set-PSFConfig -FullName 'SqlLabDataGenerator.AI.ApiKey' -Value $ApiKey
	}

	# MaxTokens
	if ($MaxTokens -gt 0) {
		Set-PSFConfig -FullName 'SqlLabDataGenerator.AI.MaxTokens' -Value $MaxTokens
	}

	# Temperature (Ollama)
	if ($PSBoundParameters.ContainsKey('Temperature')) {
		Set-PSFConfig -FullName 'SqlLabDataGenerator.AI.Ollama.Temperature' -Value $Temperature
	}

	# SkipCertificateCheck (Ollama)
	if ($SkipCertificateCheck) {
		Set-PSFConfig -FullName 'SqlLabDataGenerator.AI.Ollama.SkipCertificateCheck' -Value $true
	}

	# AI Generation
	if ($EnableAIGeneration) {
		Set-PSFConfig -FullName 'SqlLabDataGenerator.Generation.AIGeneration' -Value $true
	}

	# AI Locale
	if ($EnableAILocale) {
		Set-PSFConfig -FullName 'SqlLabDataGenerator.Generation.AILocale' -Value $true
	}

	# Locale
	if ($Locale) {
		Set-PSFConfig -FullName 'SqlLabDataGenerator.Generation.Locale' -Value $Locale
	}

	# Clear caches when provider changes
	$script:SldgState.AIValueCache = @{}
	$script:SldgState.AILocaleCache = @{}
	$script:SldgState.AILocaleCategoryCache = @{}

	# Display summary
	$config = Get-SldgAIProvider
	Write-PSFMessage -Level Host -Message ($script:strings.'AI.ProviderConfigured' -f $Provider, (Get-PSFConfigValue -FullName 'SqlLabDataGenerator.AI.Model'))

	$config
}
