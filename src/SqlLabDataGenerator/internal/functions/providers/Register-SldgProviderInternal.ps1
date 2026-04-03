function Register-SldgProviderInternal {
	<#
	.SYNOPSIS
		Registers a database provider with the module.
	#>
	[CmdletBinding()]
	param (
		[Parameter(Mandatory)]
		[string]$Name,

		[Parameter(Mandatory)]
		[hashtable]$FunctionMap
	)

	$required = @('Connect', 'GetSchema', 'WriteData', 'ReadData', 'Disconnect')
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
		Disconnect = @('ConnectionInfo')
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
