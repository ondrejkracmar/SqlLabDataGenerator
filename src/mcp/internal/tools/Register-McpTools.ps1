function Register-McpTools {
	<#
	.SYNOPSIS
		Auto-registers all exported SqlLabDataGenerator cmdlets as MCP tools.

	.DESCRIPTION
		Iterates FunctionsToExport from the module manifest, extracts parameter metadata
		via Get-Command, and builds MCP tool definitions with JSON Schema input schemas.
	#>
	[CmdletBinding()]
	param ()

	$tools = [System.Collections.Generic.List[object]]::new()
	$moduleInfo = Get-Module SqlLabDataGenerator

	if (-not $moduleInfo) {
		Write-Warning 'SqlLabDataGenerator module not loaded — no tools registered.'
		return @()
	}

	foreach ($funcName in $moduleInfo.ExportedFunctions.Keys) {
		$cmdInfo = Get-Command -Name $funcName -Module SqlLabDataGenerator -ErrorAction SilentlyContinue
		if (-not $cmdInfo) { continue }

		# Get description from help
		$help = Get-Help -Name $funcName -ErrorAction SilentlyContinue
		$description = if ($help.Synopsis -and $help.Synopsis -ne $funcName) {
			$help.Synopsis.Trim()
		}
		else {
			"Invoke the $funcName command"
		}

		# Build JSON Schema for parameters
		$properties = [ordered]@{}
		$required = [System.Collections.Generic.List[string]]::new()

		foreach ($param in $cmdInfo.Parameters.Values) {
			# Skip common parameters
			if ($param.Name -in @('Verbose', 'Debug', 'ErrorAction', 'WarningAction',
				'InformationAction', 'ErrorVariable', 'WarningVariable', 'InformationVariable',
				'OutVariable', 'OutBuffer', 'PipelineVariable', 'ProgressAction',
				'WhatIf', 'Confirm')) { continue }

			$schema = ConvertTo-JsonSchema -ParameterType $param.ParameterType -ParameterName $param.Name

			# Add help description if available
			$paramHelp = $help.parameters.parameter | Where-Object { $_.name -eq $param.Name }
			if ($paramHelp.description.text) {
				$schema['description'] = ($paramHelp.description.text -join ' ').Trim()
			}

			$properties[$param.Name] = $schema

			# Check if mandatory (in default parameter set)
			$isMandatory = $param.Attributes | Where-Object {
				$_ -is [System.Management.Automation.ParameterAttribute] -and $_.Mandatory
			}
			if ($isMandatory) {
				$required.Add($param.Name)
			}
		}

		$inputSchema = [ordered]@{
			type       = 'object'
			properties = $properties
		}
		if ($required.Count -gt 0) {
			$inputSchema['required'] = @($required)
		}

		$tools.Add([ordered]@{
			name        = $funcName
			description = $description
			inputSchema = $inputSchema
		})
	}

	@($tools)
}

function ConvertTo-JsonSchema {
	<#
	.SYNOPSIS
		Converts a .NET/PowerShell parameter type to a JSON Schema definition.
	#>
	[CmdletBinding()]
	param (
		[Parameter(Mandatory)]
		[Type]$ParameterType,

		[string]$ParameterName
	)

	# Unwrap Nullable<T>
	if ($ParameterType.IsGenericType -and $ParameterType.GetGenericTypeDefinition() -eq [Nullable`1]) {
		$ParameterType = $ParameterType.GenericTypeArguments[0]
	}

	switch ($ParameterType) {
		{ $_ -eq [string] } {
			return [ordered]@{ type = 'string' }
		}
		{ $_ -eq [int] -or $_ -eq [long] -or $_ -eq [Int16] } {
			return [ordered]@{ type = 'integer' }
		}
		{ $_ -eq [double] -or $_ -eq [float] -or $_ -eq [decimal] } {
			return [ordered]@{ type = 'number' }
		}
		{ $_ -eq [bool] } {
			return [ordered]@{ type = 'boolean' }
		}
		{ $_ -eq [switch] } {
			return [ordered]@{ type = 'boolean' }
		}
		{ $_ -eq [datetime] } {
			return [ordered]@{ type = 'string'; format = 'date-time' }
		}
		{ $_ -eq [guid] } {
			return [ordered]@{ type = 'string'; format = 'uuid' }
		}
		{ $_ -eq [timespan] } {
			return [ordered]@{ type = 'string'; description = 'Duration as string (e.g. "01:30:00")' }
		}
		{ $_ -eq [string[]] } {
			return [ordered]@{ type = 'array'; items = [ordered]@{ type = 'string' } }
		}
		{ $_ -eq [int[]] } {
			return [ordered]@{ type = 'array'; items = [ordered]@{ type = 'integer' } }
		}
		{ $_ -eq [hashtable] -or $_ -eq [System.Collections.IDictionary] } {
			return [ordered]@{ type = 'object' }
		}
		{ $_ -eq [System.Management.Automation.PSCredential] } {
			return [ordered]@{
				type       = 'object'
				properties = [ordered]@{
					username = [ordered]@{ type = 'string' }
					password = [ordered]@{ type = 'string' }
				}
				required   = @('username', 'password')
			}
		}
		{ $_ -eq [System.Management.Automation.ScriptBlock] } {
			return [ordered]@{ type = 'string'; description = 'PowerShell ScriptBlock as string' }
		}
		{ $_ -eq [System.Security.SecureString] } {
			return [ordered]@{ type = 'string'; description = 'Sensitive value (will be converted to SecureString)' }
		}
		{ $_.IsEnum } {
			$values = [Enum]::GetNames($ParameterType)
			return [ordered]@{ type = 'string'; enum = @($values) }
		}
		{ $_.IsArray } {
			$elemType = $_.GetElementType()
			$itemSchema = if ($elemType) { ConvertTo-JsonSchema -ParameterType $elemType } else { [ordered]@{ type = 'string' } }
			return [ordered]@{ type = 'array'; items = $itemSchema }
		}
		default {
			return [ordered]@{ type = 'object' }
		}
	}
}
