Describe "AI Retry Intelligence and Response Validation" {
	BeforeAll {
		Remove-Module SqlLabDataGenerator -ErrorAction Ignore
		Import-Module "$PSScriptRoot\..\..\..\SqlLabDataGenerator\SqlLabDataGenerator.psd1" -Force
		$module = Get-Module SqlLabDataGenerator
	}

	AfterAll {
		& $module { Set-PSFConfig -FullName 'SqlLabDataGenerator.AI.Provider' -Value 'None' }
	}

	Context "Invoke-SldgAIRequest - Retry Intelligence Source Verification" {
		It "Source contains HTTP 401/403 no-retry logic" {
			$source = & $module { (Get-Command Invoke-SldgAIRequest).ScriptBlock.ToString() }
			$source | Should -Match '401.*403'
		}

		It "Source contains Retry-After header handling" {
			$source = & $module { (Get-Command Invoke-SldgAIRequest).ScriptBlock.ToString() }
			$source | Should -Match 'Retry-After'
		}

		It "Source extracts HTTP status code from exception" {
			$source = & $module { (Get-Command Invoke-SldgAIRequest).ScriptBlock.ToString() }
			$source | Should -Match 'statusCode'
			$source | Should -Match 'StatusCode'
		}

		It "Source handles 429 rate limit responses specially" {
			$source = & $module { (Get-Command Invoke-SldgAIRequest).ScriptBlock.ToString() }
			$source | Should -Match '429'
		}
	}

	Context "Invoke-SldgAIRequest - API Key Clearing" {
		It "Source uses Remove-Variable for API key cleanup" {
			$source = & $module { (Get-Command Invoke-SldgAIRequest).ScriptBlock.ToString() }
			$source | Should -Match 'Remove-Variable.*apiKey'
		}

		It "Source clears headers in finally block" {
			$source = & $module { (Get-Command Invoke-SldgAIRequest).ScriptBlock.ToString() }
			$source | Should -Match 'headers\.Remove'
			$source | Should -Match 'headers\.Clear'
		}
	}

	Context "Invoke-SldgAIRequest - TLS Skip Validation" {
		It "Source checks for explicit TLS values only" {
			$source = & $module { (Get-Command Invoke-SldgAIRequest).ScriptBlock.ToString() }
			# Should check for '1' or 'true' specifically, not just truthy
			$source | Should -Match "SLDG_ALLOW_SKIP_TLS.*-eq.*'(1|true)'"
		}
	}

	Context "New-SldgAIGeneratedBatch - Response Validation" {
		It "Source validates AI returned columns" {
			$source = & $module { (Get-Command New-SldgAIGeneratedBatch).ScriptBlock.ToString() }
			$source | Should -Match 'missingCols'
		}

		It "Source logs warning for missing columns" {
			$source = & $module { (Get-Command New-SldgAIGeneratedBatch).ScriptBlock.ToString() }
			$source | Should -Match 'missing columns'
		}
	}

	Context "New-SldgAIGeneratedBatch - Prompt Injection Mitigation" {
		It "Source sanitizes IndustryHint with whitelist" {
			$source = & $module { (Get-Command New-SldgAIGeneratedBatch).ScriptBlock.ToString() }
			# Whitelist pattern for allowed characters
			$source | Should -Match 'sanitizedHint'
			$source | Should -Match '\\p\{L\}'
		}

		It "Source escapes braces in TableNotes" {
			$source = & $module { (Get-Command New-SldgAIGeneratedBatch).ScriptBlock.ToString() }
			$source | Should -Match 'escapedNotes'
			$source | Should -Match "'\\{'"
		}

		It "Source limits IndustryHint length" {
			$source = & $module { (Get-Command New-SldgAIGeneratedBatch).ScriptBlock.ToString() }
			$source | Should -Match 'Substring.*200'
		}
	}

	Context "IndustryHint Sanitization - Unit Tests" {
		It "Allows normal alphabetic text" {
			$input = 'Healthcare Industry'
			$sanitized = ($input -replace '[^\p{L}\p{N}\s\.,()\[\]]', '')
			$sanitized | Should -Be 'Healthcare Industry'
		}

		It "Strips special injection characters" {
			$input = 'Healthcare; DROP TABLE--'
			$sanitized = ($input -replace '[^\p{L}\p{N}\s\.,()\[\]]', '')
			$sanitized | Should -Not -Match 'DROP TABLE--'
		}

		It "Allows diacritics and international characters" {
			$input = 'Zdravotnictví (CZ)'
			$sanitized = ($input -replace '[^\p{L}\p{N}\s\.,()\[\]]', '')
			$sanitized | Should -Be 'Zdravotnictví (CZ)'
		}

		It "Strips curly braces from hints" {
			$input = '{malicious}'
			$sanitized = ($input -replace '[^\p{L}\p{N}\s\.,()\[\]]', '')
			$sanitized | Should -Be 'malicious'
		}

		It "Truncates long hints to 200 chars" {
			$input = 'A' * 300
			$sanitized = ($input -replace '[^\p{L}\p{N}\s\.,()\[\]]', '')
			if ($sanitized.Length -gt 200) { $sanitized = $sanitized.Substring(0, 200) }
			$sanitized.Length | Should -Be 200
		}
	}

	Context "TableNotes Brace Escaping - Unit Tests" {
		It "Escapes single braces" {
			$notes = 'Use format {name}'
			$escaped = $notes -replace '\{', '{{' -replace '\}', '}}'
			$escaped | Should -Be 'Use format {{name}}'
		}

		It "Leaves plain text unchanged" {
			$notes = 'Generate realistic names'
			$escaped = $notes -replace '\{', '{{' -replace '\}', '}}'
			$escaped | Should -Be 'Generate realistic names'
		}

		It "Handles multiple braces" {
			$notes = '{a} and {b}'
			$escaped = $notes -replace '\{', '{{' -replace '\}', '}}'
			$escaped | Should -Be '{{a}} and {{b}}'
		}
	}
}
