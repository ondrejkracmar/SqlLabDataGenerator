function Get-SldgHealth {
	<#
	.SYNOPSIS
		Returns the health status of the SqlLabDataGenerator module.

	.DESCRIPTION
		Returns version, registered providers, AI configuration status, and active connection info.
		Used as the health check endpoint for the Azure Functions API.

	.EXAMPLE
		PS C:\> Get-SldgHealth

		Returns the current module health status.
	#>
	[CmdletBinding()]
	param ()

	$moduleInfo = Import-PowerShellDataFile -Path "$script:ModuleRoot\SqlLabDataGenerator.psd1"

	$aiConfig = @{
		AIGeneration = Get-PSFConfigValue -FullName 'SqlLabDataGenerator.Generation.AIGeneration' -Fallback $false
		AILocale     = Get-PSFConfigValue -FullName 'SqlLabDataGenerator.Generation.AILocale' -Fallback $false
	}

	$connection = $null
	if ($script:SldgState.ActiveConnection) {
		$connection = @{
			Provider       = $script:SldgState.ActiveProvider
			ServerInstance = $script:SldgState.ActiveConnection.ServerInstance
			Database       = $script:SldgState.ActiveConnection.Database
		}
	}

	[PSCustomObject]@{
		PSTypeName        = 'SqlLabDataGenerator.HealthStatus'
		Status            = 'OK'
		ModuleVersion     = $moduleInfo.ModuleVersion
		PowerShellVersion = $PSVersionTable.PSVersion.ToString()
		Providers         = @($script:SldgState.Providers.Keys)
		AIEnabled         = $aiConfig.AIGeneration
		AILocaleEnabled   = $aiConfig.AILocale
		ActiveConnection  = $connection
		RegisteredLocales = @($script:SldgState.Locales.Keys)
		Transformers      = @($script:SldgState.Transformers.Keys)
		Timestamp         = (Get-Date -Format 'o')
	}
}
