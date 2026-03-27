function Get-SldgAIProvider {
	<#
	.SYNOPSIS
		Returns the current AI provider configuration.

	.DESCRIPTION
		Shows which AI provider is configured, model, endpoint, and which AI features are enabled.
		Returns a structured object useful for pipelines and display.

		When per-purpose model overrides are configured (via Set-SldgAIProvider -Purpose),
		they are included in the ModelOverrides property.

	.PARAMETER Purpose
		Show the effective AI configuration for a specific purpose, resolving overrides.

	.EXAMPLE
		PS C:\> Get-SldgAIProvider

		Provider       : Ollama
		Model          : llama3
		Endpoint       : http://localhost:11434
		ApiKeySet      : False
		MaxTokens      : 4096
		Temperature    : 0.3
		AIGeneration   : True
		AILocale       : True
		Locale         : cs-CZ
		ModelOverrides : {structured-value, batch-generation}

	.EXAMPLE
		PS C:\> (Get-SldgAIProvider).Provider
		Ollama

	.EXAMPLE
		PS C:\> Get-SldgAIProvider -Purpose 'structured-value'

		Shows which provider/model would be used for structured-value generation.
	#>
	[CmdletBinding()]
	[OutputType('SqlLabDataGenerator.AIProviderInfo')]
	param (
		[ValidateSet('column-analysis', 'batch-generation', 'plan-advice', 'schema-analysis', 'structured-value', 'locale-data', 'locale-category')]
		[string]$Purpose
	)

	# If a specific purpose is requested, return the effective config for that purpose
	if ($Purpose -and $script:SldgState.AIModelOverrides.ContainsKey($Purpose)) {
		$ov = $script:SldgState.AIModelOverrides[$Purpose]
		return [SqlLabDataGenerator.AIProviderInfo]@{
			Purpose    = $Purpose
			Provider   = $ov['Provider']
			Model      = $ov['Model']
			Endpoint   = $ov['Endpoint']
			ApiKeySet  = [bool]$ov['ApiKey']
			MaxTokens  = if ($ov['MaxTokens']) { $ov['MaxTokens'] } else { Get-PSFConfigValue -FullName 'SqlLabDataGenerator.AI.MaxTokens' }
			IsOverride = $true
		}
	}

	$provider = Get-PSFConfigValue -FullName 'SqlLabDataGenerator.AI.Provider'
	$apiKey = Get-PSFConfigValue -FullName 'SqlLabDataGenerator.AI.ApiKey'

	$result = [SqlLabDataGenerator.AIProviderInfo]@{
		Provider       = if ($provider) { $provider } else { 'None' }
		Model          = Get-PSFConfigValue -FullName 'SqlLabDataGenerator.AI.Model'
		Endpoint       = Get-PSFConfigValue -FullName 'SqlLabDataGenerator.AI.Endpoint'
		ApiKeySet      = [bool]$apiKey
		MaxTokens      = Get-PSFConfigValue -FullName 'SqlLabDataGenerator.AI.MaxTokens'
		Temperature    = Get-PSFConfigValue -FullName 'SqlLabDataGenerator.AI.Ollama.Temperature'
		SkipCertCheck  = Get-PSFConfigValue -FullName 'SqlLabDataGenerator.AI.Ollama.SkipCertificateCheck'
		AIGeneration   = Get-PSFConfigValue -FullName 'SqlLabDataGenerator.Generation.AIGeneration'
		AILocale       = Get-PSFConfigValue -FullName 'SqlLabDataGenerator.Generation.AILocale'
		Locale         = Get-PSFConfigValue -FullName 'SqlLabDataGenerator.Generation.Locale'
	}

	if ($Purpose) {
		$result.Purpose = $Purpose
		$result.IsOverride = $false
	}

	# Include per-purpose overrides summary
	$overrides = @($script:SldgState.AIModelOverrides.GetEnumerator() | ForEach-Object {
		[PSCustomObject]@{
			Purpose  = $_.Key
			Provider = $_.Value['Provider']
			Model    = $_.Value['Model']
		}
	})
	$result.ModelOverrides = $overrides

	# Add connection info if available
	$conn = $script:SldgState.ActiveConnection
	if ($conn) {
		$result.Database = $conn.Database
		$result.ServerInstance = $conn.ServerInstance
		$result.DatabaseProvider = $conn.Provider
	}

	$result
}
