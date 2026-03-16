function Get-SldgAIProvider {
	<#
	.SYNOPSIS
		Returns the current AI provider configuration.

	.DESCRIPTION
		Shows which AI provider is configured, model, endpoint, and which AI features are enabled.
		Returns a structured object useful for pipelines and display.

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

	.EXAMPLE
		PS C:\> (Get-SldgAIProvider).Provider
		Ollama
	#>
	[CmdletBinding()]
	[OutputType('SqlLabDataGenerator.AIProviderInfo')]
	param ()

	$provider = Get-PSFConfigValue -FullName 'SqlLabDataGenerator.AI.Provider'
	$apiKey = Get-PSFConfigValue -FullName 'SqlLabDataGenerator.AI.ApiKey'

	$result = [PSCustomObject]@{
		PSTypeName     = 'SqlLabDataGenerator.AIProviderInfo'
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

	# Add connection info if available
	$conn = $script:SldgState.ActiveConnection
	if ($conn) {
		$result | Add-Member -NotePropertyName 'Database' -NotePropertyValue $conn.Database
		$result | Add-Member -NotePropertyName 'ServerInstance' -NotePropertyValue $conn.ServerInstance
		$result | Add-Member -NotePropertyName 'DatabaseProvider' -NotePropertyValue $conn.Provider
	}

	$result
}
