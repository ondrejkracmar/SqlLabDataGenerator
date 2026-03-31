function Convert-PsfMessageTarget {
	<#
	.SYNOPSIS
		Converts PSFramework message targets for display.
	.DESCRIPTION
		Required by PSFramework for message pipeline processing.
		Returns the target object as-is for string representation.
	#>
	param (
		[Parameter()]
		$Target
	)

	if ($null -eq $Target) { return }
	$Target
}
