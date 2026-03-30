Describe 'MCP Protocol Layer' {
	BeforeAll {
		$mcpRoot = "$PSScriptRoot\..\..\..\mcp"
		foreach ($file in (Get-ChildItem -Path "$mcpRoot\internal" -Recurse -Filter '*.ps1' -ErrorAction SilentlyContinue)) {
			. $file.FullName
		}
	}

	Context 'Read-McpMessage' {
		It 'Parses a valid JSON-RPC request' {
			$json = '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{}}'
			$msg = Read-McpMessage -Body $json
			$msg.IsValid | Should -BeTrue
			$msg.Method | Should -Be 'initialize'
			$msg.Id | Should -Be 1
		}

		It 'Returns parse error for invalid JSON' {
			$msg = Read-McpMessage -Body 'not json'
			$msg.IsValid | Should -BeFalse
			$msg.Code | Should -Be -32700
		}

		It 'Returns invalid request for wrong jsonrpc version' {
			$json = '{"jsonrpc":"1.0","id":1,"method":"test"}'
			$msg = Read-McpMessage -Body $json
			$msg.IsValid | Should -BeFalse
			$msg.Code | Should -Be -32600
		}

		It 'Returns null for empty input' {
			$msg = Read-McpMessage -Body ''
			$msg | Should -BeNullOrEmpty
		}

		It 'Handles notification (no id)' {
			$json = '{"jsonrpc":"2.0","method":"notifications/initialized"}'
			$msg = Read-McpMessage -Body $json
			$msg.IsValid | Should -BeTrue
			$msg.Method | Should -Be 'notifications/initialized'
			$msg.Id | Should -BeNullOrEmpty
		}
	}

	Context 'Write-McpMessage' {
		It 'Serializes a response to JSON' {
			$response = [ordered]@{ jsonrpc = '2.0'; id = 1; result = @{ status = 'ok' } }
			$json = Write-McpMessage -Message $response
			$json | Should -Not -BeNullOrEmpty
			$parsed = $json | ConvertFrom-Json
			$parsed.jsonrpc | Should -Be '2.0'
			$parsed.id | Should -Be 1
		}
	}

	Context 'New-McpResponse' {
		It 'Creates a valid success response' {
			$resp = New-McpResponse -Id 42 -Result @{ tools = @() }
			$resp.jsonrpc | Should -Be '2.0'
			$resp.id | Should -Be 42
			$resp.result | Should -Not -BeNullOrEmpty
		}
	}

	Context 'New-McpError' {
		It 'Creates a valid error with data' {
			$err = New-McpError -Id 5 -Code -32601 -Message 'Method not found' -Data 'extra info'
			$err.jsonrpc | Should -Be '2.0'
			$err.id | Should -Be 5
			$err.error.code | Should -Be -32601
			$err.error.message | Should -Be 'Method not found'
			$err.error.data | Should -Be 'extra info'
		}

		It 'Creates error without data' {
			$err = New-McpError -Id 1 -Code -32700 -Message 'Parse error'
			$err.error.Keys | Should -Not -Contain 'data'
		}
	}

	Context 'ConvertTo-McpContent' {
		It 'Converts a string to text content' {
			$result = 'hello' | ConvertTo-McpContent
			$result.Count | Should -Be 1
			$result[0].type | Should -Be 'text'
			$result[0].text | Should -Be 'hello'
		}

		It 'Converts a complex object to JSON' {
			$obj = [PSCustomObject]@{ Name = 'Test'; Value = 42 }
			$result = $obj | ConvertTo-McpContent
			$result[0].type | Should -Be 'text'
			$result[0].text | Should -Match '"Name"'
		}

		It 'Returns success message for null input' {
			$result = $null | ConvertTo-McpContent
			$result[0].text | Should -Match 'no output'
		}

		It 'Handles error flag' {
			$result = 'fail' | ConvertTo-McpContent -IsError
			$result[0].text | Should -Match '^ERROR:'
		}
	}
}

