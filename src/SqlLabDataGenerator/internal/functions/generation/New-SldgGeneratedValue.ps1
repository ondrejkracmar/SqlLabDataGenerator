function New-SldgGeneratedValue {
	<#
	.SYNOPSIS
		Generates a single value for a column based on its semantic type and generation rule.
	.DESCRIPTION
		Core value generation function. Handles FK lookups, identity skipping,
		nullable randomization, custom value lists, and generator dispatch.

		When a CustomRule contains AIGenerationHint and/or CrossColumnDependency,
		and the column generator is Json or Xml, passes the AI hint and the dependency
		column value (from RowContext) to New-SldgStructuredData for context-dependent
		AI-powered structured data generation.
	#>
	[CmdletBinding()]
	param (
		[Parameter(Mandatory)]
		$Column,

		[hashtable]$GeneratorMap,

		[hashtable]$ForeignKeyValues,

		[hashtable]$CustomRule,

		[int]$NullProbability = -1,

		[hashtable]$RowContext
	)

	# Skip identity and computed columns
	if ($Column.IsIdentity -or $Column.IsComputed) { return $null }

	# Handle FK columns - pick from already-generated parent values
	if ($Column.ForeignKey -and $ForeignKeyValues) {
		$refKey = "$($Column.ForeignKey.ReferencedSchema).$($Column.ForeignKey.ReferencedTable).$($Column.ForeignKey.ReferencedColumn)"
		$parentValues = $ForeignKeyValues[$refKey]
		if ($parentValues -and $parentValues.Count -gt 0) {
			return ($parentValues | Get-Random)
		}

		# FK column but no parent values available — warn and return sentinel $null
		# so the caller (New-SldgRowSet) can handle the missing FK with its own fallback
		Write-PSFMessage -Level Warning -Message "No parent values found for FK column '$($Column.ColumnName)' referencing '$refKey'. Parent table may not have been populated."
		return $null
	}

	# Handle custom rule override
	if ($CustomRule) {
		if ($CustomRule.ContainsKey('ValueList') -and $CustomRule.ValueList) {
			return ($CustomRule.ValueList | Get-Random)
		}
		if ($CustomRule.ContainsKey('StaticValue')) {
			return $CustomRule.StaticValue
		}
		if ($CustomRule.ContainsKey('ScriptBlock') -and $CustomRule.ScriptBlock) {
			return (& $CustomRule.ScriptBlock)
		}
		if ($CustomRule.ContainsKey('Generator') -and $CustomRule.Generator) {
			$gen = $GeneratorMap[$CustomRule.Generator]
			if ($gen) {
				$params = if ($CustomRule.ContainsKey('Params')) { $CustomRule.Params } else { $gen.Params }
				return (& $gen.Function @params)
			}
		}
	}

	# Handle nullable columns (configurable chance of NULL for nullable non-FK columns)
	# Exempt PII columns and unique columns — they must always have values
	if ($Column.IsNullable -and -not $Column.ForeignKey -and -not $Column.IsPrimaryKey -and -not $Column.IsUnique -and -not ($Column.Classification -and $Column.Classification.IsPII)) {
		$nullProb = if ($NullProbability -ge 0) { $NullProbability } else { Get-PSFConfigValue -FullName 'SqlLabDataGenerator.Generation.NullProbability' }
		if ((Get-Random -Minimum 0 -Maximum 100) -lt $nullProb) { return [DBNull]::Value }
	}

	# Get semantic type (from classification or fallback)
	$semanticType = if ($Column.SemanticType) { $Column.SemanticType }
	elseif ($Column.Classification) { $Column.Classification.SemanticType }
	else { $null }

	if (-not $semanticType) {
		$fallback = Resolve-SldgSemanticType -DataType $Column.DataType -MaxLength $Column.MaxLength -IsNullable $Column.IsNullable
		$semanticType = $fallback.Type
	}

	# Look up generator
	$gen = $GeneratorMap[$semanticType]
	if (-not $gen) {
		# Ultimate fallback based on data type
		$typeInfo = Resolve-SldgSemanticType -DataType $Column.DataType -MaxLength $Column.MaxLength -IsNullable $Column.IsNullable
		$gen = $GeneratorMap[$typeInfo.Type]
	}

	if (-not $gen) {
		# Generate basic value by data type
		$dt = $Column.DataType.ToLower()
		if ($dt -match '^(int|bigint|smallint|tinyint)$') { return (Get-Random -Minimum 1 -Maximum 10000) }
		elseif ($dt -match '^(bit)$') { return [bool](Get-Random -Minimum 0 -Maximum 2) }
		elseif ($dt -match '^(decimal|numeric|float|real|money)$') { return [Math]::Round((Get-Random -Minimum 1 -Maximum 10000) / 100.0, 2) }
		elseif ($dt -match '^(date|datetime|datetime2|smalldatetime|datetimeoffset)$') { return (Get-Date -Date ((Get-Date).AddDays(-(Get-Random -Minimum 1 -Maximum 1000))) -Format 'yyyy-MM-dd') }
		elseif ($dt -eq 'time') { return [timespan]::FromMinutes((Get-Random -Minimum 0 -Maximum 1440)) }
		elseif ($dt -eq 'uniqueidentifier') { return [guid]::NewGuid() }
		elseif ($dt -match '^(binary|varbinary|image)$') {
			$len = if ($Column.MaxLength -and $Column.MaxLength -gt 0) { [Math]::Min($Column.MaxLength, 16) } else { 16 }
			$bytes = [byte[]]::new($len); (New-Object System.Random).NextBytes($bytes); return $bytes
		}
		else { return "Value_$(Get-Random -Minimum 1 -Maximum 9999)" }
	}

	$params = @{} + $gen.Params

	# Apply MaxLength constraint for text generators
	if ($Column.MaxLength -and $Column.MaxLength -gt 0 -and $params.ContainsKey('Type') -and $gen.Function -eq 'New-SldgText') {
		$params['MaxLength'] = $Column.MaxLength
	}

	# Apply CHECK constraint ranges to numeric generators
	if ($Column.CheckConstraints -and $Column.CheckConstraints.Count -gt 0) {
		foreach ($check in $Column.CheckConstraints) {
			# Split on AND to handle compound constraints like 'Qty >= 1 AND Qty <= 999'
			$clauses = $check -split '\bAND\b'
			foreach ($clause in $clauses) {
				if ($clause -match '\[?\w+\]?\s*>=\s*([-+]?\d+\.?\d*)') {
					$val = [double]$Matches[1]
					if (-not $params.ContainsKey('Minimum') -or $val -gt $params['Minimum']) { $params['Minimum'] = $val }
				}
				if ($clause -match '\[?\w+\]?\s*<=\s*([-+]?\d+\.?\d*)') {
					$val = [double]$Matches[1]
					if (-not $params.ContainsKey('Maximum') -or $val -lt $params['Maximum']) { $params['Maximum'] = $val }
				}
				if ($clause -match '\[?\w+\]?\s*>\s*([-+]?\d+\.?\d*)') {
					$val = [double]$Matches[1] + 1
					if (-not $params.ContainsKey('Minimum') -or $val -gt $params['Minimum']) { $params['Minimum'] = $val }
				}
				if ($clause -match '\[?\w+\]?\s*<\s*([-+]?\d+\.?\d*)') {
					$val = [double]$Matches[1] - 1
					if (-not $params.ContainsKey('Maximum') -or $val -lt $params['Maximum']) { $params['Maximum'] = $val }
				}
			}
		}
	}

	# Pass column/table context to structured data generators (JSON/XML)
	if ($gen.Function -eq 'New-SldgStructuredData') {
		$params['ColumnName'] = $Column.ColumnName
		if ($Column.TableName) { $params['TableName'] = $Column.TableName }
		if ($Column.SchemaHint) { $params['SchemaHint'] = $Column.SchemaHint }
		if ($Column.MaxLength -and $Column.MaxLength -gt 0) { $params['MaxLength'] = $Column.MaxLength }

		# AI generation hint from rule or column metadata
		$hint = if ($CustomRule -and $CustomRule.AIGenerationHint) { $CustomRule.AIGenerationHint } else { $null }
		if ($hint) { $params['AIGenerationHint'] = $hint }

		# Value examples from rule or column metadata
		$examples = if ($CustomRule -and $CustomRule.ValueExamples) { $CustomRule.ValueExamples } else { $null }
		if ($examples) { $params['ValueExamples'] = $examples }

		# Cross-column dependency: pass context from already-generated columns in this row
		$depCol = if ($CustomRule -and $CustomRule.CrossColumnDependency) { $CustomRule.CrossColumnDependency } else { $null }
		if ($depCol -and $RowContext -and $RowContext.ContainsKey($depCol)) {
			$params['ContextColumn'] = $depCol
			$params['ContextValue'] = [string]$RowContext[$depCol]
		}
	}

	& $gen.Function @params
}
