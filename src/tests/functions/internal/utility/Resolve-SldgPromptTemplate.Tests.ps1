Describe "Resolve-SldgPromptTemplate" {
	BeforeAll {
		Remove-Module SqlLabDataGenerator -ErrorAction Ignore
		Import-Module "$PSScriptRoot\..\..\..\..\SqlLabDataGenerator\SqlLabDataGenerator.psd1" -Force
		$module = Get-Module SqlLabDataGenerator
	}

	Context "Built-in Template Resolution" {
		It "Resolves a built-in default template" {
			$result = & $module {
				Resolve-SldgPromptTemplate -Purpose 'batch-generation'
			}
			$result | Should -Not -BeNullOrEmpty
		}

		It "Returns null for non-existent template" {
			$result = & $module {
				Resolve-SldgPromptTemplate -Purpose 'nonexistent-purpose-xyz'
			}
			$result | Should -BeNullOrEmpty
		}
	}

	Context "Variable Substitution" {
		It "Replaces {{Variable}} placeholders" {
			# Create a temp template
			$tempDir = Join-Path $TestDrive 'prompts'
			New-Item -Path $tempDir -ItemType Directory -Force | Out-Null

			$templateContent = @"
---
description: Test template
---
Hello {{Name}}, your count is {{Count}}.
"@
			Set-Content -Path (Join-Path $tempDir 'test-sub.default.prompt') -Value $templateContent -Encoding UTF8

			$result = & $module {
				param($dir)
				Set-PSFConfig -FullName 'SqlLabDataGenerator.AI.PromptPath' -Value $dir
				Set-PSFConfig -FullName 'SqlLabDataGenerator.AI.PromptVariant' -Value 'default'
				$r = Resolve-SldgPromptTemplate -Purpose 'test-sub' -Variables @{ Name = 'World'; Count = 42 }
				Set-PSFConfig -FullName 'SqlLabDataGenerator.AI.PromptPath' -Value ''
				$r
			} $tempDir

			$result | Should -Match 'Hello World'
			$result | Should -Match 'your count is 42'
		}

		It "Strips YAML front matter from output" {
			$tempDir = Join-Path $TestDrive 'prompts2'
			New-Item -Path $tempDir -ItemType Directory -Force | Out-Null

			$templateContent = @"
---
description: Front matter test
model: gpt-4
---
Body content only.
"@
			Set-Content -Path (Join-Path $tempDir 'test-fm.default.prompt') -Value $templateContent -Encoding UTF8

			$result = & $module {
				param($dir)
				Set-PSFConfig -FullName 'SqlLabDataGenerator.AI.PromptPath' -Value $dir
				Set-PSFConfig -FullName 'SqlLabDataGenerator.AI.PromptVariant' -Value 'default'
				$r = Resolve-SldgPromptTemplate -Purpose 'test-fm'
				Set-PSFConfig -FullName 'SqlLabDataGenerator.AI.PromptPath' -Value ''
				$r
			} $tempDir

			$result | Should -Not -Match '---'
			$result | Should -Not -Match 'description:'
			$result | Should -Match 'Body content only'
		}

		It "Converts complex variables to JSON" {
			$tempDir = Join-Path $TestDrive 'prompts3'
			New-Item -Path $tempDir -ItemType Directory -Force | Out-Null

			$templateContent = @"
---
description: JSON test
---
Data: {{Schema}}
"@
			Set-Content -Path (Join-Path $tempDir 'test-json.default.prompt') -Value $templateContent -Encoding UTF8

			$result = & $module {
				param($dir)
				Set-PSFConfig -FullName 'SqlLabDataGenerator.AI.PromptPath' -Value $dir
				Set-PSFConfig -FullName 'SqlLabDataGenerator.AI.PromptVariant' -Value 'default'
				$r = Resolve-SldgPromptTemplate -Purpose 'test-json' -Variables @{ Schema = @{ Table = 'Users'; Columns = @('Id','Name') } }
				Set-PSFConfig -FullName 'SqlLabDataGenerator.AI.PromptPath' -Value ''
				$r
			} $tempDir

			$result | Should -Match 'Users'
			$result | Should -Match 'Id'
		}
	}

	Context "Custom Path Priority" {
		It "Prefers custom path over built-in" {
			$tempDir = Join-Path $TestDrive 'custom_prompts'
			New-Item -Path $tempDir -ItemType Directory -Force | Out-Null

			$templateContent = @"
---
description: Custom override
---
CUSTOM TEMPLATE
"@
			Set-Content -Path (Join-Path $tempDir 'batch-generation.default.prompt') -Value $templateContent -Encoding UTF8

			$result = & $module {
				param($dir)
				Set-PSFConfig -FullName 'SqlLabDataGenerator.AI.PromptPath' -Value $dir
				Set-PSFConfig -FullName 'SqlLabDataGenerator.AI.PromptVariant' -Value 'default'
				$r = Resolve-SldgPromptTemplate -Purpose 'batch-generation'
				Set-PSFConfig -FullName 'SqlLabDataGenerator.AI.PromptPath' -Value ''
				$r
			} $tempDir

			$result | Should -Match 'CUSTOM TEMPLATE'
		}
	}
}
