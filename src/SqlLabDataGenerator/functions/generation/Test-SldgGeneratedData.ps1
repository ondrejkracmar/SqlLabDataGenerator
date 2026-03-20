function Test-SldgGeneratedData {
	<#
	.SYNOPSIS
		Validates the quality and integrity of generated data.

	.DESCRIPTION
		Runs a suite of validation checks against the generated data in the target database:
		- Foreign key referential integrity
		- Primary key and unique constraint uniqueness
		- NOT NULL constraint compliance
		- Row count verification

	.PARAMETER Schema
		The schema model to validate against.

	.PARAMETER ConnectionInfo
		The database connection. If not specified, uses the active connection.

	.EXAMPLE
		PS C:\> $results = Test-SldgGeneratedData -Schema $schema

		Validates all constraints in the connected database.

	.EXAMPLE
		PS C:\> $results = Test-SldgGeneratedData -Schema $schema | Where-Object { -not $_.Passed }

		Shows only failed validations.
	#>
	[CmdletBinding()]
	param (
		[Parameter(Mandatory)]
		$Schema,

		$ConnectionInfo
	)

	if (-not $ConnectionInfo) { $ConnectionInfo = $script:SldgState.ActiveConnection }
	if (-not $ConnectionInfo) {
		Stop-PSFFunction -String 'Connect.NoActiveConnection' -EnableException $true
	}

	# Connection staleness check
	if ($ConnectionInfo.DbConnection -and $ConnectionInfo.DbConnection.State -ne 'Open') {
		Stop-PSFFunction -Message ($script:strings.'Connect.HealthCheckFailed' -f $ConnectionInfo.Provider, $ConnectionInfo.ServerInstance, $ConnectionInfo.Database) -EnableException $true
	}

	Write-PSFMessage -Level Host -Message ($script:strings.'Validation.Starting' -f $Schema.TableCount)

	$allResults = [System.Collections.Generic.List[object]]::new()

	# FK integrity
	$fkResults = Test-SldgForeignKeyIntegrity -ConnectionInfo $ConnectionInfo -SchemaModel $Schema
	foreach ($r in $fkResults) { $allResults.Add($r) }

	# Unique constraints
	$uniqueResults = Test-SldgUniqueConstraints -ConnectionInfo $ConnectionInfo -SchemaModel $Schema
	foreach ($r in $uniqueResults) { $allResults.Add($r) }

	# Data type constraints
	$dtResults = Test-SldgDataTypeConstraints -ConnectionInfo $ConnectionInfo -SchemaModel $Schema
	foreach ($r in $dtResults) { $allResults.Add($r) }

	$passed = ($allResults | Where-Object { $_.Passed }).Count
	$warnings = ($allResults | Where-Object { $_.Severity -eq 'Warning' }).Count
	$errors = ($allResults | Where-Object { $_.Severity -eq 'Error' }).Count

	Write-PSFMessage -Level Host -Message ($script:strings.'Validation.Complete' -f $passed, $warnings, $errors)

	$allResults
}
