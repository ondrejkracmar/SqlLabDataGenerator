Describe "Pipeline, OutputType, and ShouldProcess Compliance" {
	BeforeAll {
		Remove-Module SqlLabDataGenerator -ErrorAction Ignore
		Import-Module "$PSScriptRoot\..\..\..\SqlLabDataGenerator\SqlLabDataGenerator.psd1" -Force
		$module = Get-Module SqlLabDataGenerator
	}

	Context "OutputType Declarations" {
		# Every public function with typed output should declare [OutputType()]
		$outputTypeCases = @(
			@{ Name = 'Connect-SldgDatabase';      Expected = 'SqlLabDataGenerator.Connection' }
			@{ Name = 'Get-SldgAIProvider';         Expected = 'SqlLabDataGenerator.AIProviderInfo' }
			@{ Name = 'Get-SldgColumnAnalysis';     Expected = 'SqlLabDataGenerator.SchemaModel' }
			@{ Name = 'Get-SldgDatabaseSchema';     Expected = 'SqlLabDataGenerator.SchemaModel' }
			@{ Name = 'Get-SldgPromptTemplate';     Expected = 'SqlLabDataGenerator.PromptTemplate' }
			@{ Name = 'Get-SldgSession';            Expected = 'SqlLabDataGenerator.SessionInfo' }
			@{ Name = 'Get-SldgTransformer';        Expected = 'SqlLabDataGenerator.Transformer' }
			@{ Name = 'Invoke-SldgDataGeneration';  Expected = 'SqlLabDataGenerator.GenerationResult' }
			@{ Name = 'New-SldgGenerationPlan';     Expected = 'SqlLabDataGenerator.GenerationPlan' }
			@{ Name = 'Set-SldgAIProvider';         Expected = 'SqlLabDataGenerator.AIProviderInfo' }
			@{ Name = 'Set-SldgPromptTemplate';     Expected = 'SqlLabDataGenerator.PromptTemplate' }
			@{ Name = 'Test-SldgAIProvider';        Expected = 'SqlLabDataGenerator.AIProviderTestResult' }
			@{ Name = 'Test-SldgGeneratedData';     Expected = 'SqlLabDataGenerator.ValidationResult' }
		)

		It "<Name> declares OutputType <Expected>" -ForEach $outputTypeCases {
			$cmd = Get-Command $Name
			$types = $cmd.OutputType | ForEach-Object { $_.Type.FullName, $_.Name } | Select-Object -Unique
			$types | Should -Contain $Expected
		}
	}

	Context "ShouldProcess Support" {
		# State-changing cmdlets writing to files or resetting state
		$shouldProcessCases = @(
			@{ Name = 'Export-SldgGenerationProfile' }
			@{ Name = 'Export-SldgTransformedData' }
			@{ Name = 'Invoke-SldgDataGeneration' }
			@{ Name = 'Remove-SldgPromptTemplate' }
			@{ Name = 'Reset-SldgSession' }
			@{ Name = 'Set-SldgPromptTemplate' }
		)

		It "<Name> supports -WhatIf and -Confirm" -ForEach $shouldProcessCases {
			$cmd = Get-Command $Name
			$cmd.Parameters.Keys | Should -Contain 'WhatIf'
			$cmd.Parameters.Keys | Should -Contain 'Confirm'
		}
	}

	Context "Pipeline Input Support" {
		$pipelineCases = @(
			@{ Name = 'Get-SldgColumnAnalysis'; ParamName = 'Schema' }
			@{ Name = 'New-SldgGenerationPlan'; ParamName = 'Schema' }
			@{ Name = 'Test-SldgGeneratedData'; ParamName = 'Schema' }
			@{ Name = 'Invoke-SldgDataGeneration'; ParamName = 'Plan' }
			@{ Name = 'Export-SldgGenerationProfile'; ParamName = 'Plan' }
			@{ Name = 'Remove-SldgPromptTemplate'; ParamName = 'InputObject' }
			@{ Name = 'Set-SldgPromptTemplate'; ParamName = 'InputObject' }
		)

		It "<Name> accepts pipeline input on -<ParamName>" -ForEach $pipelineCases {
			$cmd = Get-Command $Name
			$param = $cmd.Parameters[$ParamName]
			$param | Should -Not -BeNullOrEmpty
			$pipelineAttr = $param.Attributes.Where({
				$_ -is [System.Management.Automation.ParameterAttribute] -and $_.ValueFromPipeline
			})
			$pipelineAttr | Should -Not -BeNullOrEmpty -Because "$Name -$ParamName should accept ValueFromPipeline"
		}
	}

	Context "Pipeline Execution - Schema Pipeline" {
		BeforeAll {
			# Build a minimal schema for pipeline testing
			$schemaTable = [SqlLabDataGenerator.TableInfo]@{
				SchemaName = 'dbo'
				TableName  = 'PipelineTest'
				FullName   = 'dbo.PipelineTest'
				Columns    = @(
					[SqlLabDataGenerator.ColumnInfo]@{
						ColumnName  = 'Id'
						DataType    = 'int'
						IsIdentity  = $true
						IsPrimaryKey = $true
						IsNullable  = $false
					},
					[SqlLabDataGenerator.ColumnInfo]@{
						ColumnName  = 'Name'
						DataType    = 'nvarchar'
						MaxLength   = 100
						IsNullable  = $false
					}
				)
			}
			$script:testSchema = [SqlLabDataGenerator.SchemaModel]@{
				Database     = 'PipelineTestDB'
				Tables       = @($schemaTable)
				TableCount   = 1
				DiscoveredAt = (Get-Date)
			}
		}

		It "Schema pipelines through Get-SldgColumnAnalysis" {
			$result = $testSchema | Get-SldgColumnAnalysis
			$result | Should -Not -BeNullOrEmpty
			$result.Tables.Count | Should -Be 1
		}

		It "Schema pipelines through New-SldgGenerationPlan" {
			$analyzed = Get-SldgColumnAnalysis -Schema $testSchema
			$plan = $analyzed | New-SldgGenerationPlan -RowCount 5
			$plan | Should -Not -BeNullOrEmpty
			$plan | Should -BeOfType 'SqlLabDataGenerator.GenerationPlan'
			$plan.Tables.Count | Should -Be 1
		}

		It "Plan pipelines through Invoke-SldgDataGeneration -NoInsert" {
			$analyzed = Get-SldgColumnAnalysis -Schema $testSchema
			$plan = New-SldgGenerationPlan -Schema $analyzed -RowCount 5
			$result = $plan | Invoke-SldgDataGeneration -NoInsert
			$result | Should -Not -BeNullOrEmpty
			$result | Should -BeOfType 'SqlLabDataGenerator.GenerationResult'
		}

		It "Full pipeline: Schema | Analyze | Plan | Generate" {
			$result = $testSchema |
				Get-SldgColumnAnalysis |
				New-SldgGenerationPlan -RowCount 3 |
				Invoke-SldgDataGeneration -NoInsert
			$result | Should -Not -BeNullOrEmpty
			$result.TotalRows | Should -BeGreaterThan 0
		}
	}

	Context "Pipeline Execution - Plan to Export" {
		It "Plan pipelines through Export-SldgGenerationProfile" {
			$schemaTable = [SqlLabDataGenerator.TableInfo]@{
				SchemaName = 'dbo'
				TableName  = 'ExportTest'
				FullName   = 'dbo.ExportTest'
				Columns    = @(
					[SqlLabDataGenerator.ColumnInfo]@{
						ColumnName  = 'Id'
						DataType    = 'int'
						IsIdentity  = $true
						IsPrimaryKey = $true
						IsNullable  = $false
					}
				)
			}
			$schema = [SqlLabDataGenerator.SchemaModel]@{
				Database     = 'ExportPipeDB'
				Tables       = @($schemaTable)
				TableCount   = 1
				DiscoveredAt = (Get-Date)
			}
			$analyzed = Get-SldgColumnAnalysis -Schema $schema
			$plan = New-SldgGenerationPlan -Schema $analyzed -RowCount 5

			$exportPath = Join-Path $TestDrive 'pipeline-export.json'
			$plan | Export-SldgGenerationProfile -Path $exportPath

			Test-Path $exportPath | Should -BeTrue
			$json = Get-Content $exportPath -Raw | ConvertFrom-Json
			$json.database | Should -Be 'ExportPipeDB'
		}
	}

	Context "Pipeline Execution - PromptTemplate Pipeline" {
		It "Get-SldgPromptTemplate output pipelines to Remove-SldgPromptTemplate -WhatIf" {
			$templates = Get-SldgPromptTemplate
			$templates | Should -Not -BeNullOrEmpty

			# -WhatIf ensures nothing is actually removed
			{ $templates | Remove-SldgPromptTemplate -WhatIf } | Should -Not -Throw
		}
	}

	Context "ShouldProcess Execution" {
		It "Export-SldgGenerationProfile -WhatIf does not create file" {
			$schemaTable = [SqlLabDataGenerator.TableInfo]@{
				SchemaName = 'dbo'
				TableName  = 'WhatIfTest'
				FullName   = 'dbo.WhatIfTest'
				Columns    = @(
					[SqlLabDataGenerator.ColumnInfo]@{
						ColumnName  = 'Id'
						DataType    = 'int'
						IsIdentity  = $true
						IsPrimaryKey = $true
						IsNullable  = $false
					}
				)
			}
			$schema = [SqlLabDataGenerator.SchemaModel]@{
				Database     = 'WhatIfDB'
				Tables       = @($schemaTable)
				TableCount   = 1
				DiscoveredAt = (Get-Date)
			}
			$analyzed = Get-SldgColumnAnalysis -Schema $schema
			$plan = New-SldgGenerationPlan -Schema $analyzed -RowCount 5

			$whatIfPath = Join-Path $TestDrive 'whatif-test.json'
			Export-SldgGenerationProfile -Plan $plan -Path $whatIfPath -WhatIf

			Test-Path $whatIfPath | Should -BeFalse
		}

		It "Invoke-SldgDataGeneration -WhatIf does not generate rows" {
			$schemaTable = [SqlLabDataGenerator.TableInfo]@{
				SchemaName = 'dbo'
				TableName  = 'WhatIfGen'
				FullName   = 'dbo.WhatIfGen'
				Columns    = @(
					[SqlLabDataGenerator.ColumnInfo]@{
						ColumnName  = 'Id'
						DataType    = 'int'
						IsIdentity  = $true
						IsPrimaryKey = $true
						IsNullable  = $false
					},
					[SqlLabDataGenerator.ColumnInfo]@{
						ColumnName  = 'Name'
						DataType    = 'nvarchar'
						MaxLength   = 50
						IsNullable  = $false
					}
				)
			}
			$schema = [SqlLabDataGenerator.SchemaModel]@{
				Database     = 'WhatIfGenDB'
				Tables       = @($schemaTable)
				TableCount   = 1
				DiscoveredAt = (Get-Date)
			}
			$analyzed = Get-SldgColumnAnalysis -Schema $schema
			$plan = New-SldgGenerationPlan -Schema $analyzed -RowCount 5

			$result = Invoke-SldgDataGeneration -Plan $plan -NoInsert -WhatIf
			$result.TotalRows | Should -Be 0
		}
	}
}
