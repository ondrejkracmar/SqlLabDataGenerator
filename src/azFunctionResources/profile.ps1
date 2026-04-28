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
		# Bound the MI handshake so a hung IMDS endpoint cannot stall every cold start indefinitely.
		$miJob = Start-Job -ScriptBlock { Connect-AzAccount -Identity -ErrorAction Stop }
		$completed = Wait-Job -Job $miJob -Timeout 15
		if (-not $completed)
		{
			Stop-Job -Job $miJob -ErrorAction SilentlyContinue
			Remove-Job -Job $miJob -Force -ErrorAction SilentlyContinue
			throw "Managed Identity authentication did not complete within 15 seconds."
		}
		Receive-Job -Job $miJob -ErrorAction Stop | Out-Null
		Remove-Job -Job $miJob -Force -ErrorAction SilentlyContinue
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