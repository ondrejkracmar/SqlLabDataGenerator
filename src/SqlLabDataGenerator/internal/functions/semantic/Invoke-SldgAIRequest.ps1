function Invoke-SldgAIRequest {
	<#
	.SYNOPSIS
		Sends a request to the configured AI provider (OpenAI, Azure OpenAI, or Ollama).
	.DESCRIPTION
		Includes retry with exponential backoff, configurable timeout, and rate limiting.
	#>
	[CmdletBinding()]
	param (
		[Parameter(Mandatory)]
		[string]$SystemPrompt,

		[Parameter(Mandatory)]
		[string]$UserMessage
	)

	$aiProvider = Get-PSFConfigValue -FullName 'SqlLabDataGenerator.AI.Provider'
	$apiKeyRaw = Get-PSFConfigValue -FullName 'SqlLabDataGenerator.AI.ApiKey'
	$apiKey = $null
	try {
		$apiKey = if ($apiKeyRaw -is [securestring]) {
			[System.Net.NetworkCredential]::new('', $apiKeyRaw).Password
		} elseif ($apiKeyRaw) { [string]$apiKeyRaw } else { $null }
	}
	catch {
		Write-PSFMessage -Level Warning -Message "Failed to retrieve API key: $_"
		return $null
	}
	$endpoint = Get-PSFConfigValue -FullName 'SqlLabDataGenerator.AI.Endpoint'
	$model = Get-PSFConfigValue -FullName 'SqlLabDataGenerator.AI.Model'
	$maxTokens = Get-PSFConfigValue -FullName 'SqlLabDataGenerator.AI.MaxTokens'
	$retryCount = Get-PSFConfigValue -FullName 'SqlLabDataGenerator.AI.RetryCount'
	$retryDelay = Get-PSFConfigValue -FullName 'SqlLabDataGenerator.AI.RetryDelaySeconds'
	$timeoutSec = Get-PSFConfigValue -FullName 'SqlLabDataGenerator.AI.TimeoutSeconds'
	$rateLimit = Get-PSFConfigValue -FullName 'SqlLabDataGenerator.AI.RateLimitPerMinute'

	if ($aiProvider -eq 'None') {
		return $null
	}

	# Ollama does not require an API key
	if ($aiProvider -ne 'Ollama' -and -not $apiKey) {
		return $null
	}

	# Rate limiting: enforce max requests per minute
	if ($rateLimit -and $rateLimit -gt 0) {
		$now = [datetime]::UtcNow
		$windowStart = $now.AddMinutes(-1)
		# Remove timestamps older than 1 minute
		while ($script:SldgState.AIRequestTimestamps.Count -gt 0 -and $script:SldgState.AIRequestTimestamps[0] -lt $windowStart) {
			$script:SldgState.AIRequestTimestamps.RemoveAt(0)
		}
		if ($script:SldgState.AIRequestTimestamps.Count -ge $rateLimit) {
			$waitUntil = $script:SldgState.AIRequestTimestamps[0].AddMinutes(1)
			$waitSeconds = [math]::Ceiling(($waitUntil - $now).TotalSeconds)
			if ($waitSeconds -gt 0) {
				Write-PSFMessage -Level Verbose -Message ($script:strings.'AI.RateLimitWaiting' -f $waitSeconds)
				Start-Sleep -Seconds $waitSeconds
			}
			# Clean up again after waiting
			$now = [datetime]::UtcNow
			$windowStart = $now.AddMinutes(-1)
			while ($script:SldgState.AIRequestTimestamps.Count -gt 0 -and $script:SldgState.AIRequestTimestamps[0] -lt $windowStart) {
				$script:SldgState.AIRequestTimestamps.RemoveAt(0)
			}
		}
	}

	$body = @{
		model      = $model
		max_tokens = $maxTokens
		messages   = @(
			@{ role = 'system'; content = $SystemPrompt }
			@{ role = 'user'; content = $UserMessage }
		)
	}

	# Ollama supports additional options
	if ($aiProvider -eq 'Ollama') {
		$temperature = Get-PSFConfigValue -FullName 'SqlLabDataGenerator.AI.Ollama.Temperature'
		if ($temperature) {
			$body['options'] = @{ temperature = $temperature }
		}
		$body['stream'] = $false
	}

	$bodyJson = $body | ConvertTo-Json -Depth 10

	$headers = @{ 'Content-Type' = 'application/json' }

	$uri = switch ($aiProvider) {
		'OpenAI' {
			$headers['Authorization'] = "Bearer $apiKey"
			'https://api.openai.com/v1/chat/completions'
		}
		'AzureOpenAI' {
			$headers['api-key'] = $apiKey
			"$endpoint/openai/deployments/$model/chat/completions?api-version=2024-02-01"
		}
		'Ollama' {
			$ollamaEndpoint = if ($endpoint) { $endpoint.TrimEnd('/') } else { 'http://localhost:11434' }
			"$ollamaEndpoint/api/chat"
		}
		default {
			Write-PSFMessage -Level Warning -Message ($script:strings.'AI.UnknownProvider' -f $aiProvider)
			return $null
		}
	}

	# Clear plaintext API key from variable — already embedded in headers
	if ($apiKey) {
		$apiKey = [string]::new([char]0, $apiKey.Length)
		Remove-Variable apiKey -ErrorAction SilentlyContinue
	}

	$params = @{
		Uri         = $uri
		Method      = 'Post'
		Headers     = $headers
		Body        = $bodyJson
		ErrorAction = 'Stop'
	}

	# Timeout support (PS 7+ has -TimeoutSec, PS 5.1 does not)
	if ($PSVersionTable.PSVersion.Major -ge 7 -and $timeoutSec -gt 0) {
		$params['TimeoutSec'] = $timeoutSec
	}

	# Ollama may use self-signed certs in dev — scoped to Ollama only
	if ($aiProvider -eq 'Ollama') {
		$skipCertCheck = Get-PSFConfigValue -FullName 'SqlLabDataGenerator.AI.Ollama.SkipCertificateCheck'
		if ($skipCertCheck -and $PSVersionTable.PSVersion.Major -ge 7) {
			if (-not $env:SLDG_ALLOW_SKIP_TLS) {
				Write-PSFMessage -Level Warning -Message "TLS certificate validation skip requested for Ollama but blocked. Set environment variable SLDG_ALLOW_SKIP_TLS=1 to allow this in development environments."
			} else {
				Write-PSFMessage -Level Warning -Message "TLS certificate validation is disabled for Ollama (SLDG_ALLOW_SKIP_TLS is set). This should NEVER be used in production environments."
				$params['SkipCertificateCheck'] = $true
			}
		}
	}

	# Retry loop with exponential backoff
	$lastError = $null
	for ($attempt = 1; $attempt -le ($retryCount + 1); $attempt++) {
		try {
			# Record timestamp for rate limiting
			$script:SldgState.AIRequestTimestamps.Add([datetime]::UtcNow)

			$response = Invoke-RestMethod @params

			# Ollama /api/chat returns message directly, OpenAI-compatible returns choices array
			if ($response.message) {
				return $response.message.content
			}
			elseif ($response.choices) {
				return $response.choices[0].message.content
			}
			else {
				Write-PSFMessage -Level Warning -Message ($script:strings.'AI.UnexpectedResponse' -f $aiProvider)
				return $null
			}
		}
		catch {
			$lastError = $_
			if ($attempt -le $retryCount) {
				$delay = $retryDelay * [math]::Pow(2, $attempt - 1)
				Write-PSFMessage -Level Warning -Message ($script:strings.'AI.RetryAttempt' -f $attempt, $retryCount, $delay, $_)
				Start-Sleep -Seconds $delay
			}
		}
	}

	Write-PSFMessage -Level Warning -Message ($script:strings.'AI.RequestFailed' -f $lastError)
	$null
}
