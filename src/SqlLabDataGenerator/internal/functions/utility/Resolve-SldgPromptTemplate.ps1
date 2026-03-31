function Resolve-SldgPromptTemplate {
	<#
	.SYNOPSIS
		Resolves and renders a prompt template file with variable substitution.
	.DESCRIPTION
		Loads a .prompt template file for the given purpose, resolving the best
		variant match based on the active AI provider and configuration.

		Search order (first match wins):
		  1. Custom path / {purpose}.{effectiveVariant}.prompt
		  2. Custom path / {purpose}.default.prompt
		  3. Built-in  / {purpose}.{effectiveVariant}.prompt
		  4. Built-in  / {purpose}.default.prompt

		The effective variant is determined by:
		  - AI.PromptVariant config (if not 'default')
		  - Otherwise auto-detected from AI.Provider (AzureOpenAI maps to 'openai')

		Template files use YAML front matter for metadata and {{Variable}} placeholders
		in the body that are replaced from the -Variables hashtable.
	#>
	[CmdletBinding()]
	[OutputType([string])]
	param (
		[Parameter(Mandatory)]
		[string]$Purpose,

		[hashtable]$Variables = @{}
	)

	# Determine effective variant
	$configVariant = Get-PSFConfigValue -FullName 'SqlLabDataGenerator.AI.PromptVariant'
	if ($configVariant -and $configVariant -ne 'default') {
		$effectiveVariant = $configVariant
	}
	else {
		$provider = Get-PSFConfigValue -FullName 'SqlLabDataGenerator.AI.Provider'
		$effectiveVariant = switch ($provider) {
			'AzureOpenAI' { 'openai' }
			'OpenAI'      { 'openai' }
			'Ollama'      { 'ollama' }
			default       { 'default' }
		}
	}

	$builtInPath = Join-Path -Path (Join-Path -Path $script:ModuleRoot -ChildPath 'internal') -ChildPath 'prompts'
	$customPath = Get-PSFConfigValue -FullName 'SqlLabDataGenerator.AI.PromptPath'

	# Build search candidates in priority order
	$candidates = @()
	if ($customPath -and (Test-Path $customPath)) {
		$candidates += Join-Path $customPath "$Purpose.$effectiveVariant.prompt"
		if ($effectiveVariant -ne 'default') {
			$candidates += Join-Path $customPath "$Purpose.default.prompt"
		}
	}
	$candidates += Join-Path $builtInPath "$Purpose.$effectiveVariant.prompt"
	if ($effectiveVariant -ne 'default') {
		$candidates += Join-Path $builtInPath "$Purpose.default.prompt"
	}

	$resolvedFile = $null
	foreach ($candidate in $candidates) {
		if (Test-Path $candidate) {
			$resolvedFile = $candidate
			break
		}
	}

	if (-not $resolvedFile) {
		Write-PSFMessage -Level Warning -Message ($script:strings.'Prompt.TemplateNotFound' -f $Purpose, $effectiveVariant, ($candidates -join ', '))
		return $null
	}

	Write-PSFMessage -Level Verbose -Message ($script:strings.'Prompt.TemplateResolved' -f $resolvedFile)

	$raw = Get-Content -Path $resolvedFile -Raw -Encoding UTF8

	# Parse YAML front matter: strip the --- header block, keep the body
	$body = $raw
	if ($raw -match '^---\s*\r?\n([\s\S]*?)\r?\n---\s*\r?\n([\s\S]*)$') {
		$body = $Matches[2]
	}

	# Substitute {{Variable}} placeholders (use literal .Replace to avoid regex backreference injection via $0/$1/$&)
	foreach ($key in $Variables.Keys) {
		$val = $Variables[$key]
		$strVal = if ($val -is [hashtable] -or $val -is [System.Collections.IDictionary] -or $val -is [System.Array] -or $val -is [psobject] -and $val -isnot [string] -and $val -isnot [ValueType]) {
			$val | ConvertTo-Json -Depth 5 -Compress
		} else {
			[string]$val
		}
		$body = $body.Replace("{{$key}}", $strVal)
	}

	$body.TrimEnd()
}
