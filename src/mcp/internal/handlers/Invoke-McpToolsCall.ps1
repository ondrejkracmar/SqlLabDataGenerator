function Invoke-McpToolsCall {
	<#
	.SYNOPSIS
		Handles the tools/call MCP request — dispatches to the appropriate PowerShell cmdlet.

	.DESCRIPTION
		Validates the tool name, converts JSON arguments to PowerShell parameters,
		invokes the cmdlet, and returns the result as MCP content.
	#>
	[CmdletBinding()]
	param (
		[Parameter(Mandatory)]
		$Params
	)

	$toolName = $Params.name
	$arguments = $Params.arguments

	# Validate tool exists
	$tool = $script:McpTools | Where-Object { $_.name -eq $toolName }
	if (-not $tool) {
		return [ordered]@{
			content = @([ordered]@{ type = 'text'; text = "Unknown tool: $toolName" })
			isError = $true
		}
	}

	# Convert arguments hashtable — handle ConvertFrom-Json producing PSCustomObject
	$psParams = @{}
	if ($null -ne $arguments) {
		$argObject = if ($arguments -is [hashtable]) { $arguments }
		else {
			$ht = @{}
			foreach ($prop in $arguments.PSObject.Properties) {
				$ht[$prop.Name] = $prop.Value
			}
			$ht
		}

		# Convert argument types based on tool schema
		$cmdInfo = Get-Command -Name $toolName -ErrorAction SilentlyContinue
		if ($cmdInfo) {
			foreach ($key in @($argObject.Keys)) {
				$paramInfo = $cmdInfo.Parameters[$key]
				if (-not $paramInfo) { continue }

				$value = $argObject[$key]
				$targetType = $paramInfo.ParameterType

				# Handle switch parameters — MCP sends booleans
				if ($targetType -eq [switch]) {
					$argObject[$key] = [switch][bool]$value
				}
				# Handle PSCredential — MCP sends { username, password }
				elseif ($targetType -eq [System.Management.Automation.PSCredential] -and $value -is [PSCustomObject]) {
					$secPass = ConvertTo-SecureString -String $value.password -AsPlainText -Force
					$argObject[$key] = [System.Management.Automation.PSCredential]::new($value.username, $secPass)
				}
				# Handle string arrays — MCP may send a single string
				elseif ($targetType -eq [string[]] -and $value -is [string]) {
					$argObject[$key] = @($value)
				}
				# Handle int
				elseif ($targetType -eq [int] -and $value -isnot [int]) {
					$argObject[$key] = [int]$value
				}
				# Handle hashtable from PSCustomObject
				elseif ($targetType -eq [hashtable] -and $value -is [PSCustomObject]) {
					$ht = @{}
					foreach ($p in $value.PSObject.Properties) { $ht[$p.Name] = $p.Value }
					$argObject[$key] = $ht
				}
				# Handle SecureString — MCP sends plaintext strings
				elseif ($targetType -eq [System.Security.SecureString] -and $value -is [string]) {
					$argObject[$key] = ConvertTo-SecureString -String $value -AsPlainText -Force
				}
			}
		}

		$psParams = $argObject
	}

	# Invoke the cmdlet
	try {
		$output = & $toolName @psParams 2>&1
		$errors = @($output | Where-Object { $_ -is [System.Management.Automation.ErrorRecord] })
		$results = @($output | Where-Object { $_ -isnot [System.Management.Automation.ErrorRecord] })

		if ($errors.Count -gt 0 -and $results.Count -eq 0) {
			$errorText = ($errors | ForEach-Object { $_.Exception.Message }) -join "`n"
			[ordered]@{
				content = @([ordered]@{ type = 'text'; text = $errorText })
				isError = $true
			}
		}
		else {
			$content = $results | ConvertTo-McpContent
			$result = [ordered]@{ content = $content }
			if ($errors.Count -gt 0) {
				$result['content'] += @([ordered]@{
					type = 'text'
					text = "Warnings: $(($errors | ForEach-Object { $_.Exception.Message }) -join '; ')"
				})
			}
			$result
		}
	}
	catch {
		[ordered]@{
			content = @([ordered]@{ type = 'text'; text = $_.Exception.Message })
			isError = $true
		}
	}
}
