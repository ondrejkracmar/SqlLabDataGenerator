<#
Built-in transformer registration.
Loaded after configuration.ps1 (alphabetical order: t > p > l > c) so $script:SldgState is initialized.
#>
Register-SldgTransformerInternal -Name 'EntraIdUser' `
	-Description 'Transforms data to Microsoft Entra ID (Azure AD) user objects for Microsoft Graph API' `
	-TransformFunction 'ConvertTo-SldgEntraIdUser' `
	-RequiredSemanticTypes @('FirstName', 'LastName', 'Email') `
	-OutputType 'SqlLabDataGenerator.EntraIdUser'

Register-SldgTransformerInternal -Name 'EntraIdGroup' `
	-Description 'Transforms data to Microsoft Entra ID group objects for Microsoft Graph API' `
	-TransformFunction 'ConvertTo-SldgEntraIdGroup' `
	-RequiredSemanticTypes @('CompanyName', 'Department') `
	-OutputType 'SqlLabDataGenerator.EntraIdGroup'
