function Get-InternalConnectionData
{
<#
	.SYNOPSIS
		Creates parameter hashtables for Invoke-RestMethod calls.
	
	.DESCRIPTION
		Creates parameter hashtables for Invoke-RestMethod calls.
		This is the main abstraction layer for public functions.
	
	.PARAMETER Method
		The Rest Method to use when calling this function.
	
	.PARAMETER Parameters
		The PSBoundParameters object. Will be passed online using PowerShell Serialization.
	
	.PARAMETER FunctionName
		The name of the Azure Function to call.
		This should always be the condensed name of the function.
#>
	[OutputType([System.Collections.Hashtable])]
	[CmdletBinding()]
	param (
		[string]
		$Method,
		
		$Parameters,
		
		[string]
		$FunctionName
	)
	
	process
	{
		$escapedFunctionName = [uri]::EscapeDataString($FunctionName)
		try { $uri = '{0}{1}' -f (Get-PSFConfigValue -FullName 'SqlLabDataGenerator.Client.Uri' -NotNull), $escapedFunctionName }
		catch { $PSCmdlet.ThrowTerminatingError($_) }
		$header = @{ }
		
		#region Authentication
		$unprotectedToken = Get-PSFConfigValue -FullName 'SqlLabDataGenerator.Client.UnprotectedToken'
		$protectedToken = Get-PSFConfigValue -FullName 'SqlLabDataGenerator.Client.ProtectedToken'
		
		$authenticationDone = $false
		if ($protectedToken -and -not $authenticationDone)
		{
			$header['x-functions-key'] = $protectedToken.GetNetworkCredential().Password
			$authenticationDone = $true
		}
		if ($unprotectedToken -and -not $authenticationDone)
		{
			$header['x-functions-key'] = $unprotectedToken
			$authenticationDone = $true
		}
		if (-not $authenticationDone)
		{
			throw "No Authentication configured!"
		}
		#endregion Authentication
		
		$bodyData = $Parameters | ConvertTo-PSFHashtable | ConvertTo-PSFClixml
		# Enforce a size limit on serialized data (10 MB)
		if ($bodyData.Length -gt 10485760)
		{
			throw "Serialized parameter data exceeds maximum allowed size (10 MB)."
		}
		
		@{
			Method  = $Method
			Uri	    = $uri
			Headers = $header
			Body    = (@{
				__SerializedParameters = $bodyData
				__PSSerialize		   = $true
			} | ConvertTo-Json)
		}
	}
}