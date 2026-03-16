function Import-SldgGenerationProfile {
	<#
	.SYNOPSIS
		Imports generation rules from a JSON profile file.

	.DESCRIPTION
		Loads a previously exported or manually created JSON profile that defines
		custom generation rules for specific tables and columns. This allows
		consistent, repeatable data generation across environments.

		The JSON format is:
		{
		    "tables": {
		        "dbo.Customer": {
		            "rowCount": 200,
		            "columns": {
		                "Status": { "valueList": ["Active", "Inactive"] },
		                "Currency": { "staticValue": "USD" },
		                "Email": { "generator": "Email" }
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

	$profile = Get-Content -Path $Path -Raw | ConvertFrom-Json

	$ruleCount = 0
	$columnOverrides = 0

	if ($profile.tables) {
		$tableNames = $profile.tables.PSObject.Properties.Name
		foreach ($tableName in $tableNames) {
			$tableProfile = $profile.tables.$tableName

			# Override row count
			if ($tableProfile.rowCount) {
				$tablePlan = $Plan.Tables | Where-Object { $_.FullName -eq $tableName } | Select-Object -First 1
				if ($tablePlan) {
					$tablePlan.RowCount = [int]$tableProfile.rowCount
				}
			}

			# Override column rules
			if ($tableProfile.columns) {
				$colNames = $tableProfile.columns.PSObject.Properties.Name
				foreach ($colName in $colNames) {
					$colProfile = $tableProfile.columns.$colName

					# Security guard: reject scriptBlock keys from JSON profiles to prevent code injection
					if ($colProfile.PSObject.Properties.Name -contains 'scriptBlock') {
						Write-PSFMessage -Level Warning -Message "Profile '$Path': column '$colName' in table '$tableName' contains a 'scriptBlock' key — skipped for security."
						continue
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
