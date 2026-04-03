function Set-SldgPromptTemplate {
	<#
	.SYNOPSIS
		Creates or updates a custom prompt template override.

	.DESCRIPTION
		Writes a custom .prompt file to the configured AI.PromptPath directory.
		Custom prompts take priority over built-in templates during resolution.

		If AI.PromptPath is not set, creates a 'prompts' folder next to the module
		and configures it automatically.

		The prompt file uses YAML front matter for metadata and supports
		{{Variable}} placeholders that are substituted at runtime.

		Accepts pipeline input from Get-SldgPromptTemplate — Purpose, Variant,
		and Content are bound by property name.

	.PARAMETER InputObject
		A prompt template object from Get-SldgPromptTemplate. Purpose, Variant,
		and Content (when present) are extracted automatically.

	.PARAMETER Purpose
		The prompt purpose to override (e.g. 'column-analysis', 'structured-value',
		'batch-generation', 'plan-advice', 'locale-data', 'locale-category').

	.PARAMETER Variant
		The variant name. Defaults to 'default'. Use provider names like 'openai'
		or 'ollama' to create provider-specific overrides.

	.PARAMETER Content
		The prompt body text. Can include {{Variable}} placeholders.

	.PARAMETER Description
		Optional description stored in the YAML front matter.

	.PARAMETER FilePath
		Read the prompt content from an existing file instead of -Content.

	.PARAMETER Force
		Overwrite an existing custom prompt without confirmation.

	.PARAMETER Confirm
		If this switch is enabled, you will be prompted for confirmation before executing any operations that change state.
	.PARAMETER WhatIf
		If this switch is enabled, no actions are performed but informational messages will be displayed that explain what would happen if the command were to run.
	.EXAMPLE
		PS C:\> Set-SldgPromptTemplate -Purpose 'structured-value' -Variant 'default' -Content $myPrompt -Description 'Custom JSON/XML generator for reports'

		Creates a custom structured-value prompt template.

	.EXAMPLE
		PS C:\> Set-SldgPromptTemplate -Purpose 'column-analysis' -Variant 'ollama' -FilePath '.\my-ollama-prompt.txt'

		Creates an Ollama-specific override for column analysis from a file.

	.EXAMPLE
		PS C:\> Get-SldgPromptTemplate -Purpose structured-value -IncludeContent | Set-SldgPromptTemplate -Force

		Copies the built-in template as a custom override (Purpose, Variant, Content bound by property name).

	.EXAMPLE
		PS C:\> Get-SldgPromptTemplate -Purpose structured-value -IncludeContent | Set-SldgPromptTemplate -Content ($_.Content -replace 'Generate 10', 'Generate 20') -Force

		Copies and modifies the built-in template.
	#>
	[OutputType([SqlLabDataGenerator.PromptTemplate])]
	[CmdletBinding(SupportsShouldProcess, DefaultParameterSetName = 'Content')]
	param (
		[Parameter(ValueFromPipeline, ParameterSetName = 'InputObject')]
		[PSTypeName('SqlLabDataGenerator.PromptTemplate')]
		$InputObject,

		[Parameter(Mandatory, ParameterSetName = 'Content', ValueFromPipelineByPropertyName)]
		[Parameter(Mandatory, ParameterSetName = 'File', ValueFromPipelineByPropertyName)]
		[ValidateNotNullOrEmpty()]
		[string]$Purpose,

		[Parameter(ValueFromPipelineByPropertyName)]
		[string]$Variant = 'default',

		[Parameter(Mandatory, ParameterSetName = 'Content', ValueFromPipelineByPropertyName)]
		[string]$Content,

		[Parameter(Mandatory, ParameterSetName = 'File')]
		[string]$FilePath,

		[string]$Description,

		[switch]$Force
	)

	process {
		# InputObject pipeline binding — extract properties from piped Get-SldgPromptTemplate output
		if ($PSCmdlet.ParameterSetName -eq 'InputObject' -and $InputObject) {
			if (-not $PSBoundParameters.ContainsKey('Purpose')) { $Purpose = $InputObject.Purpose }
			if (-not $PSBoundParameters.ContainsKey('Variant')) { $Variant = $InputObject.Variant }
			if (-not $PSBoundParameters.ContainsKey('Content') -and $InputObject.PSObject.Properties['Content']) {
				$Content = $InputObject.Content
			}
		}

		if (-not $Purpose) {
			Stop-PSFFunction -String 'Prompt.PurposeRequired' -EnableException $true
		}

		# Resolve content from file if specified
		if ($FilePath) {
			if (-not (Test-Path $FilePath)) {
				Stop-PSFFunction -String 'Prompt.FileNotFound' -StringValues $FilePath -EnableException $true
			}
			$Content = Get-Content -Path $FilePath -Raw -Encoding UTF8
		}

		if (-not $Content) {
			Stop-PSFFunction -String 'Prompt.ContentEmpty' -EnableException $true
		}

		# Ensure custom prompt path exists
		$customPath = Get-PSFConfigValue -FullName 'SqlLabDataGenerator.AI.PromptPath'
		if (-not $customPath) {
			$customPath = Join-Path (Split-Path $script:ModuleRoot -Parent) 'CustomPrompts'
			Set-PSFConfig -FullName 'SqlLabDataGenerator.AI.PromptPath' -Value $customPath
			Write-PSFMessage -Level Verbose -Message ($script:strings.'Prompt.PromptPathAutoconfigured' -f $customPath)
		}

		if (-not (Test-Path $customPath)) {
			$null = New-Item -Path $customPath -ItemType Directory -Force
			Write-PSFMessage -Level Verbose -Message ($script:strings.'Prompt.DirectoryCreated' -f $customPath)
		}

		$fileName = "$Purpose.$Variant.prompt"
		$targetPath = Join-Path $customPath $fileName

		if ((Test-Path $targetPath) -and -not $Force) {
			if (-not $PSCmdlet.ShouldProcess($targetPath, 'Overwrite existing custom prompt')) {
				return
			}
		}

		# Strip existing YAML front matter from content if present (user may have piped from Get-SldgPromptTemplate)
		$body = $Content
		if ($Content -match '^---\s*\r?\n[\s\S]*?\r?\n---\s*\r?\n([\s\S]*)$') {
			$body = $Matches[1]
		}

		# Build YAML front matter — escape values to prevent YAML injection
		$descText = if ($Description) { $Description } else { "Custom override for $Purpose" }
		# Escape YAML special characters: wrap in single quotes, double any internal single quotes
		$safePurpose = "'" + ($Purpose -replace "'", "''") + "'"
		$safeDesc = "'" + ($descText -replace "'", "''") + "'"
		$header = @"
---
purpose: $safePurpose
description: $safeDesc
version: 1
---
"@

		$fullContent = "$header`n$body"

		Set-Content -Path $targetPath -Value $fullContent -Encoding UTF8 -NoNewline
		Write-PSFMessage -Level Host -Message ($script:strings.'Prompt.Saved' -f $targetPath)

		[SqlLabDataGenerator.PromptTemplate]@{
			Purpose     = $Purpose
			Variant     = $Variant
			Description = $descText
			Path        = $targetPath
			IsCustom    = $true
		}
	}
}
