function Export-SldgTransformedData {
	<#
	.SYNOPSIS
		Transforms generated data into a target format (e.g., Entra ID users, Entra ID groups).

	.DESCRIPTION
		Takes generated data (DataTable from Invoke-SldgDataGeneration with -PassThru)
		and transforms it using a registered transformer. Supports output to JSON files
		for import into target systems, or returns objects for pipeline use.

		Built-in transformers:
		- EntraIdUser: Microsoft Entra ID (Azure AD) user objects for Microsoft Graph API
		- EntraIdGroup: Microsoft Entra ID group objects for Microsoft Graph API

	.PARAMETER Data
		The DataTable containing generated data (from generation result with -PassThru).

	.PARAMETER Transformer
		Name of the registered transformer to use.

	.PARAMETER OutputPath
		Optional file path to save the transformed data as JSON.

	.PARAMETER ColumnMapping
		Optional hashtable mapping target properties to source column names.
		If not specified, auto-detection is used based on column name patterns.

	.PARAMETER TransformerParams
		Optional hashtable of additional parameters to pass to the transformer function.

	.EXAMPLE
		PS C:\> $result = Invoke-SldgDataGeneration -Plan $plan -NoInsert -PassThru
		PS C:\> $users = Export-SldgTransformedData -Data $result.Tables[0].DataTable -Transformer 'EntraIdUser' -TransformerParams @{ Domain = 'mycompany.onmicrosoft.com' }

		Transforms the first table's data into Entra ID user objects.

	.EXAMPLE
		PS C:\> Export-SldgTransformedData -Data $data -Transformer 'EntraIdUser' -OutputPath 'C:\export\users.json'

		Exports transformed user data to a JSON file.

	.EXAMPLE
		PS C:\> $groups = Export-SldgTransformedData -Data $deptData -Transformer 'EntraIdGroup' -TransformerParams @{ GroupType = 'Microsoft365' }

		Creates Microsoft 365 group objects from department data.
	#>
	[OutputType([SqlLabDataGenerator.EntraIdUser])]
	[OutputType([SqlLabDataGenerator.EntraIdGroup])]
	[CmdletBinding()]
	param (
		[Parameter(Mandatory)]
		[System.Data.DataTable]$Data,

		[Parameter(Mandatory)]
		[string]$Transformer,

		[string]$OutputPath,

		[hashtable]$ColumnMapping,

		[hashtable]$TransformerParams
	)

	# Validate transformer exists
	if (-not $script:SldgState.Transformers.ContainsKey($Transformer)) {
		$available = $script:SldgState.Transformers.Keys -join ', '
		Stop-PSFFunction -Message ($script:strings.'Transform.NotFound' -f $Transformer, $available) -EnableException $true
	}

	$transformerInfo = $script:SldgState.Transformers[$Transformer]
	Write-PSFMessage -Level Host -Message ($script:strings.'Transform.Starting' -f $Transformer, $Data.Rows.Count)

	# Build parameters for the transformer function
	$params = @{ Data = $Data }
	if ($ColumnMapping) { $params['ColumnMapping'] = $ColumnMapping }
	if ($TransformerParams) {
		foreach ($key in $TransformerParams.Keys) {
			$params[$key] = $TransformerParams[$key]
		}
	}

	# Execute transformer
	$transformed = & $transformerInfo.TransformFunction @params

	Write-PSFMessage -Level Host -Message ($script:strings.'Transform.Complete' -f $Transformer, @($transformed).Count)

	# Export to file if path specified
	if ($OutputPath) {
		# Validate path: resolve and ensure it doesn't escape via traversal
		$resolvedOutputPath = [System.IO.Path]::GetFullPath($ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($OutputPath))
		$parentDir = Split-Path -Path $resolvedOutputPath -Parent
		if ($parentDir -and -not (Test-Path $parentDir)) {
			$null = New-Item -Path $parentDir -ItemType Directory -Force
		}

		# Convert to clean hashtable for JSON export (remove PSTypeName)
		$exportData = foreach ($item in $transformed) {
			$ht = [ordered]@{}
			foreach ($prop in $item.PSObject.Properties) {
				if ($prop.Name -ne 'PSTypeName') {
					$ht[$prop.Name] = $prop.Value
				}
			}
			$ht
		}

		@{ value = @($exportData) } | ConvertTo-Json -Depth 10 | Set-Content -Path $resolvedOutputPath -Encoding UTF8
		Write-PSFMessage -Level Host -Message ($script:strings.'Transform.Exported' -f $resolvedOutputPath, @($transformed).Count)
	}

	$transformed
}
