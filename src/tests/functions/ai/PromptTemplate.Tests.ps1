Describe "Prompt Template Functions" {
	BeforeAll {
		Remove-Module SqlLabDataGenerator -ErrorAction Ignore
		Import-Module "$PSScriptRoot\..\..\..\SqlLabDataGenerator\SqlLabDataGenerator.psd1" -Force
		$module = Get-Module SqlLabDataGenerator

		# Preserve original custom path
		$script:originalPromptPath = & $module { Get-PSFConfigValue -FullName 'SqlLabDataGenerator.AI.PromptPath' }
		$script:testPromptPath = Join-Path $TestDrive 'CustomPrompts'
		& $module { param($p) Set-PSFConfig -FullName 'SqlLabDataGenerator.AI.PromptPath' -Value $p } $script:testPromptPath
	}

	AfterAll {
		# Restore original prompt path
		if ($script:originalPromptPath) {
			& $module { param($p) Set-PSFConfig -FullName 'SqlLabDataGenerator.AI.PromptPath' -Value $p } $script:originalPromptPath
		}
	}

	Context "Get-SldgPromptTemplate - Parameter Validation" {
		It "Has optional Purpose parameter" {
			$cmd = Get-Command Get-SldgPromptTemplate
			$cmd.Parameters.ContainsKey('Purpose') | Should -BeTrue
		}

		It "Has optional Variant parameter" {
			$cmd = Get-Command Get-SldgPromptTemplate
			$cmd.Parameters.ContainsKey('Variant') | Should -BeTrue
		}

		It "Has IncludeContent switch parameter" {
			$cmd = Get-Command Get-SldgPromptTemplate
			$cmd.Parameters['IncludeContent'].SwitchParameter | Should -BeTrue
		}
	}

	Context "Get-SldgPromptTemplate - Built-in Templates" {
		It "Returns built-in templates" {
			$templates = Get-SldgPromptTemplate
			$templates | Should -Not -BeNullOrEmpty
		}

		It "Templates have PromptTemplate type" {
			$templates = Get-SldgPromptTemplate
			$templates | ForEach-Object {
				$_.PSTypeNames | Should -Contain 'SqlLabDataGenerator.PromptTemplate'
			}
		}

		It "Templates have required properties" {
			$templates = Get-SldgPromptTemplate
			$first = $templates | Select-Object -First 1
			$first.PSObject.Properties.Name | Should -Contain 'Purpose'
			$first.PSObject.Properties.Name | Should -Contain 'Variant'
			$first.PSObject.Properties.Name | Should -Contain 'Path'
			$first.PSObject.Properties.Name | Should -Contain 'IsCustom'
			$first.PSObject.Properties.Name | Should -Contain 'Placeholders'
		}

		It "Built-in templates are not flagged as custom" {
			$templates = Get-SldgPromptTemplate
			$templates | Where-Object { -not $_.IsCustom } | Should -Not -BeNullOrEmpty
		}

		It "Returns content with -IncludeContent" {
			$templates = Get-SldgPromptTemplate -IncludeContent
			$withContent = $templates | Where-Object { $_.Content }
			$withContent | Should -Not -BeNullOrEmpty
		}

		It "Filters by -Purpose" {
			$all = Get-SldgPromptTemplate
			$firstPurpose = ($all | Select-Object -First 1).Purpose
			$filtered = Get-SldgPromptTemplate -Purpose $firstPurpose
			$filtered | ForEach-Object { $_.Purpose | Should -Be $firstPurpose }
		}
	}

	Context "Set-SldgPromptTemplate - Parameter Validation" {
		It "Has mandatory Purpose parameter in Content set" {
			$cmd = Get-Command Set-SldgPromptTemplate
			$purposeParam = $cmd.Parameters['Purpose']
			$contentSetAttr = $purposeParam.Attributes.Where({
				$_ -is [System.Management.Automation.ParameterAttribute] -and $_.ParameterSetName -eq 'Content'
			})
			$contentSetAttr.Mandatory | Should -BeTrue
		}

		It "Has mandatory Content parameter" {
			$cmd = Get-Command Set-SldgPromptTemplate
			$cmd.Parameters.ContainsKey('Content') | Should -BeTrue
		}

		It "Has Force switch parameter" {
			$cmd = Get-Command Set-SldgPromptTemplate
			$cmd.Parameters.ContainsKey('Force') | Should -BeTrue
		}

		It "Supports ShouldProcess" {
			$cmd = Get-Command Set-SldgPromptTemplate
			$cmd.Parameters.ContainsKey('WhatIf') | Should -BeTrue
			$cmd.Parameters.ContainsKey('Confirm') | Should -BeTrue
		}
	}

	Context "Set-SldgPromptTemplate - Create and Overwrite" {
		It "Creates a custom prompt template" {
			Set-SldgPromptTemplate -Purpose 'test-purpose' -Variant 'default' -Content 'Test prompt {{Variable}}' -Force
			$result = Get-SldgPromptTemplate -Purpose 'test-purpose'
			$custom = $result | Where-Object { $_.IsCustom }
			$custom | Should -Not -BeNullOrEmpty
			$custom.Purpose | Should -Be 'test-purpose'
		}

		It "Custom template has correct variant" {
			$result = Get-SldgPromptTemplate -Purpose 'test-purpose'
			$custom = $result | Where-Object { $_.IsCustom }
			$custom.Variant | Should -Be 'default'
		}

		It "Detects placeholders in content" {
			$result = Get-SldgPromptTemplate -Purpose 'test-purpose' -IncludeContent
			$custom = $result | Where-Object { $_.IsCustom }
			$custom.Placeholders | Should -Contain 'Variable'
		}

		It "Overwrites existing template with -Force" {
			Set-SldgPromptTemplate -Purpose 'test-purpose' -Variant 'default' -Content 'Updated prompt {{NewVar}}' -Force
			$result = Get-SldgPromptTemplate -Purpose 'test-purpose' -IncludeContent
			$custom = $result | Where-Object { $_.IsCustom }
			$custom.Content | Should -Match 'Updated prompt'
		}

		It "Pipeline from Get-SldgPromptTemplate works" {
			$all = Get-SldgPromptTemplate -IncludeContent
			$first = $all | Select-Object -First 1
			if ($first.Content) {
				{ $first | Set-SldgPromptTemplate -Force } | Should -Not -Throw
			}
		}
	}

	Context "Remove-SldgPromptTemplate - Parameter Validation" {
		It "Has optional Purpose parameter" {
			$cmd = Get-Command Remove-SldgPromptTemplate
			$cmd.Parameters.ContainsKey('Purpose') | Should -BeTrue
		}

		It "Has optional Variant parameter" {
			$cmd = Get-Command Remove-SldgPromptTemplate
			$cmd.Parameters.ContainsKey('Variant') | Should -BeTrue
		}

		It "Supports ShouldProcess" {
			$cmd = Get-Command Remove-SldgPromptTemplate
			$cmd.Parameters.ContainsKey('WhatIf') | Should -BeTrue
			$cmd.Parameters.ContainsKey('Confirm') | Should -BeTrue
		}
	}

	Context "Remove-SldgPromptTemplate - Remove Custom Templates" {
		BeforeAll {
			# Create a template to remove
			Set-SldgPromptTemplate -Purpose 'removable-test' -Variant 'default' -Content 'Will be removed' -Force
		}

		It "Removes a custom template" {
			Remove-SldgPromptTemplate -Purpose 'removable-test' -Variant 'default' -Confirm:$false
			$result = Get-SldgPromptTemplate -Purpose 'removable-test'
			$custom = $result | Where-Object { $_.IsCustom }
			$custom | Should -BeNullOrEmpty
		}

		It "Warns on non-existent custom template" {
			# Should not throw, just warn
			{ Remove-SldgPromptTemplate -Purpose 'does-not-exist' -Variant 'default' -Confirm:$false -ErrorAction SilentlyContinue } | Should -Not -Throw
		}

		It "Skips built-in templates from pipeline" {
			$builtIn = Get-SldgPromptTemplate | Where-Object { -not $_.IsCustom } | Select-Object -First 1
			if ($builtIn) {
				{ $builtIn | Remove-SldgPromptTemplate -Confirm:$false } | Should -Not -Throw
				# Built-in should still exist
				$after = Get-SldgPromptTemplate -Purpose $builtIn.Purpose
				$after | Where-Object { -not $_.IsCustom } | Should -Not -BeNullOrEmpty
			}
		}
	}
}
