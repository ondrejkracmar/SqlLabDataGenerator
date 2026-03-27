function Get-SldgPromptTemplate {
	<#
	.SYNOPSIS
		Lists or reads AI prompt templates available to the module.
	.DESCRIPTION
		Discovers prompt template files (.prompt) from the built-in templates
		directory and any custom override path configured via AI.PromptPath.

		Without parameters, lists all available templates with metadata.
		With -Purpose, shows details for a specific template including
		which file would be resolved for the current AI provider.
		With -IncludeContent, also returns the rendered prompt body.
	.PARAMETER Purpose
		Filter to a specific prompt purpose (e.g. 'column-analysis', 'batch-generation').
	.PARAMETER Variant
		Show a specific variant. Defaults to the effective variant for the active provider.
	.PARAMETER IncludeContent
		Include the rendered template content in the output.
	.PARAMETER Confirm
		If this switch is enabled, you will be prompted for confirmation before executing any operations that change state.
	.PARAMETER WhatIf
		If this switch is enabled, no actions are performed but informational messages will be displayed that explain what would happen if the command were to run.
	.EXAMPLE
		PS C:\> Get-SldgPromptTemplate

		Lists all available prompt templates.
	.EXAMPLE
		PS C:\> Get-SldgPromptTemplate -Purpose column-analysis -IncludeContent

		Shows the resolved column-analysis template with its content.
	#>
	[OutputType([SqlLabDataGenerator.PromptTemplate])]
	[CmdletBinding()]
	param (
		[string]$Purpose,

		[string]$Variant,

		[switch]$IncludeContent
	)

	$builtInPath = Join-Path -Path (Join-Path -Path $script:ModuleRoot -ChildPath 'internal') -ChildPath 'prompts'
	$customPath = Get-PSFConfigValue -FullName 'SqlLabDataGenerator.AI.PromptPath'

	# Collect all .prompt files
	$allFiles = @()
	if (Test-Path $builtInPath) {
		$allFiles += Get-ChildItem -Path $builtInPath -Filter '*.prompt' -File
	}
	if ($customPath -and (Test-Path $customPath)) {
		$allFiles += Get-ChildItem -Path $customPath -Filter '*.prompt' -File
	}

	if ($Purpose) {
		$allFiles = $allFiles | Where-Object { $_.Name -like "$Purpose.*" }
	}

	foreach ($file in $allFiles) {
		# Parse name: purpose.variant.prompt
		$parts = $file.BaseName -split '\.'
		if ($parts.Count -lt 2) { continue }
		$filePurpose = $parts[0..($parts.Count - 2)] -join '.'
		$fileVariant = $parts[-1]

		# If specific variant requested, filter
		if ($Variant -and $fileVariant -ne $Variant) { continue }

		# Parse YAML front matter
		$raw = Get-Content -Path $file.FullName -Raw -Encoding UTF8
		$metadata = @{}
		$body = $raw
		if ($raw -match '^---\s*\r?\n([\s\S]*?)\r?\n---\s*\r?\n([\s\S]*)$') {
			$headerBlock = $Matches[1]
			$body = $Matches[2]
			foreach ($line in ($headerBlock -split '\r?\n')) {
				if ($line -match '^\s*([^:]+?)\s*:\s*(.+?)\s*$') {
					$metadata[$Matches[1]] = $Matches[2]
				}
			}
		}

		# Detect placeholders
		$placeholders = @([regex]::Matches($body, '\{\{(\w+)\}\}') | ForEach-Object { $_.Groups[1].Value } | Sort-Object -Unique)

		# Determine if this is the resolved (active) file
		$isCustom = $file.DirectoryName -ne $builtInPath

		$output = [SqlLabDataGenerator.PromptTemplate]@{
			Purpose      = $filePurpose
			Variant      = $fileVariant
			Description  = $metadata['description']
			Version      = $metadata['version']
			Path         = $file.FullName
			IsCustom     = $isCustom
			Placeholders = $placeholders
		}

		if ($IncludeContent) {
			$output.Content = $body
		}

		$output
	}
}
