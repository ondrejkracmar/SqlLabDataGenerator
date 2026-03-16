function Convert-AzureFunctionParameter
{
<#
	.SYNOPSIS
		Extracts the parameters passed into the rest method.
	
	.DESCRIPTION
		Extracts the parameters passed into the rest method of an Azure Function.
		Returns a hashtable, similar to what would be found on a $PSBoundParameters variable.
	
	.PARAMETER Request
		The request to process
	
	.EXAMPLE
		PS C:\> Convert-AzureFunctionParameter -Request $request
	
		Converts the $request object into a regular hashtable.
#>
	[OutputType([System.Collections.Hashtable])]
	[CmdletBinding()]
	param (
		$Request
	)
	
	$parameterObject = [pscustomobject]@{
		Parameters = @{ }
		Serialize = $false
	}
	
	foreach ($key in $Request.Query.Keys)
	{
		# Do NOT include the authentication key
		if ($key -eq 'code') { continue }
		$parameterObject.Parameters[$key] = $Request.Query.$key
	}
	foreach ($key in $Request.Body.Keys)
	{
		$parameterObject.Parameters[$key] = $Request.Body.$key
	}
	if ($parameterObject.Parameters.__PSSerialize)
	{
		$parameterObject.Serialize = $true
		$null = $parameterObject.Parameters.Remove('__PSSerialize')
	}
	if ($parameterObject.Parameters.__SerializedParameters)
	{
		$serializedData = $parameterObject.Parameters.__SerializedParameters
		# Validate serialized data size (10 MB limit)
		if ($serializedData -is [string] -and $serializedData.Length -gt 10485760)
		{
			throw "Serialized parameter data exceeds maximum allowed size (10 MB)."
		}
		try
		{
			$parameterObject.Parameters = $serializedData | ConvertFrom-PSFClixml
		}
		catch
		{
			throw "Failed to deserialize parameters: $($_.Exception.Message)"
		}
	}
	
	$parameterObject
}