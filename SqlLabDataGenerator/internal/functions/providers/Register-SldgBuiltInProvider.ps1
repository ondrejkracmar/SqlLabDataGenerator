function Register-SldgBuiltInProvider {
	<#
	.SYNOPSIS
		Registers the built-in schema/data function maps and transformers.
	.DESCRIPTION
		Called once at import (internal/configurations/providers.ps1) and again by
		Reset-SldgSession, because SldgSession.Reset() clears every registry and a session
		without these maps cannot discover a schema or write a row. Re-running it is
		harmless: registration replaces by name.

		Function maps are keyed by dialect schema source, not by PSSqlRepository provider
		name: SqlServer -> 'SqlServer', Sqlite -> 'Sqlite', everything else (DuckDB,
		PostgreSQL, MySQL, future extensions) -> 'InformationSchema'. See
		Get-SldgProviderInternal for the resolution. Since 3.0 all three maps point at the
		same functions: the catalogue is read through PSSqlRepository's schema import
		(Get-SldgImportedSchema) and rows travel through the shared read/write paths; the
		schema source only selects the CHECK-constraint and view-hint augmentation inside them.
	#>
	[CmdletBinding()]
	param ()

	Register-SldgProviderInternal -Name 'SqlServer' -FunctionMap @{
		GetSchema = 'Get-SldgImportedSchema'
		WriteData = 'Write-SldgTableData'
		ReadData  = 'Read-SldgTableData'
	}

	Register-SldgProviderInternal -Name 'Sqlite' -FunctionMap @{
		GetSchema = 'Get-SldgImportedSchema'
		WriteData = 'Write-SldgTableData'
		ReadData  = 'Read-SldgTableData'
	}

	Register-SldgProviderInternal -Name 'InformationSchema' -FunctionMap @{
		GetSchema = 'Get-SldgImportedSchema'
		WriteData = 'Write-SldgTableData'
		ReadData  = 'Read-SldgTableData'
	}

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
}
