function Get-SldgGenerationQualityReport {
	<#
	.SYNOPSIS
		Builds the GenerationQualityReport attached to a GenerationResult.
	.DESCRIPTION
		Pure aggregation over the table-level results plus FK-fallback statistics and the
		validation outcome. Centralising this here keeps the orchestrator readable and makes
		the report shape unit-testable.
	.PARAMETER Plan
		The plan that was executed; supplies requested row and table counts.
	.PARAMETER TableResults
		One TableResult per table, including failed ones.
	.PARAMETER TotalInserted
		Rows inserted across all tables.
	.PARAMETER FkFallbackStats
		Foreign-key references whose parent values were loaded from the database.
	.PARAMETER ValidationRun
		Whether -ValidateAfterGeneration ran.
	.PARAMETER ValidationResults
		The validation checks, when validation ran.
	#>
	[CmdletBinding()]
	[OutputType([SqlLabDataGenerator.GenerationQualityReport])]
	param (
		[Parameter(Mandatory)]
		[SqlLabDataGenerator.GenerationPlan]$Plan,

		[Parameter(Mandatory)]
		[AllowEmptyCollection()]
		[SqlLabDataGenerator.TableResult[]]$TableResults,

		[Parameter(Mandatory)]
		[int]$TotalInserted,

		[SqlLabDataGenerator.ForeignKeyFallback[]]$FkFallbackStats,

		[bool]$ValidationRun,

		[SqlLabDataGenerator.ValidationResult[]]$ValidationResults
	)

	$requestedRows = ($Plan.Tables | Measure-Object -Property RowCount -Sum).Sum
	if ($null -eq $requestedRows) { $requestedRows = 0 }

	$failedRows = ($TableResults | Where-Object { -not $_.Success } | Measure-Object -Property RequestedRows -Sum).Sum
	if ($null -eq $failedRows) { $failedRows = 0 }

	$skippedRows = ($TableResults | Measure-Object -Property SkippedRows -Sum).Sum
	if ($null -eq $skippedRows) { $skippedRows = 0 }

	$fallbacks = @($FkFallbackStats | Where-Object { $null -ne $_ })
	$validationErrorCount = if ($ValidationRun) { @($ValidationResults | Where-Object { -not $_.Passed -and $_.Severity -eq 'Error' }).Count } else { 0 }
	$validationWarningCount = if ($ValidationRun) { @($ValidationResults | Where-Object { $_.Severity -eq 'Warning' }).Count } else { 0 }
	$validationPassed = if ($ValidationRun) { $validationErrorCount -eq 0 } else { $null }

	[SqlLabDataGenerator.GenerationQualityReport]@{
		RequestedRows            = [int]$requestedRows
		InsertedRows             = [int]$TotalInserted
		SkippedRows              = [int]$skippedRows
		FailedRows               = [int]$failedRows
		TableCount               = [int]$Plan.TableCount
		SuccessfulTables         = @($TableResults | Where-Object Success).Count
		FailedTables             = @($TableResults | Where-Object { -not $_.Success }).Count
		FKFallbackReferenceCount = $fallbacks.Count
		FKFallbackValueCount     = [int](($fallbacks | Measure-Object -Property ValueCount -Sum).Sum)
		FKFallbacks              = $fallbacks
		ValidationRun            = [bool]$ValidationRun
		ValidationPassed         = $validationPassed
		ValidationErrorCount     = $validationErrorCount
		ValidationWarningCount   = $validationWarningCount
	}
}
