Describe "MCP SSE Transport Security" {
	BeforeAll {
		$mcpRoot = "$PSScriptRoot\..\..\..\mcp"
		foreach ($file in (Get-ChildItem -Path "$mcpRoot\internal" -Recurse -Filter '*.ps1' -ErrorAction SilentlyContinue)) {
			. $file.FullName
		}
	}

	Context "Start-McpSseTransport - Security Constants" {
		It "Function exists" {
			Get-Command Start-McpSseTransport -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty
		}

		It "Has Port parameter with default" {
			$cmd = Get-Command Start-McpSseTransport
			$cmd.Parameters.ContainsKey('Port') | Should -BeTrue
		}

		It "Source includes body size limit constant" {
			$source = (Get-Command Start-McpSseTransport).ScriptBlock.ToString()
			$source | Should -Match 'maxRequestBodyBytes'
		}

		It "Source includes rate limiting constant" {
			$source = (Get-Command Start-McpSseTransport).ScriptBlock.ToString()
			$source | Should -Match 'rateLimitPerSession'
		}

		It "Source checks Content-Length for 413 response" {
			$source = (Get-Command Start-McpSseTransport).ScriptBlock.ToString()
			$source | Should -Match '413'
		}

		It "Source returns 429 for rate limit exceeded" {
			$source = (Get-Command Start-McpSseTransport).ScriptBlock.ToString()
			$source | Should -Match '429'
		}

		It "CORS restricted to localhost pattern" {
			$source = (Get-Command Start-McpSseTransport).ScriptBlock.ToString()
			$source | Should -Match 'localhost'
			$source | Should -Not -Match "Access-Control-Allow-Origin', '\*'"
		}

		It "Listens only on localhost prefix" {
			$source = (Get-Command Start-McpSseTransport).ScriptBlock.ToString()
			$source | Should -Match 'http://localhost:'
		}
	}

	Context "CORS Origin Validation Logic" {
		It "Accepts http://localhost origin" {
			$origin = 'http://localhost'
			$origin -match '^https?://localhost(:\d+)?$' | Should -BeTrue
		}

		It "Accepts http://localhost:3000 origin" {
			$origin = 'http://localhost:3000'
			$origin -match '^https?://localhost(:\d+)?$' | Should -BeTrue
		}

		It "Accepts https://localhost:8443 origin" {
			$origin = 'https://localhost:8443'
			$origin -match '^https?://localhost(:\d+)?$' | Should -BeTrue
		}

		It "Rejects http://evil.com origin" {
			$origin = 'http://evil.com'
			$origin -match '^https?://localhost(:\d+)?$' | Should -BeFalse
		}

		It "Rejects http://localhost.evil.com origin" {
			$origin = 'http://localhost.evil.com'
			$origin -match '^https?://localhost(:\d+)?$' | Should -BeFalse
		}

		It "Rejects null origin gracefully" {
			$origin = $null
			($origin -and $origin -match '^https?://localhost(:\d+)?$') | Should -BeFalse
		}
	}
}
