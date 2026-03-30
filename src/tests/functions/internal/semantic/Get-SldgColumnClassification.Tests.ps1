Describe "Get-SldgColumnClassification" {
	BeforeAll {
		Remove-Module SqlLabDataGenerator -ErrorAction Ignore
		Import-Module "$PSScriptRoot\..\..\..\..\SqlLabDataGenerator\SqlLabDataGenerator.psd1" -Force
		$module = Get-Module SqlLabDataGenerator
	}

	Context "Person Name Patterns" {
		It "Classifies 'FirstName' as FirstName PII" {
			$col = [PSCustomObject]@{ ColumnName = 'FirstName'; DataType = 'nvarchar'; MaxLength = 50; IsNullable = $false }
			$result = & $module { param($c) Get-SldgColumnClassification -Column $c -TableName 'dbo.Person' } $col
			$result.SemanticType | Should -Be 'FirstName'
			$result.IsPII | Should -BeTrue
			$result.Source | Should -Be 'PatternMatch'
		}

		It "Classifies 'LastName' as LastName PII" {
			$col = [PSCustomObject]@{ ColumnName = 'LastName'; DataType = 'nvarchar'; MaxLength = 50; IsNullable = $false }
			$result = & $module { param($c) Get-SldgColumnClassification -Column $c -TableName 'dbo.Person' } $col
			$result.SemanticType | Should -Be 'LastName'
			$result.IsPII | Should -BeTrue
		}

		It "Classifies 'DisplayName' as FullName" {
			$col = [PSCustomObject]@{ ColumnName = 'DisplayName'; DataType = 'nvarchar'; MaxLength = 100; IsNullable = $false }
			$result = & $module { param($c) Get-SldgColumnClassification -Column $c -TableName 'dbo.Person' } $col
			$result.SemanticType | Should -Be 'FullName'
		}
	}

	Context "Contact Patterns" {
		It "Classifies 'Email' as Email" {
			$col = [PSCustomObject]@{ ColumnName = 'Email'; DataType = 'nvarchar'; MaxLength = 100; IsNullable = $true }
			$result = & $module { param($c) Get-SldgColumnClassification -Column $c -TableName 'dbo.Person' } $col
			$result.SemanticType | Should -Be 'Email'
			$result.IsPII | Should -BeTrue
		}

		It "Classifies 'PhoneNumber' as Phone" {
			$col = [PSCustomObject]@{ ColumnName = 'PhoneNumber'; DataType = 'nvarchar'; MaxLength = 20; IsNullable = $true }
			$result = & $module { param($c) Get-SldgColumnClassification -Column $c -TableName 'dbo.Person' } $col
			$result.SemanticType | Should -Be 'Phone'
			$result.IsPII | Should -BeTrue
		}
	}

	Context "Address Patterns" {
		It "Classifies 'City' as City" {
			$col = [PSCustomObject]@{ ColumnName = 'City'; DataType = 'nvarchar'; MaxLength = 50; IsNullable = $true }
			$result = & $module { param($c) Get-SldgColumnClassification -Column $c -TableName 'dbo.Address' } $col
			$result.SemanticType | Should -Be 'City'
			$result.IsPII | Should -BeFalse
		}

		It "Classifies 'ZipCode' as ZipCode PII" {
			$col = [PSCustomObject]@{ ColumnName = 'ZipCode'; DataType = 'varchar'; MaxLength = 10; IsNullable = $true }
			$result = & $module { param($c) Get-SldgColumnClassification -Column $c -TableName 'dbo.Address' } $col
			$result.SemanticType | Should -Be 'ZipCode'
		}
	}

	Context "Financial Patterns" {
		It "Classifies 'TotalAmount' as Money" {
			$col = [PSCustomObject]@{ ColumnName = 'TotalAmount'; DataType = 'decimal'; MaxLength = $null; IsNullable = $false }
			$result = & $module { param($c) Get-SldgColumnClassification -Column $c -TableName 'dbo.Order' } $col
			$result.SemanticType | Should -Be 'Money'
			$result.IsPII | Should -BeFalse
		}

		It "Classifies 'IBAN' as IBAN PII" {
			$col = [PSCustomObject]@{ ColumnName = 'IBAN'; DataType = 'varchar'; MaxLength = 34; IsNullable = $true }
			$result = & $module { param($c) Get-SldgColumnClassification -Column $c -TableName 'dbo.BankAccount' } $col
			$result.SemanticType | Should -Be 'IBAN'
			$result.IsPII | Should -BeTrue
		}
	}

	Context "Date Patterns" {
		It "Classifies 'DateOfBirth' as BirthDate PII" {
			$col = [PSCustomObject]@{ ColumnName = 'DateOfBirth'; DataType = 'date'; MaxLength = $null; IsNullable = $true }
			$result = & $module { param($c) Get-SldgColumnClassification -Column $c -TableName 'dbo.Person' } $col
			$result.SemanticType | Should -Be 'BirthDate'
			$result.IsPII | Should -BeTrue
		}

		It "Classifies 'CreatedAt' as Timestamp" {
			$col = [PSCustomObject]@{ ColumnName = 'CreatedAt'; DataType = 'datetime2'; MaxLength = $null; IsNullable = $false }
			$result = & $module { param($c) Get-SldgColumnClassification -Column $c -TableName 'dbo.Any' } $col
			$result.SemanticType | Should -Be 'Timestamp'
			$result.IsPII | Should -BeFalse
		}

		It "Classifies 'OrderDate' as PastDate" {
			$col = [PSCustomObject]@{ ColumnName = 'OrderDate'; DataType = 'datetime'; MaxLength = $null; IsNullable = $false }
			$result = & $module { param($c) Get-SldgColumnClassification -Column $c -TableName 'dbo.Order' } $col
			$result.SemanticType | Should -Be 'PastDate'
		}
	}

	Context "Business Patterns" {
		It "Classifies 'CompanyName' as CompanyName" {
			$col = [PSCustomObject]@{ ColumnName = 'CompanyName'; DataType = 'nvarchar'; MaxLength = 100; IsNullable = $true }
			$result = & $module { param($c) Get-SldgColumnClassification -Column $c -TableName 'dbo.Vendor' } $col
			$result.SemanticType | Should -Be 'CompanyName'
		}

		It "Classifies 'Status' as Status" {
			$col = [PSCustomObject]@{ ColumnName = 'Status'; DataType = 'nvarchar'; MaxLength = 20; IsNullable = $false }
			$result = & $module { param($c) Get-SldgColumnClassification -Column $c -TableName 'dbo.Order' } $col
			$result.SemanticType | Should -Be 'Status'
		}

		It "Classifies 'IsActive' as Boolean" {
			$col = [PSCustomObject]@{ ColumnName = 'IsActive'; DataType = 'bit'; MaxLength = $null; IsNullable = $false }
			$result = & $module { param($c) Get-SldgColumnClassification -Column $c -TableName 'dbo.User' } $col
			$result.SemanticType | Should -Be 'Boolean'
		}
	}

	Context "Czech Column Names" {
		It "Classifies 'rodne_cislo' as NationalId" {
			$col = [PSCustomObject]@{ ColumnName = 'rodne_cislo'; DataType = 'varchar'; MaxLength = 11; IsNullable = $true }
			$result = & $module { param($c) Get-SldgColumnClassification -Column $c -TableName 'dbo.Osoba' } $col
			$result.SemanticType | Should -Be 'NationalId'
			$result.IsPII | Should -BeTrue
		}

		It "Classifies 'datum_narozeni' as BirthDate" {
			$col = [PSCustomObject]@{ ColumnName = 'datum_narozeni'; DataType = 'date'; MaxLength = $null; IsNullable = $true }
			$result = & $module { param($c) Get-SldgColumnClassification -Column $c -TableName 'dbo.Osoba' } $col
			$result.SemanticType | Should -Be 'BirthDate'
		}
	}

	Context "FK-Aware Classification" {
		It "Classifies FK int column with Source ForeignKey" {
			$col = [PSCustomObject]@{
				ColumnName = 'CustomerID'
				DataType   = 'int'
				MaxLength  = $null
				IsNullable = $false
				ForeignKey = [PSCustomObject]@{ ReferencedTable = 'dbo.Customer'; ReferencedColumn = 'CustomerID' }
			}
			$result = & $module { param($c) Get-SldgColumnClassification -Column $c -TableName 'dbo.Order' } $col
			$result.Source | Should -Be 'ForeignKey'
			$result.SemanticType | Should -Be 'Integer'
			$result.IsPII | Should -BeFalse
			$result.Confidence | Should -Be 0.95
			$result.MatchedRule | Should -Be 'FK -> dbo.Customer.CustomerID'
		}

		It "Classifies FK uniqueidentifier column as Guid" {
			$col = [PSCustomObject]@{
				ColumnName = 'TenantId'
				DataType   = 'uniqueidentifier'
				MaxLength  = $null
				IsNullable = $false
				ForeignKey = [PSCustomObject]@{ ReferencedTable = 'dbo.Tenant'; ReferencedColumn = 'TenantId' }
			}
			$result = & $module { param($c) Get-SldgColumnClassification -Column $c -TableName 'dbo.User' } $col
			$result.Source | Should -Be 'ForeignKey'
			$result.SemanticType | Should -Be 'Guid'
		}

		It "FK classification takes precedence over pattern match" {
			$col = [PSCustomObject]@{
				ColumnName = 'Email'
				DataType   = 'int'
				MaxLength  = $null
				IsNullable = $false
				ForeignKey = [PSCustomObject]@{ ReferencedTable = 'dbo.EmailType'; ReferencedColumn = 'Id' }
			}
			$result = & $module { param($c) Get-SldgColumnClassification -Column $c -TableName 'dbo.Contact' } $col
			$result.Source | Should -Be 'ForeignKey'
			$result.SemanticType | Should -Be 'Integer'
		}
	}

	Context "Table Context Disambiguation - Name" {
		It "Classifies 'Name' in Person table as FullName PII" {
			$col = [PSCustomObject]@{ ColumnName = 'Name'; DataType = 'nvarchar'; MaxLength = 100; IsNullable = $false }
			$result = & $module { param($c) Get-SldgColumnClassification -Column $c -TableName 'dbo.Person' } $col
			$result.SemanticType | Should -Be 'FullName'
			$result.IsPII | Should -BeTrue
			$result.Source | Should -Be 'TableContext'
		}

		It "Classifies 'Name' in Customer table as FullName PII" {
			$col = [PSCustomObject]@{ ColumnName = 'Name'; DataType = 'nvarchar'; MaxLength = 100; IsNullable = $false }
			$result = & $module { param($c) Get-SldgColumnClassification -Column $c -TableName 'dbo.Customer' } $col
			$result.SemanticType | Should -Be 'FullName'
			$result.IsPII | Should -BeTrue
			$result.Source | Should -Be 'TableContext'
		}

		It "Classifies 'Name' in Company table as CompanyName" {
			$col = [PSCustomObject]@{ ColumnName = 'Name'; DataType = 'nvarchar'; MaxLength = 100; IsNullable = $false }
			$result = & $module { param($c) Get-SldgColumnClassification -Column $c -TableName 'dbo.Company' } $col
			$result.SemanticType | Should -Be 'CompanyName'
			$result.IsPII | Should -BeFalse
			$result.Source | Should -Be 'TableContext'
		}

		It "Classifies 'Name' in Vendor table as CompanyName" {
			$col = [PSCustomObject]@{ ColumnName = 'Name'; DataType = 'nvarchar'; MaxLength = 100; IsNullable = $false }
			$result = & $module { param($c) Get-SldgColumnClassification -Column $c -TableName 'Purchasing.Vendor' } $col
			$result.SemanticType | Should -Be 'CompanyName'
			$result.Source | Should -Be 'TableContext'
		}

		It "Classifies 'Name' in Product table as Text" {
			$col = [PSCustomObject]@{ ColumnName = 'Name'; DataType = 'nvarchar'; MaxLength = 100; IsNullable = $false }
			$result = & $module { param($c) Get-SldgColumnClassification -Column $c -TableName 'dbo.Product' } $col
			$result.SemanticType | Should -Be 'Text'
			$result.IsPII | Should -BeFalse
			$result.Source | Should -Be 'TableContext'
		}

		It "Classifies 'Name' in Category table as Text" {
			$col = [PSCustomObject]@{ ColumnName = 'Name'; DataType = 'nvarchar'; MaxLength = 50; IsNullable = $false }
			$result = & $module { param($c) Get-SldgColumnClassification -Column $c -TableName 'dbo.Category' } $col
			$result.SemanticType | Should -Be 'Text'
			$result.IsPII | Should -BeFalse
			$result.Source | Should -Be 'TableContext'
		}

		It "Classifies 'Name' in unknown table as Text (default)" {
			$col = [PSCustomObject]@{ ColumnName = 'Name'; DataType = 'nvarchar'; MaxLength = 100; IsNullable = $false }
			$result = & $module { param($c) Get-SldgColumnClassification -Column $c -TableName 'dbo.Widget' } $col
			$result.SemanticType | Should -Be 'Text'
			$result.IsPII | Should -BeFalse
		}
	}

	Context "Table Context Disambiguation - Title" {
		It "Classifies 'Title' in Person table as JobTitle" {
			$col = [PSCustomObject]@{ ColumnName = 'Title'; DataType = 'nvarchar'; MaxLength = 50; IsNullable = $true }
			$result = & $module { param($c) Get-SldgColumnClassification -Column $c -TableName 'dbo.Employee' } $col
			$result.SemanticType | Should -Be 'JobTitle'
			$result.Source | Should -Be 'TableContext'
		}

		It "Classifies 'Title' in non-person table as Text" {
			$col = [PSCustomObject]@{ ColumnName = 'Title'; DataType = 'nvarchar'; MaxLength = 200; IsNullable = $false }
			$result = & $module { param($c) Get-SldgColumnClassification -Column $c -TableName 'dbo.Document' } $col
			$result.SemanticType | Should -Be 'Text'
			$result.Source | Should -Be 'TableContext'
		}
	}

	Context "Table Context Disambiguation - Number" {
		It "Classifies 'Number' in Order table as BusinessNumber" {
			$col = [PSCustomObject]@{ ColumnName = 'Number'; DataType = 'nvarchar'; MaxLength = 20; IsNullable = $false }
			$result = & $module { param($c) Get-SldgColumnClassification -Column $c -TableName 'dbo.Order' } $col
			$result.SemanticType | Should -Be 'BusinessNumber'
			$result.Source | Should -Be 'TableContext'
		}

		It "Classifies 'Number' in Person table as Phone" {
			$col = [PSCustomObject]@{ ColumnName = 'Number'; DataType = 'nvarchar'; MaxLength = 20; IsNullable = $true }
			$result = & $module { param($c) Get-SldgColumnClassification -Column $c -TableName 'dbo.Contact' } $col
			$result.SemanticType | Should -Be 'Phone'
			$result.IsPII | Should -BeTrue
			$result.Source | Should -Be 'TableContext'
		}

		It "Classifies 'Number' in generic table as Code" {
			$col = [PSCustomObject]@{ ColumnName = 'Number'; DataType = 'nvarchar'; MaxLength = 20; IsNullable = $false }
			$result = & $module { param($c) Get-SldgColumnClassification -Column $c -TableName 'dbo.Widget' } $col
			$result.SemanticType | Should -Be 'Code'
			$result.Source | Should -Be 'TableContext'
		}
	}

	Context "Table Context Disambiguation - Code" {
		It "Classifies 'Code' in Category table as Code" {
			$col = [PSCustomObject]@{ ColumnName = 'Code'; DataType = 'varchar'; MaxLength = 10; IsNullable = $false }
			$result = & $module { param($c) Get-SldgColumnClassification -Column $c -TableName 'dbo.Category' } $col
			$result.SemanticType | Should -Be 'Code'
			$result.Source | Should -Be 'TableContext'
		}
	}

	Context "DataType Fallback" {
		It "Falls back to DataTypeInference for unrecognized column names" {
			$col = [PSCustomObject]@{ ColumnName = 'xyzabc123'; DataType = 'int'; MaxLength = $null; IsNullable = $false }
			$result = & $module { param($c) Get-SldgColumnClassification -Column $c -TableName 'dbo.Test' } $col
			$result.Source | Should -Be 'DataTypeInference'
			$result.Confidence | Should -BeLessThan 0.5
		}
	}

	Context "Output Type" {
		It "Returns ColumnClassification typed object" {
			$col = [PSCustomObject]@{ ColumnName = 'Email'; DataType = 'nvarchar'; MaxLength = 100; IsNullable = $true }
			$result = & $module { param($c) Get-SldgColumnClassification -Column $c -TableName 'dbo.T' } $col
			$result.PSObject.TypeNames | Should -Contain 'SqlLabDataGenerator.ColumnClassification'
		}
	}
}