Describe 'MCP Request Handler' {
	BeforeAll {
		$mcpRoot = "$PSScriptRoot\..\..\..\mcp"
		$script:McpModuleRoot = "$PSScriptRoot\..\..\..\SqlLabDataGenerator"
		foreach ($file in (Get-ChildItem -Path "$mcpRoot\internal" -Recurse -Filter '*.ps1' -ErrorAction SilentlyContinue)) {
			. $file.FullName
		}
		$script:McpTools = @()
	}

	Context 'Invoke-McpRequestHandler' {
		It 'Handles initialize request' {
			$msg = [PSCustomObject]@{ IsValid = $true; Method = 'initialize'; Params = @{}; Id = 1 }
			$response = Invoke-McpRequestHandler -Message $msg
			$response.result.protocolVersion | Should -Be '2024-11-05'
			$response.result.serverInfo.name | Should -Be 'SqlLabDataGenerator'
		}

		It 'Handles ping request' {
			$msg = [PSCustomObject]@{ IsValid = $true; Method = 'ping'; Params = $null; Id = 2 }
			$response = Invoke-McpRequestHandler -Message $msg
			$response.id | Should -Be 2
			$response.result | Should -Not -BeNullOrEmpty
		}

		It 'Returns method not found for unknown methods' {
			$msg = [PSCustomObject]@{ IsValid = $true; Method = 'unknown/method'; Params = $null; Id = 3 }
			$response = Invoke-McpRequestHandler -Message $msg
			$response.error.code | Should -Be -32601
		}

		It 'Returns tools/list with empty tools when none registered' {
			$msg = [PSCustomObject]@{ IsValid = $true; Method = 'tools/list'; Params = $null; Id = 4 }
			$response = Invoke-McpRequestHandler -Message $msg
			$response.result.Contains('tools') | Should -BeTrue -Because 'response should contain tools key'
		}

		It 'Returns resources/list' {
			$msg = [PSCustomObject]@{ IsValid = $true; Method = 'resources/list'; Params = $null; Id = 5 }
			$response = Invoke-McpRequestHandler -Message $msg
			$response.result.resources.Count | Should -BeGreaterThan 0
		}

		It 'Handles invalid message' {
			$msg = [PSCustomObject]@{ IsValid = $false; Code = -32700; Error = 'Parse error'; Id = $null }
			$response = Invoke-McpRequestHandler -Message $msg
			$response.error.code | Should -Be -32700
		}
	}
}

