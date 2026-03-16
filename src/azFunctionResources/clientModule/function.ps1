function %functionname%
{
	%parameter%
	
	process
	{
		$invokeParameters = Get-InternalConnectionData -Method '%method%' -Parameter $PSBoundParameters -FunctionName '%condensedname%'
		$maxRetries = 3
		$retryDelay = 2
		for ($attempt = 1; $attempt -le $maxRetries; $attempt++)
		{
			try
			{
				$result = Invoke-RestMethod @invokeParameters -ErrorAction Stop
				return ($result | ConvertFrom-PSFClixml)
			}
			catch
			{
				if ($attempt -eq $maxRetries) { throw }
				$statusCode = $_.Exception.Response.StatusCode.value__
				# Only retry on transient errors (429, 500, 502, 503, 504)
				if ($statusCode -notin @(429, 500, 502, 503, 504)) { throw }
				$delay = $retryDelay * [math]::Pow(2, $attempt - 1)
				Write-PSFMessage -Level Warning -Message "Request failed (attempt $attempt/$maxRetries), retrying in ${delay}s: $($_.Exception.Message)"
				Start-Sleep -Seconds $delay
			}
		}
	}
}