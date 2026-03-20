function Test-SldgAIProvider {
	<#
	.SYNOPSIS
		Tests connectivity to the configured AI provider.

	.DESCRIPTION
		Sends a simple test prompt to the currently configured AI provider and reports
		whether the connection succeeded, the response time, and the model used.

	.EXAMPLE
		PS C:\> Test-SldgAIProvider

		Provider  : Ollama
		Model     : llama3
		Status    : Connected
		ResponseMs: 342

	.EXAMPLE
		PS C:\> Test-SldgAIProvider -Verbose

		Tests with verbose output showing the request/response details.
	#>
	[CmdletBinding()]
	[OutputType('SqlLabDataGenerator.AIProviderTestResult')]
	param ()

	$provider = Get-PSFConfigValue -FullName 'SqlLabDataGenerator.AI.Provider'
	$model = Get-PSFConfigValue -FullName 'SqlLabDataGenerator.AI.Model'

	if (-not $provider -or $provider -eq 'None') {
		[SqlLabDataGenerator.AIProviderTestResult]@{
			Provider   = 'None'
			Model      = $null
			Status     = 'NotConfigured'
			ResponseMs = $null
			Error      = $script:strings.'AI.ProviderNotConfigured'
		}
		return
	}

	Write-PSFMessage -Level Verbose -Message ($script:strings.'AI.TestStarting' -f $provider, $model)

	$sw = [System.Diagnostics.Stopwatch]::StartNew()
	try {
		$response = Invoke-SldgAIRequest -SystemPrompt 'You are a test endpoint. Reply with exactly: OK' -UserMessage 'Ping'
		$sw.Stop()

		if ($response) {
			$status = 'Connected'
			$errorMessage = $null
		}
		else {
			$status = 'NoResponse'
			$errorMessage = $script:strings.'AI.TestNoResponse'
		}
	}
	catch {
		$sw.Stop()
		$status = 'Failed'
		$errorMessage = $_.Exception.Message
	}

	$result = [SqlLabDataGenerator.AIProviderTestResult]@{
		Provider   = $provider
		Model      = $model
		Endpoint   = Get-PSFConfigValue -FullName 'SqlLabDataGenerator.AI.Endpoint'
		Status     = $status
		ResponseMs = [int]$sw.ElapsedMilliseconds
		Error      = $errorMessage
	}

	if ($status -eq 'Connected') {
		Write-PSFMessage -Level Host -Message ($script:strings.'AI.TestSuccess' -f $provider, $model, $sw.ElapsedMilliseconds)
	}
	else {
		Write-PSFMessage -Level Warning -Message ($script:strings.'AI.TestFailed' -f $provider, $errorMessage)
	}

	$result
}
