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
			$deserialized = $serializedData | ConvertFrom-PSFClixml

			# Type allowlist: only permit safe parameter types from deserialized input
			$allowedTypes = @(
				[string], [int], [long], [double], [decimal], [bool], [datetime],
				[guid], [timespan], [char], [byte],
				[string[]], [int[]], [long[]], [double[]], [bool[]], [datetime[]], [byte[]],
				[hashtable], [System.Collections.Specialized.OrderedDictionary],
				[pscredential], [securestring], [switch],
				[System.Management.Automation.SwitchParameter]
			)
			if ($deserialized -is [hashtable]) {
				foreach ($key in @($deserialized.Keys)) {
					$val = $deserialized[$key]
					if ($null -ne $val -and $val.GetType() -notin $allowedTypes) {
						throw "Deserialized parameter '$key' has disallowed type '$($val.GetType().FullName)'."
					}
				}
			}

			$parameterObject.Parameters = $deserialized
		}
		catch
		{
			throw "Failed to deserialize parameters: $($_.Exception.Message)"
		}
	}
	
	$parameterObject
}