function Set-SldgGenerationRule {
	<#
	.SYNOPSIS
		Sets custom generation rules for specific columns or tables.

	.DESCRIPTION
		Overrides the default generation behavior for specific columns. Supports:
		- ValueList: pick from a predefined list of values
		- StaticValue: always use the same value
		- Generator: override the semantic type mapping
		- ScriptBlock: custom generation logic

	.PARAMETER Plan
		The generation plan to modify.

	.PARAMETER TableName
		The fully qualified table name (e.g., 'dbo.Customer').

	.PARAMETER ColumnName
		The column name to set the rule for.

	.PARAMETER ValueList
		A list of values to randomly pick from.

	.PARAMETER StaticValue
		A fixed value to always use.

	.PARAMETER Generator
		Override the semantic type (e.g., 'Email', 'Phone', 'CompanyName').

	.PARAMETER GeneratorParams
		Additional parameters for the generator.

	.PARAMETER ScriptBlock
		Custom scriptblock that generates a value.

	.EXAMPLE
		PS C:\> Set-SldgGenerationRule -Plan $plan -TableName 'dbo.Customer' -ColumnName 'Status' -ValueList @('Active', 'Inactive', 'Pending')

	.EXAMPLE
		PS C:\> Set-SldgGenerationRule -Plan $plan -TableName 'dbo.Order' -ColumnName 'Currency' -StaticValue 'USD'

	.EXAMPLE
		PS C:\> Set-SldgGenerationRule -Plan $plan -TableName 'dbo.Product' -ColumnName 'SKU' -ScriptBlock { "SKU-$(Get-Random -Minimum 10000 -Maximum 99999)" }
	#>
	[CmdletBinding()]
	param (
		[Parameter(Mandatory)]
		$Plan,

		[Parameter(Mandatory)]
		[string]$TableName,

		[Parameter(Mandatory)]
		[string]$ColumnName,

		[string[]]$ValueList,

		$StaticValue,

		[string]$Generator,

		[hashtable]$GeneratorParams,

		[scriptblock]$ScriptBlock
	)

	$rule = @{}
	if ($ValueList) { $rule['ValueList'] = $ValueList }
	if ($PSBoundParameters.ContainsKey('StaticValue')) { $rule['StaticValue'] = $StaticValue }
	if ($Generator) { $rule['Generator'] = $Generator }
	if ($GeneratorParams) { $rule['Params'] = $GeneratorParams }
	if ($ScriptBlock) { $rule['ScriptBlock'] = $ScriptBlock }

	# Store rule in plan
	if (-not $Plan.GenerationRules.ContainsKey($TableName)) {
		$Plan.GenerationRules[$TableName] = @{}
	}
	$Plan.GenerationRules[$TableName][$ColumnName] = $rule

	# Also update the column plan
	$tablePlan = $Plan.Tables | Where-Object { $_.FullName -eq $TableName } | Select-Object -First 1
	if (-not $tablePlan) {
		Write-PSFMessage -Level Warning -Message "Table '$TableName' not found in plan. Rule stored but may not be applied during generation."
	}
	else {
		$colPlan = $tablePlan.Columns | Where-Object { $_.ColumnName -eq $ColumnName } | Select-Object -First 1
		if (-not $colPlan) {
			Write-PSFMessage -Level Warning -Message "Column '$ColumnName' not found in table '$TableName'. Rule stored but may not be applied during generation."
		}
		else {
			$colPlan.CustomRule = $rule
		}
	}
}
