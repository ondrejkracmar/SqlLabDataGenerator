function New-SldgGenerationPlan {
	<#
	.SYNOPSIS
		Creates a data generation plan from an analyzed schema.

	.DESCRIPTION
		Builds an ordered execution plan for data generation. Resolves table dependencies
		via foreign keys (topological sort), assigns row counts, and maps each column
		to its generator. The plan can be reviewed and modified before execution.

		When -UseAI is specified, AI analyzes the schema to suggest:
		- Optimal row counts per table (lookup tables vs transaction tables)
		- Custom generation rules for domain-specific columns
		- Cross-table consistency requirements

	.PARAMETER Schema
		The analyzed schema model (output of Get-SldgColumnAnalysis or Get-SldgDatabaseSchema).

	.PARAMETER RowCount
		Default number of rows to generate per table. Default: value from Generation.DefaultRowCount config.

	.PARAMETER TableRowCounts
		Hashtable of table-specific row counts: @{ 'dbo.Customer' = 500; 'dbo.Order' = 2000 }.

	.PARAMETER Mode
		Generation mode: Synthetic (new data), Masking (anonymize existing), Scenario (domain template).

	.PARAMETER UseAI
		Let AI analyze the schema and suggest optimal row counts and generation rules.
		AI-suggested row counts are used unless overridden by -TableRowCounts.
		AI-suggested custom rules are applied unless columns already have rules.

	.PARAMETER IndustryHint
		Industry context for AI plan suggestions (e.g., 'Healthcare', 'eCommerce').

	.PARAMETER ScenarioName
		Scenario template name for Scenario mode. Built-in: eCommerce, Healthcare, HR,
		Finance, Education. Use 'Auto' (default) to let the module detect the best match
		from table names in the schema.

	.EXAMPLE
		PS C:\> $plan = New-SldgGenerationPlan -Schema $analyzed -RowCount 200

		Creates a plan to generate 200 rows per table.

	.EXAMPLE
		PS C:\> $plan = New-SldgGenerationPlan -Schema $analyzed -UseAI -RowCount 100

		AI suggests table-specific row counts (scaled from base 100) and custom rules.

	.EXAMPLE
		PS C:\> $plan = New-SldgGenerationPlan -Schema $analyzed -UseAI -IndustryHint 'eCommerce'

		AI uses eCommerce domain knowledge for realistic data patterns.

	.EXAMPLE
		PS C:\> $plan = New-SldgGenerationPlan -Schema $analyzed -Mode Scenario -ScenarioName eCommerce -RowCount 100

		Generates a Scenario plan: lookup tables get ~5 rows, customers 100, orders 300, order items 800.
	#>
	[OutputType([SqlLabDataGenerator.GenerationPlan])]
	[CmdletBinding()]
	param (
		[Parameter(Mandatory)]
		$Schema,

		[int]$RowCount,

		[hashtable]$TableRowCounts,

		[ValidateSet('Synthetic', 'Masking', 'Scenario')]
		[string]$Mode,

		[switch]$UseAI,

		[string]$IndustryHint,

		[string]$ScenarioName = 'Auto'
	)

	if (-not $RowCount) { $RowCount = Get-PSFConfigValue -FullName 'SqlLabDataGenerator.Generation.DefaultRowCount' }
	if (-not $Mode) { $Mode = Get-PSFConfigValue -FullName 'SqlLabDataGenerator.Generation.Mode' }

	Write-PSFMessage -Level Host -Message ($script:strings.'Generation.CreatingPlan' -f $Schema.TableCount)

	# Get AI plan advice if requested
	$aiAdvice = $null
	if ($UseAI) {
		$aiAdvice = Get-SldgAIPlanAdvice -SchemaModel $Schema -BaseRowCount $RowCount -IndustryHint $IndustryHint
		if ($aiAdvice) {
			Write-PSFMessage -Level Host -Message ($script:strings.'AI.PlanAdviceApplying' -f $aiAdvice.Tables.Count, $aiAdvice.CustomRules.Count)
		}
	}

	# Scenario mode: load template for domain-specific row count ratios and value rules
	$scenarioTemplate = $null
	if ($Mode -eq 'Scenario') {
		$scenarioTemplate = Get-SldgScenarioTemplate -Name $ScenarioName -Schema $Schema
		if ($scenarioTemplate) {
			Write-PSFMessage -Level Host -Message ($script:strings.'Scenario.Applying' -f $scenarioTemplate.Name, $scenarioTemplate.Description)
		}
		else {
			Write-PSFMessage -Level Warning -Message ($script:strings.'Scenario.FallbackSynthetic')
		}
	}

	# Resolve table insertion order
	$orderedTables = Resolve-SldgForeignKeyOrder -Tables $Schema.Tables

	# Build generator map
	$generatorMap = Get-SldgGeneratorMap

	# Build table plans
	$tablePlans = [System.Collections.Generic.List[object]]::new()
	$order = 0
	foreach ($table in $orderedTables) {
		$order++

		# Row count priority: explicit TableRowCounts > AI suggestion > Scenario template > default RowCount
		$tableRowCount = if ($TableRowCounts -and $TableRowCounts.ContainsKey($table.FullName)) {
			$TableRowCounts[$table.FullName]
		}
		elseif ($aiAdvice -and $aiAdvice.Tables.ContainsKey($table.FullName)) {
			$aiAdvice.Tables[$table.FullName].RowCount
		}
		elseif ($scenarioTemplate) {
			# Apply scenario row count multiplier based on table role matching
			$multiplier = 1.0
			$tableLower = $table.TableName.ToLower()
			foreach ($pattern in $scenarioTemplate.TableRoles.Keys) {
				if ($tableLower -match $pattern) {
					$multiplier = $scenarioTemplate.TableRoles[$pattern].Multiplier
					break
				}
			}
			[math]::Max(1, [int]($RowCount * $multiplier))
		}
		else { $RowCount }

		# Build column plans
		$columnPlans = foreach ($col in $table.Columns) {
			$skip = $col.IsIdentity -or $col.IsComputed -or $col.DataType -in @('timestamp', 'rowversion', 'geography', 'geometry', 'hierarchyid')
			$semanticType = if ($col.SemanticType) { $col.SemanticType } else { (Resolve-SldgSemanticType -DataType $col.DataType -MaxLength $col.MaxLength -IsNullable $col.IsNullable).Type }
			$gen = $generatorMap[$semanticType]

			[SqlLabDataGenerator.ColumnPlan]@{
				ColumnName    = $col.ColumnName
				DataType      = $col.DataType
				SemanticType  = $semanticType
				Generator     = if ($gen) { $gen.Function } else { 'Fallback' }
				IsPII         = if ($col.Classification) { $col.Classification.IsPII } else { $false }
				IsPrimaryKey  = [bool]$col.IsPrimaryKey
				IsUnique      = [bool]$col.IsUnique
				IsNullable    = [bool]$col.IsNullable
				MaxLength     = $col.MaxLength
				ForeignKey    = $col.ForeignKey
				SchemaHint    = $col.SchemaHint
				Skip          = $skip
				CustomRule    = $col.GenerationRule
			}
		}

		$tablePlans.Add([SqlLabDataGenerator.TablePlan]@{
				Order                   = $order
				SchemaName              = $table.SchemaName
				TableName               = $table.TableName
				FullName                = $table.FullName
				RowCount                = $tableRowCount
				Columns                 = $columnPlans
				ForeignKeys             = $table.ForeignKeys
				ColumnCount             = $table.ColumnCount
				HasCircularDependency   = [bool]$table.HasCircularDependency
			})
	}

	$plan = [SqlLabDataGenerator.GenerationPlan]@{
		Database       = $Schema.Database
		Mode           = $Mode
		Tables         = $tablePlans.ToArray()
		TableCount     = $tablePlans.Count
		TotalRows      = ($tablePlans | Measure-Object -Property RowCount -Sum).Sum
		GeneratorMap   = $generatorMap
		CreatedAt      = Get-Date
		GenerationRules = @{}
		AIAdvice       = $aiAdvice
	}

	# Apply AI-suggested custom rules
	if ($aiAdvice -and $aiAdvice.CustomRules.Count -gt 0) {
		foreach ($rule in $aiAdvice.CustomRules) {
			$tableName = $rule.TableName
			$columnName = $rule.ColumnName

			# Don't override existing rules
			if ($plan.GenerationRules.ContainsKey($tableName) -and $plan.GenerationRules[$tableName].ContainsKey($columnName)) {
				continue
			}

			$genRule = @{}
			switch ($rule.RuleType) {
				'ValueList' {
					if ($rule.Values -and $rule.Values.Count -gt 0) {
						$genRule['ValueList'] = $rule.Values
					}
				}
				'Hint' {
					# Store the hint for AI batch generation to use
					$genRule['AIHint'] = $rule.Hint
				}
			}

			if ($genRule.Count -gt 0) {
				if (-not $plan.GenerationRules.ContainsKey($tableName)) {
					$plan.GenerationRules[$tableName] = @{}
				}
				$plan.GenerationRules[$tableName][$columnName] = $genRule
			}
		}
	}

	# Apply Scenario template value rules to matching columns
	if ($scenarioTemplate -and $scenarioTemplate.ValueRules) {
		foreach ($tp in $plan.Tables) {
			foreach ($col in $tp.Columns) {
				if ($col.Skip -or $col.ForeignKey) { continue }

				# Don't override existing rules
				if ($plan.GenerationRules.ContainsKey($tp.FullName) -and $plan.GenerationRules[$tp.FullName].ContainsKey($col.ColumnName)) {
					continue
				}

				$colLower = $col.ColumnName.ToLower() -replace '[_\s]', ''
				foreach ($pattern in $scenarioTemplate.ValueRules.Keys) {
					if ($colLower -match $pattern) {
						if (-not $plan.GenerationRules.ContainsKey($tp.FullName)) {
							$plan.GenerationRules[$tp.FullName] = @{}
						}
						$plan.GenerationRules[$tp.FullName][$col.ColumnName] = @{
							ValueList = $scenarioTemplate.ValueRules[$pattern]
						}
						break
					}
				}
			}
		}
	}

	# Store in module state for modification
	$script:SldgState.GenerationPlans[$Schema.Database] = $plan

	$plan
}
