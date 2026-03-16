function Test-SldgConnection
{
<#
	.SYNOPSIS
		Tests connectivity to the SqlLabDataGenerator Azure Function.
	
	.DESCRIPTION
		Sends a lightweight request to the Azure Function endpoint to verify
		connectivity and authentication before running operations.
		Returns $true if the connection is healthy, $false otherwise.
	
	.EXAMPLE
		PS C:\> Test-SldgConnection
	
		Tests whether the configured Azure Function endpoint is reachable.
#>
	[OutputType([bool])]
	[CmdletBinding()]
	param ()
	
	process
	{
		try
		{
			$connectionData = Get-InternalConnectionData -Method 'GET' -FunctionName 'health'
			$response = Invoke-RestMethod @connectionData -TimeoutSec 15 -ErrorAction Stop
			Write-PSFMessage -Level Verbose -Message "Connection test successful"
			$true
		}
		catch
		{
			Write-PSFMessage -Level Warning -Message "Connection test failed: $($_.Exception.Message)"
			$false
		}
	}
}
