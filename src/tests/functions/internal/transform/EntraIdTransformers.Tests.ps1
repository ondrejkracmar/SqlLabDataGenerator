Describe "Entra ID Transformers" {
	BeforeAll {
		Remove-Module SqlLabDataGenerator -ErrorAction Ignore
		Import-Module "$PSScriptRoot\..\..\..\..\SqlLabDataGenerator\SqlLabDataGenerator.psd1" -Force
		$module = Get-Module SqlLabDataGenerator

		# Build a test DataTable
		$script:testData = New-Object System.Data.DataTable
		[void]$script:testData.Columns.Add('FirstName', [string])
		[void]$script:testData.Columns.Add('LastName', [string])
		[void]$script:testData.Columns.Add('Email', [string])
		[void]$script:testData.Columns.Add('Phone', [string])
		[void]$script:testData.Columns.Add('JobTitle', [string])
		[void]$script:testData.Columns.Add('Department', [string])
		[void]$script:testData.Columns.Add('City', [string])
		[void]$script:testData.Columns.Add('GroupName', [string])
		[void]$script:testData.Columns.Add('Description', [string])

		$row1 = $script:testData.NewRow()
		$row1['FirstName'] = 'John'
		$row1['LastName'] = 'Doe'
		$row1['Email'] = 'john.doe@test.com'
		$row1['Phone'] = '+1234567890'
		$row1['JobTitle'] = 'Developer'
		$row1['Department'] = 'Engineering'
		$row1['City'] = 'Seattle'
		$row1['GroupName'] = 'Engineering Team'
		$row1['Description'] = 'Main engineering group'
		$script:testData.Rows.Add($row1)

		$row2 = $script:testData.NewRow()
		$row2['FirstName'] = 'Jane'
		$row2['LastName'] = 'Smith'
		$row2['Email'] = 'jane.smith@test.com'
		$row2['Phone'] = '+0987654321'
		$row2['JobTitle'] = 'Manager'
		$row2['Department'] = 'Management'
		$row2['City'] = 'Portland'
		$row2['GroupName'] = 'Management Team'
		$row2['Description'] = 'Main management group'
		$script:testData.Rows.Add($row2)
	}

	Context "ConvertTo-SldgEntraIdUser" {
		It "Converts DataTable rows to Entra ID user objects" {
			$users = & $module {
				param($data)
				ConvertTo-SldgEntraIdUser -Data $data -Domain 'test.onmicrosoft.com'
			} $script:testData

			$users.Count | Should -Be 2
		}

		It "Auto-detects column mappings" {
			$users = & $module {
				param($data)
				ConvertTo-SldgEntraIdUser -Data $data -Domain 'test.onmicrosoft.com'
			} $script:testData

			$users[0].givenName | Should -Be 'John'
			$users[0].surname | Should -Be 'Doe'
			$users[0].displayName | Should -Be 'John Doe'
		}

		It "Generates valid UPN from name" {
			$users = & $module {
				param($data)
				ConvertTo-SldgEntraIdUser -Data $data -Domain 'test.onmicrosoft.com'
			} $script:testData

			$users[0].userPrincipalName | Should -Be 'john.doe@test.onmicrosoft.com'
			$users[1].userPrincipalName | Should -Be 'jane.smith@test.onmicrosoft.com'
		}

		It "Sets accountEnabled to true" {
			$users = & $module {
				param($data)
				ConvertTo-SldgEntraIdUser -Data $data -Domain 'test.onmicrosoft.com'
			} $script:testData

			$users[0].accountEnabled | Should -BeTrue
		}

		It "Generates password profile" {
			$users = & $module {
				param($data)
				ConvertTo-SldgEntraIdUser -Data $data -Domain 'test.onmicrosoft.com'
			} $script:testData

			$users[0].passwordProfile | Should -Not -BeNullOrEmpty
			$users[0].passwordProfile.forceChangePasswordNextSignIn | Should -BeTrue
			$users[0].passwordProfile.password | Should -Not -BeNullOrEmpty
		}

		It "Uses custom default password when provided" {
			$users = & $module {
				param($data)
				ConvertTo-SldgEntraIdUser -Data $data -Domain 'test.onmicrosoft.com' -DefaultPassword 'TestP@ss123!'
			} $script:testData

			$users[0].passwordProfile.password | Should -Be 'TestP@ss123!'
		}

		It "Maps optional properties from auto-detected columns" {
			$users = & $module {
				param($data)
				ConvertTo-SldgEntraIdUser -Data $data -Domain 'test.onmicrosoft.com'
			} $script:testData

			$users[0].mail | Should -Be 'john.doe@test.com'
			$users[0].mobilePhone | Should -Be '+1234567890'
			$users[0].jobTitle | Should -Be 'Developer'
			$users[0].department | Should -Be 'Engineering'
			$users[0].city | Should -Be 'Seattle'
		}

		It "Respects explicit column mapping" {
			$mapping = @{
				'givenName' = 'FirstName'
				'surname'   = 'LastName'
			}
			$users = & $module {
				param($data, $map)
				ConvertTo-SldgEntraIdUser -Data $data -ColumnMapping $map -Domain 'custom.com'
			} $script:testData $mapping

			$users[0].givenName | Should -Be 'John'
			$users[0].surname | Should -Be 'Doe'
		}

		It "Sets usageLocation from parameter" {
			$users = & $module {
				param($data)
				ConvertTo-SldgEntraIdUser -Data $data -UsageLocation 'CZ'
			} $script:testData

			$users[0].usageLocation | Should -Be 'CZ'
		}

		It "Generates mailNickname from UPN" {
			$users = & $module {
				param($data)
				ConvertTo-SldgEntraIdUser -Data $data
			} $script:testData

			$users[0].mailNickname | Should -Not -BeNullOrEmpty
			$users[0].mailNickname | Should -Not -Match '@'
		}
	}

	Context "ConvertTo-SldgEntraIdGroup" {
		It "Converts DataTable rows to Entra ID group objects" {
			$groups = & $module {
				param($data)
				ConvertTo-SldgEntraIdGroup -Data $data
			} $script:testData

			$groups.Count | Should -Be 2
		}

		It "Auto-detects group name from columns" {
			$groups = & $module {
				param($data)
				ConvertTo-SldgEntraIdGroup -Data $data
			} $script:testData

			# Should match one of the name-like columns
			$groups[0].displayName | Should -Not -BeNullOrEmpty
		}

		It "Creates Security group by default" {
			$groups = & $module {
				param($data)
				ConvertTo-SldgEntraIdGroup -Data $data -GroupType 'Security'
			} $script:testData

			$groups[0].securityEnabled | Should -BeTrue
			$groups[0].mailEnabled | Should -BeFalse
		}

		It "Creates Microsoft365 group with correct properties" {
			$groups = & $module {
				param($data)
				ConvertTo-SldgEntraIdGroup -Data $data -GroupType 'Microsoft365'
			} $script:testData

			$groups[0].securityEnabled | Should -BeTrue
			$groups[0].mailEnabled | Should -BeTrue
			$groups[0].groupTypes | Should -Contain 'Unified'
		}

		It "Creates DistributionList group" {
			$groups = & $module {
				param($data)
				ConvertTo-SldgEntraIdGroup -Data $data -GroupType 'DistributionList'
			} $script:testData

			$groups[0].mailEnabled | Should -BeTrue
			$groups[0].securityEnabled | Should -BeFalse
		}

		It "Generates mailNickname from displayName" {
			$groups = & $module {
				param($data)
				ConvertTo-SldgEntraIdGroup -Data $data
			} $script:testData

			$groups[0].mailNickname | Should -Not -BeNullOrEmpty
			$groups[0].mailNickname | Should -Match '^[a-z0-9]+$'
		}

		It "Respects explicit column mapping" {
			$mapping = @{
				'displayName'  = 'GroupName'
				'description'  = 'Description'
				'department'   = 'Department'
			}
			$groups = & $module {
				param($data, $map)
				ConvertTo-SldgEntraIdGroup -Data $data -ColumnMapping $map
			} $script:testData $mapping

			$groups[0].displayName | Should -Be 'Engineering Team'
			$groups[0].Description | Should -Be 'Main engineering group'
			$groups[0].Department | Should -Be 'Engineering'
		}
	}
}
