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

		Use -Purpose to configure a different AI model for a specific task. This allows
		combining models — e.g. GPT-4 for column analysis but a local Ollama model
		for structured JSON/XML generation.

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

	.PARAMETER Credential
		PSCredential object whose password is used as the API key. Alternative to -ApiKey.

	.PARAMETER Purpose
		Set a per-purpose AI model override instead of the global default. Valid purposes:
		column-analysis, batch-generation, plan-advice, schema-analysis, structured-value,
		locale-data, locale-category.
		When AI runs for that purpose, the override is used instead of the global config.

		Two-tier AI setup example: use a smart cloud model for schema-analysis and a fast
		local model for batch-generation:
		  Set-SldgAIProvider -Provider OpenAI -Model 'o3' -ApiKey $key
		  Set-SldgAIProvider -Provider Ollama -Model 'llama3' -Purpose batch-generation

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

	.EXAMPLE
		PS C:\> Set-SldgAIProvider -Provider Ollama -Model 'codellama' -Purpose 'structured-value'

		Uses Ollama codellama specifically for JSON/XML structured value generation,
		while other AI tasks use the global provider.

	.EXAMPLE
		PS C:\> Set-SldgAIProvider -Provider OpenAI -Model 'gpt-4o' -ApiKey $key
		PS C:\> Set-SldgAIProvider -Provider Ollama -Model 'llama3' -Endpoint 'http://gpu:11434' -Purpose 'batch-generation'

		Global: GPT-4o for classification and planning. Override: Ollama for batch data generation.
	#>
	[OutputType([SqlLabDataGenerator.AIProviderInfo])]
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

		[string]$Locale,

		[ValidateSet('column-analysis', 'batch-generation', 'plan-advice', 'schema-analysis', 'structured-value', 'locale-data', 'locale-category')]
		[string]$Purpose
	)

	# Per-purpose override mode
	if ($Purpose) {
		$override = @{ Provider = $Provider }

		if ($Model) { $override['Model'] = $Model }
		elseif ($Provider -eq 'Ollama') { $override['Model'] = 'llama3' }

		if ($Endpoint) {
			# Enforce HTTPS for cloud providers (same validation as global path)
			if ($Provider -in @('OpenAI', 'AzureOpenAI')) {
				try {
					$parsedUri = [System.Uri]::new($Endpoint)
					if ($parsedUri.UserInfo) {
						Stop-PSFFunction -String 'AI.EndpointCredentialsForbidden' -EnableException $true
					}
					if ($parsedUri.Scheme -ne 'https') {
						Stop-PSFFunction -String 'AI.EndpointHttpsForbidden' -StringValues $Provider, $parsedUri.Scheme, $parsedUri.Host -EnableException $true
					}
				} catch [System.UriFormatException] {
					Stop-PSFFunction -String 'AI.EndpointInvalidUri' -StringValues $Provider -EnableException $true
				}
			}
			$override['Endpoint'] = $Endpoint
		}
		elseif ($Provider -eq 'Ollama') { $override['Endpoint'] = 'http://localhost:11434' }

		if ($Credential) {
			$override['ApiKey'] = $Credential.Password
		}
		elseif ($ApiKey) {
			$override['ApiKey'] = $ApiKey
		}

		if ($MaxTokens -gt 0) { $override['MaxTokens'] = $MaxTokens }
		if ($PSBoundParameters.ContainsKey('Temperature')) { $override['Temperature'] = $Temperature }

		$script:SldgState.AIModelOverrides[$Purpose] = $override
		Write-PSFMessage -Level Host -String 'AI.OverrideSet' -StringValues $Purpose, $Provider, $override['Model']

		return [SqlLabDataGenerator.AIModelOverride]@{
			Purpose    = $Purpose
			Provider   = $Provider
			Model      = $override['Model']
			Endpoint   = $override['Endpoint']
			MaxTokens  = $override['MaxTokens']
		}
	}

	# Global provider configuration
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
		# Enforce HTTPS for cloud providers to protect API keys in transit
		if ($Provider -in @('OpenAI', 'AzureOpenAI')) {
			try {
				$parsedUri = [System.Uri]::new($Endpoint)
				if ($parsedUri.UserInfo) {
					Stop-PSFFunction -String 'AI.EndpointCredentialsForbidden' -EnableException $true
				}
				if ($parsedUri.Scheme -ne 'https') {
					Stop-PSFFunction -String 'AI.EndpointHttpsForbidden' -StringValues $Provider, $parsedUri.Scheme, $parsedUri.Host -EnableException $true
				}
			} catch [System.UriFormatException] {
				Stop-PSFFunction -String 'AI.EndpointInvalidUri' -StringValues $Provider -EnableException $true
			}
		}
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
		Write-PSFMessage -Level Warning -String 'AI.TLSDisabledWarning'
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
	$script:SldgState.ClearCaches()

	# Display summary
	$config = Get-SldgAIProvider
	Write-PSFMessage -Level Host -Message ($script:strings.'AI.ProviderConfigured' -f $Provider, (Get-PSFConfigValue -FullName 'SqlLabDataGenerator.AI.Model'))

	$config
}
