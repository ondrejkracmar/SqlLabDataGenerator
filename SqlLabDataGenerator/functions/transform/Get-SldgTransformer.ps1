function Get-SldgTransformer {
	<#
	.SYNOPSIS
		Lists available data transformers.

	.DESCRIPTION
		Returns information about registered data transformers that can be used
		with Export-SldgTransformedData to convert generated data into different
		target formats (e.g., Entra ID users, Entra ID groups).

	.PARAMETER Name
		Optional name filter. Supports wildcards.

	.EXAMPLE
		PS C:\> Get-SldgTransformer

		Lists all available transformers.

	.EXAMPLE
		PS C:\> Get-SldgTransformer -Name 'EntraId*'

		Lists Entra ID-related transformers.
	#>
	[OutputType([SqlLabDataGenerator.Transformer])]
	[CmdletBinding()]
	param (
		[string]$Name = '*'
	)

	$script:SldgState.Transformers.Values | Where-Object { $_.Name -like $Name }
}
