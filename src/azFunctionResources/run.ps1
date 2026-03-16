param (
	$Request,
	
	$TriggerMetadata
)

$parameterObject = Convert-AzureFunctionParameter -Request $Request
$parameters = $parameterObject.Parameters
try { $data = %functionname% @parameters }
catch
{
	$errorDetail = @{
		Error     = $_.Exception.Message
		Type      = $_.Exception.GetType().FullName
		Function  = '%functionname%'
		Timestamp = (Get-Date -Format 'o')
	}
	Write-AzureFunctionOutput -Value ($errorDetail | ConvertTo-Json -Depth 3) -Status InternalServerError
	return
}

Write-AzureFunctionOutput -Value $data -Serialize:$parameterObject.Serialize