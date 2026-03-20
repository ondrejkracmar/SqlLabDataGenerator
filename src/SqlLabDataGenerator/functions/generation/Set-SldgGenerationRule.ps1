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

	.PARAMETER AIGenerationHint
		Instructions for AI-powered generation. Provides context about what kind of data
		to generate — especially useful for JSON/XML columns where the structure should
		vary based on business context.
		Example: 'Generate M365 usage report data. Vary JSON structure by report type:
		UserActivity, MailboxUsage, OneDriveUsage, TeamsDeviceUsage, SharePointSiteUsage.'

	.PARAMETER CrossColumnDependency
		Specifies another column name in the same table that this column depends on.
		During generation, the value of the dependency column is passed to AI so it can
		generate context-appropriate data. For example, a 'Report' JSON column might
		depend on 'ReportId' to vary its structure by report type.

	.PARAMETER ValueExamples
		Example values that illustrate the expected format. Passed to AI to guide generation.
		For JSON/XML columns, provide example documents showing the expected structure.

	.EXAMPLE
		PS C:\> Set-SldgGenerationRule -Plan $plan -TableName 'dbo.Customer' -ColumnName 'Status' -ValueList @('Active', 'Inactive', 'Pending')

		Sets the Status column to randomly pick from a predefined list.

	.EXAMPLE
		PS C:\> Set-SldgGenerationRule -Plan $plan -TableName 'dbo.Order' -ColumnName 'Currency' -StaticValue 'USD'

		Sets the Currency column to always use 'USD'.

	.EXAMPLE
		PS C:\> Set-SldgGenerationRule -Plan $plan -TableName 'dbo.Product' -ColumnName 'SKU' -ScriptBlock { "SKU-$(Get-Random -Minimum 10000 -Maximum 99999)" }

		Sets the SKU column to use a custom scriptblock for value generation.

	.EXAMPLE
		PS C:\> Set-SldgGenerationRule -Plan $plan -TableName 'dbo.UsageReport' -ColumnName 'ReportData' `
		    -Generator 'Json' `
		    -AIGenerationHint 'Generate Microsoft 365 usage report data. Structure varies by report type: UserActivity has sessions/actions, MailboxUsage has storage/itemCount, TeamsDeviceUsage has deviceType/usageMinutes.' `
		    -CrossColumnDependency 'ReportType'

		Sets the ReportData JSON column to use AI generation, varying the JSON structure
		based on the ReportType column value in each row.

	.NOTES
		SECURITY WARNING: The -ScriptBlock parameter executes arbitrary PowerShell code
		during data generation. Only use ScriptBlocks from trusted sources. ScriptBlocks
		are intentionally NOT supported in JSON profiles (Import-SldgGenerationProfile)
		to prevent code injection from untrusted files.
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

		[scriptblock]$ScriptBlock,

		[string]$AIGenerationHint,

		[string]$CrossColumnDependency,

		[string[]]$ValueExamples
	)

	$rule = @{}
	if ($ValueList) { $rule['ValueList'] = $ValueList }
	if ($PSBoundParameters.ContainsKey('StaticValue')) { $rule['StaticValue'] = $StaticValue }
	if ($Generator) { $rule['Generator'] = $Generator }
	if ($GeneratorParams) { $rule['Params'] = $GeneratorParams }
	if ($ScriptBlock) { $rule['ScriptBlock'] = $ScriptBlock }
	if ($AIGenerationHint) { $rule['AIGenerationHint'] = $AIGenerationHint }
	if ($CrossColumnDependency) { $rule['CrossColumnDependency'] = $CrossColumnDependency }
	if ($ValueExamples) { $rule['ValueExamples'] = $ValueExamples }

	# Store rule in plan
	if (-not $Plan.GenerationRules.ContainsKey($TableName)) {
		$Plan.GenerationRules[$TableName] = @{}
	}
	$Plan.GenerationRules[$TableName][$ColumnName] = $rule

	# Also update the column plan
	$tablePlan = $Plan.Tables | Where-Object { $_.FullName -eq $TableName } | Select-Object -First 1
	if (-not $tablePlan) {
		Write-PSFMessage -Level Warning -String 'GenerationRule.TableNotFound' -StringValues $TableName
	}
	else {
		$colPlan = $tablePlan.Columns | Where-Object { $_.ColumnName -eq $ColumnName } | Select-Object -First 1
		if (-not $colPlan) {
			Write-PSFMessage -Level Warning -String 'GenerationRule.ColumnNotFound' -StringValues $ColumnName, $TableName
		}
		else {
			$colPlan.CustomRule = $rule
		}
	}
}
