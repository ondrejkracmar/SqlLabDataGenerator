function Register-SldgTransformerInternal {
	<#
	.SYNOPSIS
		Registers a data transformer that converts generated data to a target format.
	#>
	[CmdletBinding()]
	param (
		[Parameter(Mandatory)]
		[string]$Name,

		[Parameter(Mandatory)]
		[string]$Description,

		[Parameter(Mandatory)]
		[string]$TransformFunction,

		[string[]]$RequiredSemanticTypes,

		[string]$OutputType
	)

	$script:SldgState.Transformers[$Name] = [SqlLabDataGenerator.Transformer]@{
		Name                  = $Name
		Description           = $Description
		TransformFunction     = $TransformFunction
		RequiredSemanticTypes = $RequiredSemanticTypes
		OutputType            = $OutputType
	}

	Write-PSFMessage -Level Verbose -Message ($script:strings.'Transform.Register' -f $Name)
}
