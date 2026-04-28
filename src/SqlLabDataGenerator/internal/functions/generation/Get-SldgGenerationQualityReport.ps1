function Get-SldgGenerationQualityReport {
	<#
	.SYNOPSIS
		Builds the QualityReport PSCustomObject attached to the GenerationResult.
	.DESCRIPTION
		Extracted from Invoke-SldgDataGeneration. Pure aggregation over the table-level
		results plus FK-fallback statistics and validation outcome. Centralising this here
		keeps the orchestrator readable and makes the report shape unit-testable.
	#>
	[CmdletBinding()]
	[OutputType([PSCustomObject])]
	param (
		[Parameter(Mandatory)]
		$Plan,

		[Parameter(Mandatory)]
		$TableResults,

		[Parameter(Mandatory)]
		[int]$TotalInserted,

		$FkFallbackStats,

		[bool]$ValidationRun,

		$ValidationResults
	)

	$requestedRows = ($Plan.Tables | Measure-Object -Property RowCount -Sum).Sum
	if ($null -eq $requestedRows) { $requestedRows = 0 }

	$failedRows = ($TableResults | Where-Object { -not $_.Success } | ForEach-Object {
			if ($_.PSObject.Properties.Name -contains 'RequestedRows') { [int]$_.RequestedRows } else { 0 }
		} | Measure-Object -Sum).Sum
	if ($null -eq $failedRows) { $failedRows = 0 }

	$skippedRows = ($TableResults | ForEach-Object {
			if ($_.PSObject.Properties.Name -contains 'SkippedRows') { [int]$_.SkippedRows } else { 0 }
		} | Measure-Object -Sum).Sum
	if ($null -eq $skippedRows) { $skippedRows = 0 }

	$validationErrorCount = if ($ValidationRun) { @($ValidationResults | Where-Object { -not $_.Passed -and $_.Severity -eq 'Error' }).Count } else { 0 }
	$validationWarningCount = if ($ValidationRun) { @($ValidationResults | Where-Object { $_.Severity -eq 'Warning' }).Count } else { 0 }
	$validationPassed = if ($ValidationRun) { $validationErrorCount -eq 0 } else { $null }

	[PSCustomObject]@{
		RequestedRows            = [int]$requestedRows
		InsertedRows             = [int]$TotalInserted
		SkippedRows              = [int]$skippedRows
		FailedRows               = [int]$failedRows
		TableCount               = [int]$Plan.TableCount
		SuccessfulTables         = ($TableResults | Where-Object Success).Count
		FailedTables             = ($TableResults | Where-Object { -not $_.Success }).Count
		FKFallbackReferenceCount = @($FkFallbackStats).Count
		FKFallbackValueCount     = [int]((@($FkFallbackStats) | Measure-Object -Property ValueCount -Sum).Sum)
		FKFallbacks              = @($FkFallbackStats)
		ValidationRun            = [bool]$ValidationRun
		ValidationPassed         = $validationPassed
		ValidationErrorCount     = $validationErrorCount
		ValidationWarningCount   = $validationWarningCount
	}
}
