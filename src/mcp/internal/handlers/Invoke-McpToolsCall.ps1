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

	# Invoke the cmdlet with timeout protection
	$toolTimeoutSeconds = 300  # 5-minute max execution time per tool call
	$modBase = (Get-Module SqlLabDataGenerator).ModuleBase
	try {
		$job = Start-Job -ScriptBlock {
			param($tn, $pp, $mb)
			# Re-import module in job scope
			if ($mb) {
				Import-Module (Join-Path $mb 'SqlLabDataGenerator.psd1') -ErrorAction Stop
			}
			& $tn @pp 2>&1
		} -ArgumentList $toolName, $psParams, $modBase

		$completed = $job | Wait-Job -Timeout $toolTimeoutSeconds
		if (-not $completed) {
			$job | Stop-Job
			$job | Remove-Job -Force
			return [ordered]@{
				content = @([ordered]@{ type = 'text'; text = "Tool execution timed out after $toolTimeoutSeconds seconds." })
				isError = $true
			}
		}

		$jobState = $job.State
		$output = $job | Receive-Job -ErrorVariable jobErrors -ErrorAction SilentlyContinue
		$job | Remove-Job -Force

		# Collect errors from multiple sources: output stream (2>&1), Receive-Job errors, and deserialized ErrorRecords
		$errors = @($output | Where-Object { $_ -is [System.Management.Automation.ErrorRecord] -or $_.PSObject.TypeNames -contains 'Deserialized.System.Management.Automation.ErrorRecord' })
		$results = @($output | Where-Object { $_ -isnot [System.Management.Automation.ErrorRecord] -and $_.PSObject.TypeNames -notcontains 'Deserialized.System.Management.Automation.ErrorRecord' })

		# Terminating errors (e.g. parameter validation) show up in jobErrors, not output
		if ($jobErrors.Count -gt 0) { $errors += @($jobErrors) }

		if ($jobState -eq 'Failed' -or ($errors.Count -gt 0 -and $results.Count -eq 0)) {
			$errorText = ($errors | ForEach-Object {
				if ($_ -is [System.Management.Automation.ErrorRecord]) { $_.Exception.Message }
				elseif ($_.Exception) { $_.Exception.Message }
				else { "$_" }
			}) -join "`n"
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
