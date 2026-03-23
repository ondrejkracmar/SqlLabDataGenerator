@{
	# Script module or binary module file associated with this manifest
	RootModule = 'SqlLabDataGenerator.psm1'
	
	# Version number of this module.
	ModuleVersion = '0.0.0'
	
	# ID used to uniquely identify this module
	GUID = '82fb705b-c1c0-4c63-b5f0-aae7e9b5f962'
	
	# Author of this module
	Author = 'Ondrej Kracmar'
	
	# Company or vendor of this module
	CompanyName = 'i-system'

	# Copyright statement for this module
	Copyright = 'Copyright (c) 2026 i-system'
	
	# Description of the functionality provided by this module
	Description = 'AI-assisted synthetic data generation platform for SQL Server, SQLite and more. Discovers database schema, classifies columns semantically (with OpenAI, Azure OpenAI, or Ollama), generates realistic FK-consistent test data with locale support (en-US, cs-CZ, ...), context-dependent JSON/XML generation via cross-column AI dependencies, and transforms output to Entra ID objects and other formats.'
	
	# Minimum version of the Windows PowerShell engine required by this module
	PowerShellVersion = '5.1'
	
	# Modules that must be imported into the global environment prior to importing
	# this module
	RequiredModules    = @('PSFramework')
	
	# Assemblies that must be loaded prior to importing this module
	# Assembly loading is centralized in bin\assembly.ps1
	RequiredAssemblies = @()
	
	# Type files (.ps1xml) to be loaded when importing this module
	TypesToProcess = @('types\SqlLabDataGenerator.Types.ps1xml')
	
	# Format files (.ps1xml) to be loaded when importing this module
	FormatsToProcess = @('views\SqlLabDataGenerator.Format.ps1xml')
	
	# Functions to export from this module
	FunctionsToExport = @(
		'Connect-SldgDatabase',
		'Disconnect-SldgDatabase',
		'Export-SldgGenerationProfile',
		'Export-SldgTransformedData',
		'Get-SldgAIProvider',
		'Get-SldgColumnAnalysis',
		'Get-SldgDatabaseSchema',
		'Get-SldgPromptTemplate',
		'Get-SldgTransformer',
		'Import-SldgGenerationProfile',
		'Invoke-SldgDataGeneration',
		'New-SldgGenerationPlan',
		'Register-SldgLocale',
		'Register-SldgTransformer',
		'Remove-SldgPromptTemplate',
		'Set-SldgAIProvider',
		'Set-SldgGenerationRule',
		'Set-SldgPromptTemplate',
		'Test-SldgAIProvider',
		'Test-SldgGeneratedData'
	)
	
	# Cmdlets to export from this module
	CmdletsToExport = ''
	
	# Variables to export from this module
	VariablesToExport = ''
	
	# Aliases to export from this module
	AliasesToExport = ''
	
	# List of all modules packaged with this module
	ModuleList = @()
	
	# List of all files packaged with this module
	FileList = @()
	
	# Private data to pass to the module specified in ModuleToProcess. This may also contain a PSData hashtable with additional module metadata used by PowerShell.
	PrivateData = @{
		
		#Support for PowerShellGet galleries.
		PSData = @{
			
			# Tags applied to this module. These help with module discovery in online galleries.
			Tags = @('SQL', 'SqlServer', 'SQLite', 'TestData', 'SyntheticData', 'DataGeneration', 'LabData', 'Database', 'AI', 'Ollama', 'OpenAI', 'DataMasking', 'DevOps', 'Testing', 'EntraID', 'AzureAD', 'Locale', 'i18n')
			
			# A URL to the license for this module.
			LicenseUri = ''
			
			# A URL to the main website for this project.
			ProjectUri = ''
			
			# A URL to an icon representing this module.
			# IconUri = ''
			
			# ReleaseNotes of this module
			ReleaseNotes = ''
			
		} # End of PSData hashtable
		
	} # End of PrivateData hashtable
}