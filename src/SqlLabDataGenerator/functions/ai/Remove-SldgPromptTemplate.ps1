function Remove-SldgPromptTemplate {
	<#
	.SYNOPSIS
		Removes a custom prompt template override.

	.DESCRIPTION
		Deletes a custom .prompt file from the AI.PromptPath directory.
		Only custom overrides can be removed — built-in templates are protected.

		After removal, the module falls back to the built-in template for that purpose.

		Accepts pipeline input from Get-SldgPromptTemplate — Purpose and Variant
		are bound by property name. Built-in templates piped in are skipped.

	.PARAMETER InputObject
		A prompt template object from Get-SldgPromptTemplate. Purpose and Variant
		are extracted automatically. Built-in (non-custom) templates are skipped.

	.PARAMETER Purpose
		The prompt purpose to remove (e.g. 'structured-value', 'column-analysis').

	.PARAMETER Variant
		The variant to remove. Defaults to 'default'.

	.PARAMETER Confirm
		If this switch is enabled, you will be prompted for confirmation before executing any operations that change state.
	.PARAMETER WhatIf
		If this switch is enabled, no actions are performed but informational messages will be displayed that explain what would happen if the command were to run.
	.EXAMPLE
		PS C:\> Remove-SldgPromptTemplate -Purpose 'structured-value'

		Removes the custom default variant of the structured-value prompt.

	.EXAMPLE
		PS C:\> Remove-SldgPromptTemplate -Purpose 'column-analysis' -Variant 'ollama'

		Removes the Ollama-specific column-analysis override.

	.EXAMPLE
		PS C:\> Get-SldgPromptTemplate | Where-Object IsCustom | Remove-SldgPromptTemplate

		Removes all custom prompt overrides via pipeline.

	.EXAMPLE
		PS C:\> Get-SldgPromptTemplate -Purpose 'structured-value' | Where-Object IsCustom | Remove-SldgPromptTemplate

		Removes custom overrides for a specific purpose.
	#>
	[CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Medium')]
	param (
		[Parameter(ValueFromPipeline)]
		[PSTypeName('SqlLabDataGenerator.PromptTemplate')]
		$InputObject,

		[Parameter(ValueFromPipelineByPropertyName)]
		[string]$Purpose,

		[Parameter(ValueFromPipelineByPropertyName)]
		[string]$Variant = 'default'
	)

	process {
		# InputObject pipeline binding
		if ($InputObject) {
			if (-not $PSBoundParameters.ContainsKey('Purpose')) { $Purpose = $InputObject.Purpose }
			if (-not $PSBoundParameters.ContainsKey('Variant')) { $Variant = $InputObject.Variant }

			# Skip built-in templates — only custom overrides can be removed
			if ($InputObject.PSObject.Properties['IsCustom'] -and -not $InputObject.IsCustom) {
				Write-PSFMessage -Level Verbose -Message ($script:strings.'Prompt.SkippingBuiltIn' -f $Purpose, $Variant)
				return
			}
		}

		if (-not $Purpose) {
			Stop-PSFFunction -String 'Prompt.PurposeRequired' -EnableException $true
		}

		$customPath = Get-PSFConfigValue -FullName 'SqlLabDataGenerator.AI.PromptPath'
		if (-not $customPath -or -not (Test-Path $customPath)) {
			Stop-PSFFunction -String 'Prompt.NoCustomPath' -EnableException $true
		}

		$fileName = "$Purpose.$Variant.prompt"
		$targetPath = Join-Path $customPath $fileName

		if (-not (Test-Path $targetPath)) {
			Write-PSFMessage -Level Warning -Message ($script:strings.'Prompt.CustomNotFound' -f $targetPath)
			return
		}

		if ($PSCmdlet.ShouldProcess($targetPath, 'Remove custom prompt template')) {
			Remove-Item -Path $targetPath -Force
			Write-PSFMessage -Level Host -Message ($script:strings.'Prompt.Removed' -f $targetPath)
		}
	}
}
