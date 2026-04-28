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
		# S-4: Managed Identity is the preferred authentication path for the Azure Function client.
		# Falls back to function-key (protected/unprotected) only if MI is not configured.
		$useManagedIdentity = $false
		try { $useManagedIdentity = [bool](Get-PSFConfigValue -FullName 'SqlLabDataGenerator.Client.UseManagedIdentity' -Fallback $false) } catch { $useManagedIdentity = $false }
		$unprotectedToken   = Get-PSFConfigValue -FullName 'SqlLabDataGenerator.Client.UnprotectedToken'
		$protectedToken     = Get-PSFConfigValue -FullName 'SqlLabDataGenerator.Client.ProtectedToken'

		$authenticationDone = $false
		if ($useManagedIdentity)
		{
			if (-not (Get-Module -ListAvailable -Name Az.Accounts))
			{
				Stop-PSFFunction -String 'Client.MIRequiresAzAccounts' -EnableException $true
				return
			}
			$audience = Get-PSFConfigValue -FullName 'SqlLabDataGenerator.Client.Audience'
			if (-not $audience)
			{
				Stop-PSFFunction -String 'Client.MIRequiresAudience' -EnableException $true
				return
			}
			try
			{
				# Get-AzAccessToken returns a SecureString in newer Az versions; coerce safely either way.
				$tokenObj = Get-AzAccessToken -ResourceUrl $audience -ErrorAction Stop
				$tokenValue = if ($tokenObj.Token -is [System.Security.SecureString]) {
					[System.Net.NetworkCredential]::new('', $tokenObj.Token).Password
				} else { [string]$tokenObj.Token }
				$header['Authorization'] = "Bearer $tokenValue"
				Remove-Variable -Name tokenValue -ErrorAction SilentlyContinue
				$authenticationDone = $true
			}
			catch
			{
				Stop-PSFFunction -Message "Failed to acquire Managed Identity access token: $($_.Exception.Message)" -ErrorRecord $_ -EnableException $true
				return
			}
		}
		if (-not $authenticationDone -and $protectedToken)
		{
			# Keep the SecureString — only materialise into the header momentarily.
			$networkCred = $protectedToken.GetNetworkCredential()
			$header['x-functions-key'] = $networkCred.Password
			$networkCred = $null
			$authenticationDone = $true
		}
		if (-not $authenticationDone -and $unprotectedToken)
		{
			$header['x-functions-key'] = $unprotectedToken
			$authenticationDone = $true
		}
		if (-not $authenticationDone)
		{
			Stop-PSFFunction -String 'Client.NoAuthConfigured' -EnableException $true
			return
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