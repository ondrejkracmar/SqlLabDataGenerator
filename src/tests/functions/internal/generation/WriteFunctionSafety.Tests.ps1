Describe "Write Functions - Safety and Disposal" {
	BeforeAll {
		Remove-Module SqlLabDataGenerator -ErrorAction Ignore
		Import-Module "$PSScriptRoot\..\..\..\..\SqlLabDataGenerator\SqlLabDataGenerator.psd1" -Force
		$module = Get-Module SqlLabDataGenerator
	}

	Context "Write-SldgSqlServerData - Disposal Pattern" {
		It "Function exists" {
			& $module { Get-Command Write-SldgSqlServerData -ErrorAction SilentlyContinue } | Should -Not -BeNullOrEmpty
		}

		It "Source uses try/finally for BulkCopy disposal" {
			$source = & $module { (Get-Command Write-SldgSqlServerData).ScriptBlock.ToString() }
			$source | Should -Match 'try'
			$source | Should -Match 'finally'
			$source | Should -Match 'bulkCopy'
		}

		It "Source initializes BulkCopy to null before try block" {
			$source = & $module { (Get-Command Write-SldgSqlServerData).ScriptBlock.ToString() }
			$source | Should -Match '\$bulkCopy\s*=\s*\$null'
		}

		It "Source disposes command objects in finally blocks" {
			$source = & $module { (Get-Command Write-SldgSqlServerData).ScriptBlock.ToString() }
			$source | Should -Match '\.Dispose\(\)'
		}

		It "Source handles IDENTITY_INSERT cleanup in finally" {
			$source = & $module { (Get-Command Write-SldgSqlServerData).ScriptBlock.ToString() }
			$source | Should -Match 'IDENTITY_INSERT'
		}
	}

	Context "Write-SldgSqliteData - Named Constants" {
		It "Function exists" {
			& $module { Get-Command Write-SldgSqliteData -ErrorAction SilentlyContinue } | Should -Not -BeNullOrEmpty
		}

		It "Source uses named constant for max variables" {
			$source = & $module { (Get-Command Write-SldgSqliteData).ScriptBlock.ToString() }
			$source | Should -Match 'SQLITE_MAX_VARIABLES'
		}

		It "SQLITE_MAX_VARIABLES is set to 999" {
			$source = & $module { (Get-Command Write-SldgSqliteData).ScriptBlock.ToString() }
			$source | Should -Match 'SQLITE_MAX_VARIABLES\s*=\s*999'
		}
	}
}
