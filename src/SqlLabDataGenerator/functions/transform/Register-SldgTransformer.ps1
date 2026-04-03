function Register-SldgTransformer {
	<#
	.SYNOPSIS
		Registers a custom data transformer.

	.DESCRIPTION
		Registers a custom transformer that converts generated DataTable data
		into a specific target format. The transformer function must accept
		a -Data parameter (System.Data.DataTable) and return transformed objects.

	.PARAMETER Name
		Unique name for the transformer.

	.PARAMETER Description
		Description of what the transformer produces.

	.PARAMETER TransformFunction
		Name of the function that performs the transformation.
		The function must accept a -Data [System.Data.DataTable] parameter.

	.PARAMETER RequiredSemanticTypes
		Optional list of semantic types the source data should contain.

	.PARAMETER OutputType
		Optional PSTypeName of the output objects.

	.EXAMPLE
		PS C:\> Register-SldgTransformer -Name 'CsvUsers' `
		>>     -Description 'Exports users as CSV-ready objects' `
		>>     -TransformFunction 'ConvertTo-CsvUser'

		Registers a transformer that converts generated data to CSV-ready user objects.
	#>
	[OutputType([void])]
	[CmdletBinding(SupportsShouldProcess)]
	param (
		[Parameter(Mandatory)]
		[ValidateNotNullOrEmpty()]
		[string]$Name,

		[Parameter(Mandatory)]
		[ValidateNotNullOrEmpty()]
		[string]$Description,

		[Parameter(Mandatory)]
		[ValidateNotNullOrEmpty()]
		[string]$TransformFunction,

		[string[]]$RequiredSemanticTypes,

		[string]$OutputType
	)

	if (-not $PSCmdlet.ShouldProcess($Name, 'Register transformer')) { return }

	Register-SldgTransformerInternal -Name $Name -Description $Description `
		-TransformFunction $TransformFunction `
		-RequiredSemanticTypes $RequiredSemanticTypes `
		-OutputType $OutputType
}
