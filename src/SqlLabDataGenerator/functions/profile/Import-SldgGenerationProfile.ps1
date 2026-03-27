function Import-SldgGenerationProfile {
	<#
	.SYNOPSIS
		Imports generation rules from a JSON profile file.

	.DESCRIPTION
		Loads a previously exported or manually created JSON profile that defines
		custom generation rules for specific tables and columns. This allows
		consistent, repeatable data generation across environments.

		Supported column rule keys: valueList, staticValue, generator, generatorParams,
		aiGenerationHint, crossColumnDependency, and valueExamples.
		scriptBlock keys are rejected during import to prevent code injection.

		The JSON format is:
		{
		    "tables": {
		        "dbo.Customer": {
		            "rowCount": 200,
		            "columns": {
		                "Status": { "valueList": ["Active", "Inactive"] },
		                "Currency": { "staticValue": "USD" },
		                "Email": { "generator": "Email" },
		                "ReportData": {
		                    "generator": "Json",
		                    "aiGenerationHint": "M365 usage report data",
		                    "crossColumnDependency": "ReportType"
		                }
		            }
		        }
		    }
		}

	.PARAMETER Path
		Path to the JSON profile file.

	.PARAMETER Plan
		The generation plan to apply the profile to.

	.EXAMPLE
		PS C:\> $plan = New-SldgGenerationPlan -Schema $schema
		PS C:\> Import-SldgGenerationProfile -Path 'C:\profiles\retail.json' -Plan $plan

		Applies the retail profile to the generation plan.
	#>
	[CmdletBinding()]
	param (
		[Parameter(Mandatory)]
		[ValidateScript({ Test-Path $_ })]
		[string]$Path,

		[Parameter(Mandatory)]
		$Plan
	)

	Write-PSFMessage -Level Host -Message ($script:strings.'Profile.Importing' -f $Path)

	# Guard against excessively large profile files (default 10 MB limit)
	$maxProfileSizeMB = 10
	$fileSize = (Get-Item -Path $Path).Length
	if ($fileSize -gt ($maxProfileSizeMB * 1MB)) {
		Stop-PSFFunction -Message "Profile file '$Path' is $([math]::Round($fileSize / 1MB, 1)) MB, exceeding the $maxProfileSizeMB MB limit." -EnableException $true
	}

	$profileData = Get-Content -Path $Path -Raw | ConvertFrom-Json

	# Build known generator whitelist from the generator map
	$knownGenerators = @((Get-SldgGeneratorMap).Keys)

	$ruleCount = 0
	$columnOverrides = 0

	if ($profileData.tables) {
		$tableNames = $profileData.tables.PSObject.Properties.Name
		foreach ($tableName in $tableNames) {
			$tableProfile = $profileData.tables.$tableName

			# Override row count
			if ($tableProfile.rowCount) {
				$tablePlan = $Plan.Tables | Where-Object { $_.FullName -eq $tableName } | Select-Object -First 1
				if ($tablePlan) {
					try {
						$tablePlan.RowCount = [int]$tableProfile.rowCount
					}
					catch {
						Write-PSFMessage -Level Warning -Message "Profile: Invalid rowCount '$($tableProfile.rowCount)' for table '$tableName' — skipping override."
					}
				}
			}

			# Override column rules
			if ($tableProfile.columns) {
				$colNames = $tableProfile.columns.PSObject.Properties.Name
				foreach ($colName in $colNames) {
					$colProfile = $tableProfile.columns.$colName

					# Security guard: reject scriptBlock keys from JSON profiles to prevent code injection (case-insensitive)
					$hasScriptBlock = $colProfile.PSObject.Properties.Name | Where-Object { $_ -ieq 'scriptBlock' }
					if ($hasScriptBlock) {
						Write-PSFMessage -Level Warning -String 'Profile.ScriptBlockSkipped' -StringValues $Path, $colName, $tableName
						continue
					}

					# Generator whitelist: reject unknown generator names to prevent injection
					if ($colProfile.generator -and $colProfile.generator -notin $knownGenerators) {
						Write-PSFMessage -Level Warning -String 'Profile.UnknownGenerator' -StringValues $Path, $colName, $tableName, $colProfile.generator, ($knownGenerators -join ', ')
						continue
					}

					# Validate column exists in the plan to avoid silently applying rules to non-existent columns
					$targetTable = $Plan.Tables | Where-Object { $_.FullName -eq $tableName } | Select-Object -First 1
					if ($targetTable) {
						$colExists = $targetTable.Columns | Where-Object { $_.Name -eq $colName }
						if (-not $colExists) {
							Write-PSFMessage -Level Warning -String 'Profile.ColumnNotFound' -StringValues $colName, $tableName, $Path
							continue
						}
					}

					$ruleParams = @{
						Plan       = $Plan
						TableName  = $tableName
						ColumnName = $colName
					}

					if ($colProfile.valueList) { $ruleParams['ValueList'] = @($colProfile.valueList) }
					if ($null -ne $colProfile.staticValue) { $ruleParams['StaticValue'] = $colProfile.staticValue }
					if ($colProfile.generator) { $ruleParams['Generator'] = $colProfile.generator }
					if ($colProfile.generatorParams) {
						$params = @{}
						$colProfile.generatorParams.PSObject.Properties | ForEach-Object { $params[$_.Name] = $_.Value }
						$ruleParams['GeneratorParams'] = $params
					}

					Set-SldgGenerationRule @ruleParams
					$columnOverrides++
				}
			}

			$ruleCount++
		}
	}

	Write-PSFMessage -Level Host -Message ($script:strings.'Profile.RuleCount' -f $ruleCount, $columnOverrides)

	# Recalculate totals
	$Plan.TotalRows = ($Plan.Tables | Measure-Object -Property RowCount -Sum).Sum
}
