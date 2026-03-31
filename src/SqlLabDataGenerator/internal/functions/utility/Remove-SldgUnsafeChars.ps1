function Remove-SldgUnsafeChars {
	<#
	.SYNOPSIS
		Removes characters outside the allowed whitelist from user-controlled text.
	.DESCRIPTION
		Centralizes AI prompt sanitization to prevent prompt injection.
		Three modes are available depending on the context:
		  General  — letters, digits, whitespace, common punctuation (for notes, context)
		  Strict   — letters, digits, whitespace, dots, commas, parens, brackets (for hints)
		  Identifier — letters, digits, whitespace, dots, hyphens, underscores, brackets (for names)
	#>
	[OutputType([string])]
	[CmdletBinding()]
	param (
		[Parameter(Mandatory)]
		[string]$Text,

		[ValidateSet('General', 'Strict', 'Identifier')]
		[string]$Mode = 'General',

		[int]$MaxLength = 0
	)

	$result = switch ($Mode) {
		'General'    { $Text -replace '[^\p{L}\p{N}\s\.\-,;:()\[\]_/''\"=<>+#&]', '' }
		'Strict'     { $Text -replace '[^\p{L}\p{N}\s\.,()\[\]]', '' }
		'Identifier' { $Text -replace '[^\p{L}\p{N}\s\.\-_\[\]]', '' }
	}

	if ($MaxLength -gt 0 -and $result.Length -gt $MaxLength) {
		$result = $result.Substring(0, $MaxLength)
	}

	$result
}
