Describe "Invoke-SldgStreamingGeneration" {
	BeforeAll {
		Remove-Module SqlLabDataGenerator -ErrorAction Ignore
		Import-Module "$PSScriptRoot\..\..\..\..\SqlLabDataGenerator\SqlLabDataGenerator.psd1" -Force
		$module = Get-Module SqlLabDataGenerator

		# Helper: build a minimal table info object for testing
		$script:buildTableInfo = {
			param ([int]$colCount = 3)
			$cols = @(
				[PSCustomObject]@{
					ColumnName     = 'Id'
					DataType       = 'int'
					SemanticType   = $null
					IsIdentity     = $true
					IsComputed     = $false
					IsPrimaryKey   = $true
					IsUnique       = $true
					IsNullable     = $false
					MaxLength      = $null
					ForeignKey     = $null
					SchemaHint     = $null
					Classification = [PSCustomObject]@{ SemanticType = $null; IsPII = $false }
					GenerationRule = $null
				}
				[PSCustomObject]@{
					ColumnName     = 'Name'
					DataType       = 'nvarchar'
					SemanticType   = 'PersonFirstName'
					IsIdentity     = $false
					IsComputed     = $false
					IsPrimaryKey   = $false
					IsUnique       = $false
					IsNullable     = $false
					MaxLength      = 100
					ForeignKey     = $null
					SchemaHint     = $null
					Classification = [PSCustomObject]@{ SemanticType = 'PersonFirstName'; IsPII = $true }
					GenerationRule = $null
				}
				[PSCustomObject]@{
					ColumnName     = 'Age'
					DataType       = 'int'
					SemanticType   = $null
					IsIdentity     = $false
					IsComputed     = $false
					IsPrimaryKey   = $false
					IsUnique       = $false
					IsNullable     = $true
					MaxLength      = $null
					ForeignKey     = $null
					SchemaHint     = $null
					Classification = [PSCustomObject]@{ SemanticType = $null; IsPII = $false }
					GenerationRule = $null
				}
			)
			[PSCustomObject]@{
				SchemaName  = 'dbo'
				TableName   = 'TestTable'
				FullName    = 'dbo.TestTable'
				Columns     = $cols[0..([Math]::Min($colCount, $cols.Count) - 1)]
				ForeignKeys = @()
			}
		}
	}

	Context "Basic Streaming Behavior" {
		It "Generates rows across multiple chunks" {
			$tableInfo = & $script:buildTableInfo
			$genMap = & $module { Get-SldgGeneratorMap -Locale 'en-US' }

			$result = & $module {
				param($ti, $gm)
				Invoke-SldgStreamingGeneration -TableInfo $ti -TotalRowCount 25 -ChunkSize 10 `
					-GeneratorMap $gm -NoInsert
			} $tableInfo $genMap

			$result | Should -Not -BeNullOrEmpty
			$result.InsertedCount | Should -Be 25
		}

		It "Returns correct count for single chunk" {
			$tableInfo = & $script:buildTableInfo
			$genMap = & $module { Get-SldgGeneratorMap -Locale 'en-US' }

			$result = & $module {
				param($ti, $gm)
				Invoke-SldgStreamingGeneration -TableInfo $ti -TotalRowCount 5 -ChunkSize 100 `
					-GeneratorMap $gm -NoInsert
			} $tableInfo $genMap

			$result.InsertedCount | Should -Be 5
		}

		It "Returns GeneratedValues for FK tracking" {
			# Use a table with a non-identity unique column so values are tracked
			$tableInfo = [PSCustomObject]@{
				SchemaName  = 'dbo'
				TableName   = 'TestTable'
				FullName    = 'dbo.TestTable'
				Columns     = @(
					[PSCustomObject]@{
						ColumnName     = 'Code'
						DataType       = 'nvarchar'
						SemanticType   = 'Guid'
						IsIdentity     = $false
						IsComputed     = $false
						IsPrimaryKey   = $true
						IsUnique       = $true
						IsNullable     = $false
						MaxLength      = 50
						ForeignKey     = $null
						SchemaHint     = $null
						Classification = [PSCustomObject]@{ SemanticType = 'Guid'; IsPII = $false }
						GenerationRule = $null
					}
				)
				ForeignKeys = @()
			}
			$genMap = & $module { Get-SldgGeneratorMap -Locale 'en-US' }

			$result = & $module {
				param($ti, $gm)
				Invoke-SldgStreamingGeneration -TableInfo $ti -TotalRowCount 10 -ChunkSize 5 `
					-GeneratorMap $gm -NoInsert
			} $tableInfo $genMap

			$result.GeneratedValues | Should -Not -BeNullOrEmpty
		}
	}

	Context "PassThru Mode" {
		It "Returns DataTables when PassThru is specified" {
			$tableInfo = & $script:buildTableInfo
			$genMap = & $module { Get-SldgGeneratorMap -Locale 'en-US' }

			$result = & $module {
				param($ti, $gm)
				Invoke-SldgStreamingGeneration -TableInfo $ti -TotalRowCount 15 -ChunkSize 10 `
					-GeneratorMap $gm -NoInsert -PassThru
			} $tableInfo $genMap

			$result.DataTables | Should -Not -BeNullOrEmpty
			$result.DataTables.Count | Should -Be 2
		}
	}

	Context "Uniqueness Across Chunks (F2 fix)" {
		It "Tracks unique values across chunks via shared tracker" {
			# Build table with unique non-identity column
			$tableInfo = [PSCustomObject]@{
				SchemaName  = 'dbo'
				TableName   = 'UniqTest'
				FullName    = 'dbo.UniqTest'
				Columns     = @(
					[PSCustomObject]@{
						ColumnName     = 'Code'
						DataType       = 'nvarchar'
						SemanticType   = 'Guid'
						IsIdentity     = $false
						IsComputed     = $false
						IsPrimaryKey   = $true
						IsUnique       = $true
						IsNullable     = $false
						MaxLength      = 50
						ForeignKey     = $null
						SchemaHint     = $null
						Classification = [PSCustomObject]@{ SemanticType = 'Guid'; IsPII = $false }
						GenerationRule = $null
					}
				)
				ForeignKeys = @()
			}
			$genMap = & $module { Get-SldgGeneratorMap -Locale 'en-US' }

			$result = & $module {
				param($ti, $gm)
				Invoke-SldgStreamingGeneration -TableInfo $ti -TotalRowCount 20 -ChunkSize 5 `
					-GeneratorMap $gm -NoInsert -PassThru
			} $tableInfo $genMap

			# All generated codes across all chunks should be unique
			$allCodes = @()
			foreach ($dt in $result.DataTables) {
				foreach ($row in $dt.Rows) {
					$allCodes += $row['Code']
				}
			}
			$allCodes.Count | Should -Be 20
			($allCodes | Select-Object -Unique).Count | Should -Be 20
		}
	}
}
