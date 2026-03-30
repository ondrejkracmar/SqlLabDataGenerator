Describe "Clear-SldgCache" {
	BeforeAll {
		Remove-Module SqlLabDataGenerator -ErrorAction Ignore
		Import-Module "$PSScriptRoot\..\..\..\SqlLabDataGenerator\SqlLabDataGenerator.psd1" -Force
		$module = Get-Module SqlLabDataGenerator
	}

	Context "Parameter Validation" {
		It "Has no mandatory parameters" {
			$cmd = Get-Command Clear-SldgCache
			$mandatoryParams = $cmd.Parameters.Values | Where-Object {
				$_.Attributes.Where({ $_ -is [System.Management.Automation.ParameterAttribute] }).Mandatory -eq $true
			}
			$mandatoryParams | Should -BeNullOrEmpty
		}

		It "Has CacheName parameter with ValidateSet" {
			$cmd = Get-Command Clear-SldgCache
			$cmd.Parameters.Keys | Should -Contain 'CacheName'
			$validateSet = $cmd.Parameters['CacheName'].Attributes.Where({ $_ -is [System.Management.Automation.ValidateSetAttribute] })
			$validateSet.Count | Should -Be 1
			$validateSet.ValidValues | Should -Contain 'AIValueCache'
			$validateSet.ValidValues | Should -Contain 'AILocaleCache'
			$validateSet.ValidValues | Should -Contain 'AILocaleCategoryCache'
		}

		It "Declares OutputType void" {
			$cmd = Get-Command Clear-SldgCache
			$outputTypes = $cmd.OutputType
			if ($outputTypes.Count -gt 0) {
				$outputTypes.Type.FullName | Should -Contain 'System.Void'
			}
		}
	}

	Context "Clear All Caches" {
		BeforeEach {
			& $module {
				$script:SldgState.AIValueCache.TryAdd("test|val|$([Guid]::NewGuid())", @('a', 'b')) | Out-Null
				$script:SldgState.AILocaleCache.TryAdd("test|loc|$([Guid]::NewGuid())", @('c')) | Out-Null
				$script:SldgState.AILocaleCategoryCache.TryAdd("test|cat|$([Guid]::NewGuid())", @('d')) | Out-Null
			}
		}

		It "Clears all caches when no CacheName specified" {
			$totalBefore = & $module {
				$script:SldgState.AIValueCache.Count +
				$script:SldgState.AILocaleCache.Count +
				$script:SldgState.AILocaleCategoryCache.Count
			}
			$totalBefore | Should -BeGreaterThan 0

			Clear-SldgCache

			$totalAfter = & $module {
				$script:SldgState.AIValueCache.Count +
				$script:SldgState.AILocaleCache.Count +
				$script:SldgState.AILocaleCategoryCache.Count
			}
			$totalAfter | Should -Be 0
		}
	}

	Context "Clear Specific Cache" {
		BeforeEach {
			& $module {
				$script:SldgState.AIValueCache.TryAdd("spec|val|$([Guid]::NewGuid())", @('a')) | Out-Null
				$script:SldgState.AILocaleCache.TryAdd("spec|loc|$([Guid]::NewGuid())", @('b')) | Out-Null
			}
		}

		It "Clears only the AIValueCache when specified" {
			$localeBefore = & $module { $script:SldgState.AILocaleCache.Count }

			Clear-SldgCache -CacheName AIValueCache

			$valueAfter = & $module { $script:SldgState.AIValueCache.Count }
			$localeAfter = & $module { $script:SldgState.AILocaleCache.Count }
			$valueAfter | Should -Be 0
			$localeAfter | Should -Be $localeBefore
		}
	}

	Context "Preserves Non-Cache State" {
		It "Does not affect registered providers" {
			$providersBefore = & $module { @($script:SldgState.Providers.Keys) }
			Clear-SldgCache
			$providersAfter = & $module { @($script:SldgState.Providers.Keys) }
			$providersAfter.Count | Should -Be $providersBefore.Count
		}
	}
}