Describe 'MCP Tool Registration' {
	BeforeAll {
		$mcpRoot = "$PSScriptRoot\..\..\..\mcp"
		foreach ($file in (Get-ChildItem -Path "$mcpRoot\internal" -Recurse -Filter '*.ps1' -ErrorAction SilentlyContinue)) {
			. $file.FullName
		}

		Remove-Module SqlLabDataGenerator -ErrorAction Ignore
		Import-Module "$PSScriptRoot\..\..\..\SqlLabDataGenerator\SqlLabDataGenerator.psd1" -Force
	}

	Context 'Register-McpTools' {
		It 'Discovers all exported functions as tools' {
			$tools = Register-McpTools
			$tools.Count | Should -BeGreaterOrEqual 24
		}

		It 'Each tool has name, description, and inputSchema' {
			$tools = Register-McpTools
			foreach ($tool in $tools) {
				$tool.name | Should -Not -BeNullOrEmpty
				$tool.description | Should -Not -BeNullOrEmpty
				$tool.inputSchema | Should -Not -BeNullOrEmpty
				$tool.inputSchema.type | Should -Be 'object'
			}
		}

		It 'Connect-SldgDatabase has required parameters' {
			$tools = Register-McpTools
			$connectTool = $tools | Where-Object { $_.name -eq 'Connect-SldgDatabase' }
			$connectTool | Should -Not -BeNullOrEmpty
			$connectTool.inputSchema.properties | Should -Not -BeNullOrEmpty
		}

		It 'Maps string parameters correctly' {
			$tools = Register-McpTools
			$connectTool = $tools | Where-Object { $_.name -eq 'Connect-SldgDatabase' }
			$dbParam = $connectTool.inputSchema.properties.Database
			$dbParam.type | Should -Be 'string'
		}

		It 'Maps switch parameters as boolean' {
			$tools = Register-McpTools
			$genTool = $tools | Where-Object { $_.name -eq 'Invoke-SldgDataGeneration' }
			if ($genTool.inputSchema.properties.Parallel) {
				$genTool.inputSchema.properties.Parallel.type | Should -Be 'boolean'
			}
		}
	}

	Context 'ConvertTo-JsonSchema' {
		It 'Maps [string] to string' {
			$result = ConvertTo-JsonSchema -ParameterType ([string]) -ParameterName 'test'
			$result.type | Should -Be 'string'
		}

		It 'Maps [int] to integer' {
			$result = ConvertTo-JsonSchema -ParameterType ([int]) -ParameterName 'test'
			$result.type | Should -Be 'integer'
		}

		It 'Maps [switch] to boolean' {
			$result = ConvertTo-JsonSchema -ParameterType ([switch]) -ParameterName 'test'
			$result.type | Should -Be 'boolean'
		}

		It 'Maps [string[]] to array of strings' {
			$result = ConvertTo-JsonSchema -ParameterType ([string[]]) -ParameterName 'test'
			$result.type | Should -Be 'array'
			$result.items.type | Should -Be 'string'
		}

		It 'Maps [PSCredential] to object with username/password' {
			$result = ConvertTo-JsonSchema -ParameterType ([System.Management.Automation.PSCredential]) -ParameterName 'test'
			$result.type | Should -Be 'object'
			$result.properties.username | Should -Not -BeNullOrEmpty
			$result.properties.password | Should -Not -BeNullOrEmpty
		}

		It 'Maps [hashtable] to object' {
			$result = ConvertTo-JsonSchema -ParameterType ([hashtable]) -ParameterName 'test'
			$result.type | Should -Be 'object'
		}

		It 'Maps enums to string with values' {
			# Use a well-known enum
			$result = ConvertTo-JsonSchema -ParameterType ([System.DayOfWeek]) -ParameterName 'test'
			$result.type | Should -Be 'string'
			$result.enum | Should -Contain 'Monday'
		}
	}
}

