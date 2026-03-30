Describe "ConvertTo-SldgTableInfo" {
	BeforeAll {
		Remove-Module SqlLabDataGenerator -ErrorAction Ignore
		Import-Module "$PSScriptRoot\..\..\..\..\SqlLabDataGenerator\SqlLabDataGenerator.psd1" -Force
		$module = Get-Module SqlLabDataGenerator
	}

	Context "Basic Conversion" {
		It "Converts a simple table plan with schema, table, and columns" {
			$plan = [PSCustomObject]@{
				SchemaName  = 'dbo'
				TableName   = 'Users'
				FullName    = 'dbo.Users'
				ForeignKeys = @()
				Columns     = @(
					[PSCustomObject]@{
						ColumnName   = 'Id'
						DataType     = 'int'
						SemanticType = 'Integer'
						IsIdentity   = $true
						IsComputed   = $false
						IsPrimaryKey = $true
						IsUnique     = $true
						IsNullable   = $false
						MaxLength    = 4
						ForeignKey   = $null
						SchemaHint   = $null
						IsPII        = $false
						CustomRule   = $null
					}
					[PSCustomObject]@{
						ColumnName   = 'Name'
						DataType     = 'nvarchar'
						SemanticType = 'FullName'
						IsIdentity   = $false
						IsComputed   = $false
						IsPrimaryKey = $false
						IsUnique     = $false
						IsNullable   = $true
						MaxLength    = 100
						ForeignKey   = $null
						SchemaHint   = $null
						IsPII        = $true
						CustomRule   = $null
					}
				)
			}

			$result = & $module { param($p) ConvertTo-SldgTableInfo -TablePlan $p } $plan

			$result.SchemaName | Should -Be 'dbo'
			$result.TableName | Should -Be 'Users'
			$result.FullName | Should -Be 'dbo.Users'
			$result.Columns.Count | Should -Be 2
		}

		It "Maps column properties correctly" {
			$plan = [PSCustomObject]@{
				SchemaName  = 'dbo'
				TableName   = 'T'
				FullName    = 'dbo.T'
				ForeignKeys = @()
				Columns     = @(
					[PSCustomObject]@{
						ColumnName   = 'Col1'
						DataType     = 'nvarchar'
						SemanticType = 'Text'
						IsIdentity   = $false
						IsComputed   = $false
						IsPrimaryKey = $false
						IsUnique     = $true
						IsNullable   = $false
						MaxLength    = 50
						ForeignKey   = $null
						SchemaHint   = 'some hint'
						IsPII        = $false
						CustomRule   = @{ ValueList = @('A','B') }
					}
				)
			}

			$result = & $module { param($p) ConvertTo-SldgTableInfo -TablePlan $p } $plan
			$col = $result.Columns[0]

			$col.ColumnName | Should -Be 'Col1'
			$col.DataType | Should -Be 'nvarchar'
			$col.SemanticType | Should -Be 'Text'
			$col.IsIdentity | Should -BeFalse
			$col.IsComputed | Should -BeFalse
			$col.IsPrimaryKey | Should -BeFalse
			$col.IsUnique | Should -BeTrue
			$col.IsNullable | Should -BeFalse
			$col.MaxLength | Should -Be 50
			$col.SchemaHint | Should -Be 'some hint'
			$col.Classification.SemanticType | Should -Be 'Text'
			$col.Classification.IsPII | Should -BeFalse
			$col.GenerationRule.ValueList | Should -Be @('A','B')
		}

		It "Defaults IsNullable to true when source is null" {
			$plan = [PSCustomObject]@{
				SchemaName  = 'dbo'
				TableName   = 'T'
				FullName    = 'dbo.T'
				ForeignKeys = @()
				Columns     = @(
					[PSCustomObject]@{
						ColumnName   = 'Col1'
						DataType     = 'int'
						SemanticType = 'Integer'
						IsIdentity   = $false
						IsComputed   = $false
						IsPrimaryKey = $false
						IsUnique     = $false
						IsNullable   = $null
						MaxLength    = $null
						ForeignKey   = $null
						SchemaHint   = $null
						IsPII        = $false
						CustomRule   = $null
					}
				)
			}

			$result = & $module { param($p) ConvertTo-SldgTableInfo -TablePlan $p } $plan
			$result.Columns[0].IsNullable | Should -BeTrue
		}
	}

	Context "Foreign Key Cross-Reference" {
		It "Preserves column-level FK when already set" {
			$colFK = [PSCustomObject]@{
				ReferencedSchema = 'dbo'
				ReferencedTable  = 'Parent'
				ReferencedColumn = 'Id'
			}
			$plan = [PSCustomObject]@{
				SchemaName  = 'dbo'
				TableName   = 'Child'
				FullName    = 'dbo.Child'
				ForeignKeys = @()
				Columns     = @(
					[PSCustomObject]@{
						ColumnName   = 'ParentId'
						DataType     = 'int'
						SemanticType = 'Integer'
						IsIdentity   = $false
						IsComputed   = $false
						IsPrimaryKey = $false
						IsUnique     = $false
						IsNullable   = $false
						MaxLength    = 4
						ForeignKey   = $colFK
						SchemaHint   = $null
						IsPII        = $false
						CustomRule   = $null
					}
				)
			}

			$result = & $module { param($p) ConvertTo-SldgTableInfo -TablePlan $p } $plan
			$result.Columns[0].ForeignKey.ReferencedTable | Should -Be 'Parent'
			$result.Columns[0].ForeignKey.ReferencedColumn | Should -Be 'Id'
		}

		It "Sets FK from table-level ForeignKeys when column FK is null" {
			$plan = [PSCustomObject]@{
				SchemaName  = 'dbo'
				TableName   = 'Child'
				FullName    = 'dbo.Child'
				ForeignKeys = @(
					[PSCustomObject]@{
						ParentColumn     = 'CategoryId'
						ReferencedSchema = 'dbo'
						ReferencedTable  = 'Category'
						ReferencedColumn = 'Id'
					}
				)
				Columns     = @(
					[PSCustomObject]@{
						ColumnName   = 'CategoryId'
						DataType     = 'int'
						SemanticType = 'Integer'
						IsIdentity   = $false
						IsComputed   = $false
						IsPrimaryKey = $false
						IsUnique     = $false
						IsNullable   = $false
						MaxLength    = 4
						ForeignKey   = $null
						SchemaHint   = $null
						IsPII        = $false
						CustomRule   = $null
					}
				)
			}

			$result = & $module { param($p) ConvertTo-SldgTableInfo -TablePlan $p } $plan
			$result.Columns[0].ForeignKey | Should -Not -BeNullOrEmpty
			$result.Columns[0].ForeignKey.ReferencedSchema | Should -Be 'dbo'
			$result.Columns[0].ForeignKey.ReferencedTable | Should -Be 'Category'
			$result.Columns[0].ForeignKey.ReferencedColumn | Should -Be 'Id'
		}

		It "Does not set FK for columns not matching any table-level FK" {
			$plan = [PSCustomObject]@{
				SchemaName  = 'dbo'
				TableName   = 'Child'
				FullName    = 'dbo.Child'
				ForeignKeys = @(
					[PSCustomObject]@{
						ParentColumn     = 'CategoryId'
						ReferencedSchema = 'dbo'
						ReferencedTable  = 'Category'
						ReferencedColumn = 'Id'
					}
				)
				Columns     = @(
					[PSCustomObject]@{
						ColumnName   = 'Name'
						DataType     = 'nvarchar'
						SemanticType = 'Text'
						IsIdentity   = $false
						IsComputed   = $false
						IsPrimaryKey = $false
						IsUnique     = $false
						IsNullable   = $true
						MaxLength    = 50
						ForeignKey   = $null
						SchemaHint   = $null
						IsPII        = $false
						CustomRule   = $null
					}
				)
			}

			$result = & $module { param($p) ConvertTo-SldgTableInfo -TablePlan $p } $plan
			$result.Columns[0].ForeignKey | Should -BeNullOrEmpty
		}

		It "Passes through table-level ForeignKeys property" {
			$fks = @(
				[PSCustomObject]@{ ParentColumn = 'CatId'; ReferencedSchema = 'dbo'; ReferencedTable = 'Cat'; ReferencedColumn = 'Id' }
			)
			$plan = [PSCustomObject]@{
				SchemaName  = 'dbo'
				TableName   = 'T'
				FullName    = 'dbo.T'
				ForeignKeys = $fks
				Columns     = @()
			}

			$result = & $module { param($p) ConvertTo-SldgTableInfo -TablePlan $p } $plan
			$result.ForeignKeys.Count | Should -Be 1
			$result.ForeignKeys[0].ParentColumn | Should -Be 'CatId'
		}
	}
}
