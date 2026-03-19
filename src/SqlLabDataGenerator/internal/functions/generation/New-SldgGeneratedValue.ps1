function New-SldgGeneratedValue {
	<#
	.SYNOPSIS
		Generates a single value for a column based on its semantic type and generation rule.
	.DESCRIPTION
		Core value generation function. Handles FK lookups, identity skipping,
		nullable randomization, custom value lists, and generator dispatch.
	#>
	[CmdletBinding()]
	param (
		[Parameter(Mandatory)]
		$Column,

		[hashtable]$GeneratorMap,

		[hashtable]$ForeignKeyValues,

		[hashtable]$CustomRule,

		[int]$NullProbability = -1
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
	if ($Column.IsNullable -and -not $Column.ForeignKey -and -not $Column.IsPrimaryKey) {
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
		elseif ($dt -match '^(date|datetime|datetime2)$') { return (Get-Date -Date ((Get-Date).AddDays(-(Get-Random -Minimum 1 -Maximum 1000))) -Format 'yyyy-MM-dd') }
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
			if ($check -match '\[?\w+\]?\s*>=\s*([\d.]+)') { $params['Minimum'] = [double]$Matches[1] }
			if ($check -match '\[?\w+\]?\s*<=\s*([\d.]+)') { $params['Maximum'] = [double]$Matches[1] }
			if ($check -match '\[?\w+\]?\s*>\s*([\d.]+)') { $params['Minimum'] = [double]$Matches[1] + 1 }
			if ($check -match '\[?\w+\]?\s*<\s*([\d.]+)') { $params['Maximum'] = [double]$Matches[1] - 1 }
		}
	}

	# Pass column/table context to structured data generators (JSON/XML)
	if ($gen.Function -eq 'New-SldgStructuredData') {
		$params['ColumnName'] = $Column.ColumnName
		if ($Column.TableName) { $params['TableName'] = $Column.TableName }
		if ($Column.SchemaHint) { $params['SchemaHint'] = $Column.SchemaHint }
		if ($Column.MaxLength -and $Column.MaxLength -gt 0) { $params['MaxLength'] = $Column.MaxLength }
	}

	& $gen.Function @params
}
