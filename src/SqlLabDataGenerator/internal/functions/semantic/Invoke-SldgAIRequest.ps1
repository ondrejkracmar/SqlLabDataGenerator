function Invoke-SldgAIRequest {
	<#
	.SYNOPSIS
		Sends a request to the configured AI provider (OpenAI, Azure OpenAI, or Ollama).
	.DESCRIPTION
		Includes retry with exponential backoff, configurable timeout, and rate limiting.
		When -Purpose is specified, checks for per-purpose model overrides first.
	#>
	[CmdletBinding()]
	param (
		[Parameter(Mandatory)]
		[string]$SystemPrompt,

		[Parameter(Mandatory)]
		[string]$UserMessage,

		[string]$Purpose
	)

	# Resolve provider/model — per-purpose override takes priority over global config
	$override = $null
	if ($Purpose -and $script:SldgState.AIModelOverrides.ContainsKey($Purpose)) {
		$override = $script:SldgState.AIModelOverrides[$Purpose]
		Write-PSFMessage -Level Verbose -String 'AI.ModelOverrideUsing' -StringValues $Purpose, $override['Provider'], $override['Model']
	}

	$aiProvider = if ($override) { $override['Provider'] } else { Get-PSFConfigValue -FullName 'SqlLabDataGenerator.AI.Provider' }

	$apiKey = $null
	if ($override -and $override['ApiKey']) {
		$apiKeyRaw = $override['ApiKey']
	}
	else {
		$apiKeyRaw = Get-PSFConfigValue -FullName 'SqlLabDataGenerator.AI.ApiKey'
	}
	try {
		$apiKey = if ($apiKeyRaw -is [securestring]) {
			[System.Net.NetworkCredential]::new('', $apiKeyRaw).Password
		} elseif ($apiKeyRaw) { [string]$apiKeyRaw } else { $null }
	}
	catch {
		Write-PSFMessage -Level Warning -String 'AI.ApiKeyFailed' -StringValues $_
		return $null
	}

	$endpoint = if ($override -and $override['Endpoint']) { $override['Endpoint'] } else { Get-PSFConfigValue -FullName 'SqlLabDataGenerator.AI.Endpoint' }
	$model = if ($override -and $override['Model']) { $override['Model'] } else { Get-PSFConfigValue -FullName 'SqlLabDataGenerator.AI.Model' }
	$maxTokens = if ($override -and $override['MaxTokens']) { $override['MaxTokens'] } else { Get-PSFConfigValue -FullName 'SqlLabDataGenerator.AI.MaxTokens' }
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
		$temperature = if ($override -and $null -ne $override['Temperature']) { $override['Temperature'] } else { Get-PSFConfigValue -FullName 'SqlLabDataGenerator.AI.Ollama.Temperature' }
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
		$apiKey = $null
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
				Write-PSFMessage -Level Warning -String 'AI.TLSSkipBlocked'
			} else {
				Write-PSFMessage -Level Warning -String 'AI.TLSSkipActive'
				$params['SkipCertificateCheck'] = $true
			}
		}
	}

	# Retry loop with exponential backoff
	$lastError = $null
	try {
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
	finally {
		# Zero-fill sensitive API key values from headers to prevent memory exposure
		foreach ($headerKey in @('Authorization', 'api-key')) {
			if ($headers.ContainsKey($headerKey) -and $headers[$headerKey]) {
				$headers[$headerKey] = [string]::new([char]0, $headers[$headerKey].Length)
			}
		}
		$headers.Clear()
	}
}
