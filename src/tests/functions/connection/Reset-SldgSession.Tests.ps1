Describe "Reset-SldgSession" {
	BeforeAll {
		Remove-Module SqlLabDataGenerator -ErrorAction Ignore
		Import-Module "$PSScriptRoot\..\..\..\SqlLabDataGenerator\SqlLabDataGenerator.psd1" -Force
		$module = Get-Module SqlLabDataGenerator
	}

	Context "Parameter Validation" {
		It "Has Force switch parameter" {
			$cmd = Get-Command Reset-SldgSession
			$cmd.Parameters['Force'].SwitchParameter | Should -BeTrue
		}

		It "Supports ShouldProcess" {
			$cmd = Get-Command Reset-SldgSession
			$cmd.Parameters.Keys | Should -Contain 'WhatIf'
			$cmd.Parameters.Keys | Should -Contain 'Confirm'
		}

		It "Declares OutputType void" {
			$cmd = Get-Command Reset-SldgSession
			$outputTypes = $cmd.OutputType
			# void means either no OutputType or explicit void
			if ($outputTypes.Count -gt 0) {
				$outputTypes.Type.FullName | Should -Contain 'System.Void'
			}
		}
	}

	Context "Session Reset" {
		BeforeEach {
			# Seed some state to verify it gets cleared
			& $module {
				$script:SldgState.AIValueCache.TryAdd('test|key', @('v1', 'v2')) | Out-Null
			}
		}

		It "Clears AI caches with -Force" {
			$cacheBefore = & $module { $script:SldgState.AIValueCache.Count }
			$cacheBefore | Should -BeGreaterThan 0

			Reset-SldgSession -Force

			$cacheAfter = & $module { $script:SldgState.AIValueCache.Count }
			$cacheAfter | Should -Be 0
		}

		It "Clears providers on reset" {
			Reset-SldgSession -Force
			$providers = & $module { $script:SldgState.Providers.Count }
			$providers | Should -Be 0
		}

		It "Supports -WhatIf without modifying state" {
			& $module {
				$script:SldgState.AIValueCache.TryAdd('whatif|test', @('value')) | Out-Null
			}
			$countBefore = & $module { $script:SldgState.AIValueCache.Count }

			Reset-SldgSession -WhatIf

			$countAfter = & $module { $script:SldgState.AIValueCache.Count }
			$countAfter | Should -Be $countBefore
		}
	}

	AfterAll {
		# Re-import to restore module state for other tests
		Remove-Module SqlLabDataGenerator -ErrorAction Ignore
		Import-Module "$PSScriptRoot\..\..\..\SqlLabDataGenerator\SqlLabDataGenerator.psd1" -Force
	}
}
