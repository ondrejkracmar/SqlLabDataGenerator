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
		Write-PSFMessage -Level Verbose -Message ($script:strings.'AI.ModelOverrideUsing' -f $Purpose, $override['Provider'], $override['Model'])
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
		Write-PSFMessage -Level Warning -Message ($script:strings.'AI.ApiKeyFailed' -f $_)
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

	# Circuit breaker: skip AI calls after consecutive failures to avoid hammering a broken provider
	$cbThreshold = Get-PSFConfigValue -FullName 'SqlLabDataGenerator.AI.CircuitBreakerThreshold'
	$cbCooldown = Get-PSFConfigValue -FullName 'SqlLabDataGenerator.AI.CircuitBreakerCooldownSeconds'
	if ($script:AICircuitBreaker.ConsecutiveFailures -ge $cbThreshold) {
		$elapsed = ([datetime]::UtcNow - $script:AICircuitBreaker.OpenedAt).TotalSeconds
		if ($elapsed -lt $cbCooldown) {
			# Circuit is still open — skip this call
			return $null
		}
		# Cooldown expired — reset and allow a probe request
		Write-PSFMessage -Level Warning -Message $script:strings.'AI.CircuitBreakerReset'
		$script:AICircuitBreaker.ConsecutiveFailures = 0
		$script:AICircuitBreaker.OpenedAt = $null
	}

	# Rate limiting: enforce max requests per minute
	# Always clean up stale timestamps to prevent unbounded queue growth
	# Use lock to make check-wait-enqueue atomic across concurrent callers
	$rateLimitLock = $script:SldgState.AIRateLimitLock
	[System.Threading.Monitor]::Enter($rateLimitLock)
	try {
		$now = [datetime]::UtcNow
		$windowStart = $now.AddMinutes(-1)
		$peeked = [datetime]::MinValue
		while ($script:SldgState.AIRequestTimestamps.Count -gt 0 -and $script:SldgState.AIRequestTimestamps.TryPeek([ref]$peeked) -and $peeked -lt $windowStart) {
			$null = $script:SldgState.AIRequestTimestamps.TryDequeue([ref]$peeked)
		}
		if ($rateLimit -and $rateLimit -gt 0) {
			if ($script:SldgState.AIRequestTimestamps.Count -ge $rateLimit) {
				$oldest = [datetime]::MinValue
				$null = $script:SldgState.AIRequestTimestamps.TryPeek([ref]$oldest)
				$waitUntil = $oldest.AddMinutes(1)
				$waitSeconds = [math]::Ceiling(($waitUntil - $now).TotalSeconds)
				if ($waitSeconds -gt 0) {
					Write-PSFMessage -Level Verbose -Message ($script:strings.'AI.RateLimitWaiting' -f $waitSeconds)
					# Release lock during sleep so other callers are not blocked
					[System.Threading.Monitor]::Exit($rateLimitLock)
					try {
						Start-Sleep -Seconds $waitSeconds
					}
					finally {
						[System.Threading.Monitor]::Enter($rateLimitLock)
					}
				}
				# Clean up again after waiting
				$now = [datetime]::UtcNow
				$windowStart = $now.AddMinutes(-1)
				$peeked = [datetime]::MinValue
				while ($script:SldgState.AIRequestTimestamps.Count -gt 0 -and $script:SldgState.AIRequestTimestamps.TryPeek([ref]$peeked) -and $peeked -lt $windowStart) {
					$null = $script:SldgState.AIRequestTimestamps.TryDequeue([ref]$peeked)
				}
			}
		}
		# Record timestamp before request (outside retry loop — one logical request per invocation)
		$script:SldgState.AIRequestTimestamps.Enqueue([datetime]::UtcNow)
	}
	finally {
		[System.Threading.Monitor]::Exit($rateLimitLock)
	}

	# Periodic cache maintenance: trim caches only when they exceed max entries
	$maxCacheEntries = Get-PSFConfigValue -FullName 'SqlLabDataGenerator.Cache.MaxEntries'
	$cacheTTL = Get-PSFConfigValue -FullName 'SqlLabDataGenerator.Cache.TTLMinutes'
	$sep = $script:CacheKeySeparator
	foreach ($cacheName in @('AIValueCache', 'AILocaleCache', 'AILocaleCategoryCache')) {
		$cache = $script:SldgState.$cacheName
		if ($cache.Count -gt $maxCacheEntries) {
			# Evict entries older than TTL; if still over limit, remove oldest half
			$cutoff = [datetime]::UtcNow.AddMinutes(-$cacheTTL)
			$timestamps = $script:SldgState.CacheTimestamps
			$expiredKeys = @($cache.Keys | Where-Object { $timestamps.ContainsKey("${cacheName}${sep}$_") -and $timestamps["${cacheName}${sep}$_"] -lt $cutoff })
			foreach ($key in $expiredKeys) {
				$cache.Remove($key)
				$timestamps.Remove("${cacheName}${sep}$key")
			}
			# If still over limit after TTL eviction, remove oldest half by timestamp
			if ($cache.Count -gt $maxCacheEntries) {
				$toRemove = @($cache.Keys | Sort-Object { if ($timestamps.ContainsKey("${cacheName}${sep}$_")) { $timestamps["${cacheName}${sep}$_"] } else { [datetime]::MinValue } } | Select-Object -First ([math]::Floor($cache.Count / 2)))
				foreach ($key in $toRemove) { $cache.Remove($key); $timestamps.Remove("${cacheName}${sep}$key") }
			}
		}
	}

	$body = @{
		model    = $model
		messages = @(
			@{ role = 'system'; content = $SystemPrompt }
			@{ role = 'user'; content = $UserMessage }
		)
	}

	# Token limit parameter: newer OpenAI models require 'max_completion_tokens',
	# older models use 'max_tokens'. We start with 'max_completion_tokens' and
	# auto-fallback to 'max_tokens' if the API returns 'unsupported_parameter'.
	$tokenParamName = $null
	$tokenParamSwitched = $false
	if ($aiProvider -in @('OpenAI', 'AzureOpenAI')) {
		$tokenParamName = 'max_completion_tokens'
		$body[$tokenParamName] = $maxTokens
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
			$azureApiVersion = Get-PSFConfigValue -FullName 'SqlLabDataGenerator.AI.AzureApiVersion'
			"$endpoint/openai/deployments/$model/chat/completions?api-version=$azureApiVersion"
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
	# Note: .NET strings are immutable; we can only remove the reference, not scrub memory.
	if ($apiKey) {
		Remove-Variable -Name apiKey -ErrorAction SilentlyContinue
	}

	$params = @{
		Uri         = $uri
		Method      = 'Post'
		Headers     = $headers
		Body        = $bodyJson
		ErrorAction = 'Stop'
	}

	# Timeout support (PS 7+ has -TimeoutSec, PS 5.1 does not)
	if ($timeoutSec -gt 0) {
		$params['TimeoutSec'] = $timeoutSec
	}

	# Ollama may use self-signed certs in dev — scoped to Ollama only
	if ($aiProvider -eq 'Ollama') {
		$skipCertCheck = Get-PSFConfigValue -FullName 'SqlLabDataGenerator.AI.Ollama.SkipCertificateCheck'
		if ($skipCertCheck -and $PSVersionTable.PSVersion.Major -ge 7) {
			if ($env:SLDG_ALLOW_SKIP_TLS -eq '1' -or $env:SLDG_ALLOW_SKIP_TLS -eq 'true') {
				Write-PSFMessage -Level Warning -Message $script:strings.'AI.TLSSkipActive'
				$params['SkipCertificateCheck'] = $true
			} else {
				Write-PSFMessage -Level Warning -Message $script:strings.'AI.TLSSkipBlocked'
			}
		}
	}

	# Retry loop with exponential backoff
	$lastError = $null
	try {
		for ($attempt = 1; $attempt -le ($retryCount + 1); $attempt++) {
			try {
				$response = Invoke-RestMethod @params

				# Ollama /api/chat returns message directly, OpenAI-compatible returns choices array
				if ($response.message) {
					$script:AICircuitBreaker.ConsecutiveFailures = 0
					return $response.message.content
				}
				elseif ($response.choices) {
					$script:AICircuitBreaker.ConsecutiveFailures = 0
					return $response.choices[0].message.content
				}
				else {
					Write-PSFMessage -Level Warning -Message ($script:strings.'AI.UnexpectedResponse' -f $aiProvider)
					return $null
				}
			}
			catch {
				$lastError = $_

				# Determine HTTP status code for intelligent retry decisions
				$statusCode = 0
				if ($_.Exception.Response) {
					try { $statusCode = [int]$_.Exception.Response.StatusCode } catch { $null = $_ }
				}

				# Auto-fallback: if API rejects the token-limit parameter, switch and retry immediately (once only)
				if ($statusCode -eq 400 -and $tokenParamName -and -not $tokenParamSwitched -and $_.ErrorDetails.Message -match 'unsupported_parameter') {
					$tokenParamSwitched = $true
					$oldParam = $tokenParamName
					if ($tokenParamName -eq 'max_completion_tokens') {
						$tokenParamName = 'max_tokens'
					} else {
						$tokenParamName = 'max_completion_tokens'
					}
					$body.Remove($oldParam)
					$body[$tokenParamName] = $maxTokens
					$bodyJson = $body | ConvertTo-Json -Depth 10
					$params['Body'] = $bodyJson
					Write-PSFMessage -Level Verbose -Message "Switching token parameter from '$oldParam' to '$tokenParamName' and retrying."
					$attempt-- # do not consume a retry attempt for parameter negotiation
					continue
				}

				# Do not retry on authentication/authorization failures
				if ($statusCode -in @(401, 403)) {
					Write-PSFMessage -Level Warning -Message ($script:strings.'AI.RequestFailed' -f $_)
					return $null
				}

				if ($attempt -le $retryCount) {
					$delay = $retryDelay * [math]::Pow(2, $attempt - 1)

					# Honor Retry-After header from rate-limited responses (429)
					if ($statusCode -eq 429 -and $_.Exception.Response.Headers) {
						try {
							$retryAfter = $_.Exception.Response.Headers | Where-Object { $_.Key -eq 'Retry-After' } | Select-Object -First 1 -ExpandProperty Value
							if ($retryAfter) {
								$retryAfterSec = 0
								if ([int]::TryParse(($retryAfter | Select-Object -First 1), [ref]$retryAfterSec) -and $retryAfterSec -gt $delay) {
									$delay = $retryAfterSec
								}
							}
						} catch { $null = $_ }
					}

					Write-PSFMessage -Level Warning -Message ($script:strings.'AI.RetryAttempt' -f $attempt, $retryCount, $delay, $_)
					Start-Sleep -Seconds $delay
				}
			}
		}

		Write-PSFMessage -Level Warning -Message ($script:strings.'AI.RequestFailed' -f $lastError)

		# Track failure for circuit breaker
		$script:AICircuitBreaker.ConsecutiveFailures++
		if ($script:AICircuitBreaker.ConsecutiveFailures -ge $cbThreshold) {
			$script:AICircuitBreaker.OpenedAt = [datetime]::UtcNow
			Write-PSFMessage -Level Warning -Message ($script:strings.'AI.CircuitBreakerOpen' -f $cbThreshold, $cbCooldown)
		}
		$null
	}
	finally {
		# Remove sensitive API key references from headers
		foreach ($headerKey in @('Authorization', 'api-key')) {
			if ($headers.ContainsKey($headerKey)) {
				$headers.Remove($headerKey)
			}
		}
		$headers.Clear()
	}
}
