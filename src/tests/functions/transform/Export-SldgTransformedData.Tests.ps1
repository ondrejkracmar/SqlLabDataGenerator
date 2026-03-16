Describe "Export-SldgTransformedData" {
	BeforeAll {
		Remove-Module SqlLabDataGenerator -ErrorAction Ignore
		Import-Module "$PSScriptRoot\..\..\..\SqlLabDataGenerator\SqlLabDataGenerator.psd1" -Force
		$module = Get-Module SqlLabDataGenerator
	}

	Context "Parameter Validation" {
		It "Has mandatory Data parameter" {
			$cmd = Get-Command Export-SldgTransformedData
			$cmd.Parameters['Data'].Attributes.Where({ $_ -is [System.Management.Automation.ParameterAttribute] }).Mandatory | Should -BeTrue
		}

		It "Data parameter requires DataTable type" {
			$cmd = Get-Command Export-SldgTransformedData
			$cmd.Parameters['Data'].ParameterType.FullName | Should -Be 'System.Data.DataTable'
		}

		It "Has mandatory Transformer parameter" {
			$cmd = Get-Command Export-SldgTransformedData
			$cmd.Parameters['Transformer'].Attributes.Where({ $_ -is [System.Management.Automation.ParameterAttribute] }).Mandatory | Should -BeTrue
		}

		It "Has optional OutputPath parameter" {
			$cmd = Get-Command Export-SldgTransformedData
			$cmd.Parameters.ContainsKey('OutputPath') | Should -BeTrue
		}

		It "Has optional ColumnMapping parameter" {
			$cmd = Get-Command Export-SldgTransformedData
			$cmd.Parameters['ColumnMapping'].ParameterType.Name | Should -Be 'Hashtable'
		}

		It "Has optional TransformerParams parameter" {
			$cmd = Get-Command Export-SldgTransformedData
			$cmd.Parameters['TransformerParams'].ParameterType.Name | Should -Be 'Hashtable'
		}
	}

	Context "Transformer Validation" {
		It "Throws on unknown transformer name" {
			$dt = [System.Data.DataTable]::new()
			$null = $dt.Columns.Add('Col1', [string])
			{ Export-SldgTransformedData -Data $dt -Transformer 'NonExistentTransformer' -ErrorAction Stop } | Should -Throw
		}
	}

	Context "File Export" {
		BeforeAll {
			# Register a simple test transformer
			& $module {
				function script:ConvertTo-TestObject {
					param([System.Data.DataTable]$Data)
					foreach ($row in $Data.Rows) {
						[PSCustomObject]@{
							PSTypeName = 'Test.Object'
							Value      = $row['Col1']
						}
					}
				}
				$script:SldgState.Transformers['TestTransformer'] = [PSCustomObject]@{
					Name              = 'TestTransformer'
					Description       = 'Test transformer'
					TransformFunction = ${function:ConvertTo-TestObject}
				}
			}

			$script:testDt = [System.Data.DataTable]::new()
			$null = $script:testDt.Columns.Add('Col1', [string])
			$null = $script:testDt.Rows.Add('Value1')
			$null = $script:testDt.Rows.Add('Value2')
		}

		It "Exports to JSON file when OutputPath specified" {
			$outPath = Join-Path $TestDrive 'export.json'
			Export-SldgTransformedData -Data $script:testDt -Transformer 'TestTransformer' -OutputPath $outPath
			Test-Path $outPath | Should -BeTrue
		}

		It "Output file contains valid JSON" {
			$outPath = Join-Path $TestDrive 'export2.json'
			Export-SldgTransformedData -Data $script:testDt -Transformer 'TestTransformer' -OutputPath $outPath
			$json = Get-Content $outPath -Raw | ConvertFrom-Json
			$json | Should -Not -BeNullOrEmpty
		}

		It "Creates parent directory if needed" {
			$outPath = Join-Path $TestDrive 'subdir\nested\export.json'
			Export-SldgTransformedData -Data $script:testDt -Transformer 'TestTransformer' -OutputPath $outPath
			Test-Path $outPath | Should -BeTrue
		}

		It "Returns transformed objects" {
			$result = Export-SldgTransformedData -Data $script:testDt -Transformer 'TestTransformer'
			@($result).Count | Should -Be 2
		}

		AfterAll {
			& $module { $script:SldgState.Transformers.Remove('TestTransformer') }
		}
	}
}
