<#
This is the global profile file for the Azure Function App.
This file will have been executed first, before any function runs.
Use this to create a common execution environment,
but keep in mind that the profile execution time is added to the function startup time for ALL functions.
#>

if ($env:MSI_SECRET -and (Get-Module -ListAvailable Az.Accounts))
{
	try
	{
		Connect-AzAccount -Identity
		Write-Host "Managed Identity connected successfully"
	}
	catch
	{
		Write-Warning "Failed to authenticate with Managed Identity: $($_.Exception.Message)"
	}
}
else
{
	if (-not $env:MSI_SECRET) { Write-Host "MSI_SECRET not set - Managed Identity authentication skipped" }
	if (-not (Get-Module -ListAvailable Az.Accounts)) { Write-Warning "Az.Accounts module not available" }
}