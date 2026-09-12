function Register-SldgProviderInternal {
	<#
	.SYNOPSIS
		Registers a schema/data function map for one dialect schema source.
	.DESCRIPTION
		Connections are opened by PSSqlRepository; what this module registers per engine is
		only how the catalog is read (GetSchema) and how rows are read and written
		(ReadData, WriteData). The Name is the dialect schema source the map serves:
		'SqlServer', 'Sqlite' or 'InformationSchema'.
	#>
	[CmdletBinding()]
	param (
		[Parameter(Mandatory)]
		[string]$Name,

		[Parameter(Mandatory)]
		[hashtable]$FunctionMap
	)

	$required = @('GetSchema', 'WriteData', 'ReadData')
	foreach ($key in $required) {
		if (-not $FunctionMap.ContainsKey($key)) {
			Stop-PSFFunction -Message ($script:strings.'Provider.MissingFunction' -f $Name, $key) -EnableException $true
		}

		# Verify the function actually exists and is callable
		$funcName = $FunctionMap[$key]
		if ($funcName -is [string]) {
			$funcCmd = Get-Command -Name $funcName -ErrorAction SilentlyContinue
			if (-not $funcCmd) {
				Stop-PSFFunction -String 'Provider.FunctionNotExists' -StringValues $Name, $funcName, $key -EnableException $true
			}
		}
	}

	# Validate parameter signatures for critical provider functions
	$expectedParams = @{
		WriteData  = @('ConnectionInfo', 'SchemaName', 'TableName', 'Data')
		ReadData   = @('ConnectionInfo', 'SchemaName', 'TableName')
	}
	foreach ($funcKey in $expectedParams.Keys) {
		if (-not $FunctionMap.ContainsKey($funcKey)) { continue }
		$funcName = $FunctionMap[$funcKey]
		if ($funcName -is [string]) {
			$funcCmd = Get-Command -Name $funcName -ErrorAction SilentlyContinue
			if ($funcCmd) {
				$funcParams = $funcCmd.Parameters.Keys
				foreach ($requiredParam in $expectedParams[$funcKey]) {
					if ($requiredParam -notin $funcParams) {
						Stop-PSFFunction -String 'Provider.MissingParameter' -StringValues $Name, $funcName, $funcKey, $requiredParam -EnableException $true
					}
				}
			}
		}
	}

	$script:SldgState.Providers[$Name] = [SqlLabDataGenerator.SqlProvider]@{
		Name        = $Name
		FunctionMap = $FunctionMap
		Registered  = Get-Date
	}

	Write-PSFMessage -Level Verbose -Message ($script:strings.'Provider.Register' -f $Name)
}