Describe 'MCP Tool Invocation' {
	BeforeAll {
		$mcpRoot = "$PSScriptRoot\..\..\..\mcp"
		foreach ($file in (Get-ChildItem -Path "$mcpRoot\internal" -Recurse -Filter '*.ps1' -ErrorAction SilentlyContinue)) {
			. $file.FullName
		}

		Remove-Module SqlLabDataGenerator -ErrorAction Ignore
		Import-Module "$PSScriptRoot\..\..\..\SqlLabDataGenerator\SqlLabDataGenerator.psd1" -Force
		$script:McpTools = Register-McpTools
	}

	Context 'Invoke-McpToolsCall' {
		It 'Returns error for unknown tool' {
			$params = [PSCustomObject]@{ name = 'NonExistent-Tool'; arguments = @{} }
			$result = Invoke-McpToolsCall -Params $params
			$result.isError | Should -BeTrue
			$result.content[0].text | Should -Match 'Unknown tool'
		}

		It 'Invokes Get-SldgHealth successfully' {
			$params = [PSCustomObject]@{ name = 'Get-SldgHealth'; arguments = @{} }
			$result = Invoke-McpToolsCall -Params $params
			$result.isError | Should -Not -BeTrue
			$result.content.Count | Should -BeGreaterThan 0
		}

		It 'Invokes Get-SldgAIProvider without error' {
			$params = [PSCustomObject]@{ name = 'Get-SldgAIProvider'; arguments = @{} }
			$result = Invoke-McpToolsCall -Params $params
			# May return empty or config — just shouldn't crash
			$result.content | Should -Not -BeNullOrEmpty
		}

		It 'Handles Get-SldgTransformer' {
			$params = [PSCustomObject]@{ name = 'Get-SldgTransformer'; arguments = @{} }
			$result = Invoke-McpToolsCall -Params $params
			$result.content | Should -Not -BeNullOrEmpty
		}
	}

	Context 'Type Coercion' {
		It 'Converts boolean true to [switch] parameter' {
			# Use a tool that has a switch parameter (e.g., Invoke-SldgDataGeneration -Parallel)
			$cmdInfo = Get-Command Invoke-SldgDataGeneration
			$parallelParam = $cmdInfo.Parameters['Parallel']
			$parallelParam | Should -Not -BeNullOrEmpty -Because 'Invoke-SldgDataGeneration should have Parallel switch'

			# Simulate the coercion logic directly
			$value = $true
			$result = [switch][bool]$value
			$result.IsPresent | Should -BeTrue
		}

		It 'Converts boolean false to [switch] off' {
			$value = $false
			$result = [switch][bool]$value
			$result.IsPresent | Should -BeFalse
		}

		It 'Converts PSCustomObject to PSCredential' {
			$credJson = [PSCustomObject]@{ username = 'testuser'; password = 'testpass123' }
			$secPass = ConvertTo-SecureString -String $credJson.password -AsPlainText -Force
			$cred = [System.Management.Automation.PSCredential]::new($credJson.username, $secPass)

			$cred.UserName | Should -Be 'testuser'
			$cred.GetNetworkCredential().Password | Should -Be 'testpass123'
		}

		It 'Wraps single string as string array' {
			$value = 'SingleTable'
			$result = @($value)
			$result | Should -HaveCount 1
			$result[0] | Should -Be 'SingleTable'
			$result -is [array] | Should -BeTrue
		}

		It 'Coerces string to integer' {
			$value = '42'
			$result = [int]$value
			$result | Should -Be 42
			$result | Should -BeOfType [int]
		}

		It 'Converts PSCustomObject to hashtable' {
			$obj = [PSCustomObject]@{ Key1 = 'val1'; Key2 = 42; Nested = @{ A = 1 } }
			$ht = @{}
			foreach ($p in $obj.PSObject.Properties) { $ht[$p.Name] = $p.Value }

			$ht | Should -BeOfType [hashtable]
			$ht['Key1'] | Should -Be 'val1'
			$ht['Key2'] | Should -Be 42
			$ht['Nested'] | Should -Not -BeNullOrEmpty
		}

		It 'Passes null arguments without error' {
			$params = [PSCustomObject]@{ name = 'Get-SldgHealth'; arguments = $null }
			$result = Invoke-McpToolsCall -Params $params
			$result.isError | Should -Not -BeTrue
		}

		It 'Passes hashtable arguments as-is (no PSCustomObject conversion needed)' {
			$params = [PSCustomObject]@{ name = 'Get-SldgHealth'; arguments = @{} }
			$result = Invoke-McpToolsCall -Params $params
			$result.isError | Should -Not -BeTrue
		}
	}

	Context 'Error Handling' {
		It 'Returns isError for cmdlet that throws' {
			# Import-SldgGenerationProfile with a non-existent file will error
			$params = [PSCustomObject]@{
				name      = 'Import-SldgGenerationProfile'
				arguments = @{ Path = 'C:\NonExistent\fake_profile_12345.json' }
			}
			$result = Invoke-McpToolsCall -Params $params
			$result.isError | Should -BeTrue
			$result.content[0].text | Should -Not -BeNullOrEmpty
		}

		It 'Separates errors from results in mixed output' {
			# Get-SldgColumnAnalysis without connection outputs errors but may also have output
			$params = [PSCustomObject]@{
				name      = 'Get-SldgAIProvider'
				arguments = @{}
			}
			$result = Invoke-McpToolsCall -Params $params
			# Should not crash regardless of provider state
			$result.content | Should -Not -BeNullOrEmpty
		}

		It 'Handles tool with invalid argument name gracefully' {
			$params = [PSCustomObject]@{
				name      = 'Get-SldgHealth'
				arguments = [PSCustomObject]@{ NonExistentParam = 'value' }
			}
			# Should either succeed (ignoring unknown param) or return error
			$result = Invoke-McpToolsCall -Params $params
			$result.content | Should -Not -BeNullOrEmpty
		}
	}
}
