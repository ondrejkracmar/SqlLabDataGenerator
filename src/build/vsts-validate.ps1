# Guide for available variables and working with secrets:
# https://docs.microsoft.com/en-us/vsts/build-release/concepts/definitions/build/variables?tabs=powershell

# Needs to ensure things are Done Right and only legal commits to master get built

# Run PSScriptAnalyzer for static analysis
Write-Host "Running PSScriptAnalyzer..." -ForegroundColor Cyan
$analyzerResults = Invoke-ScriptAnalyzer -Path "$PSScriptRoot\..\SqlLabDataGenerator" -Recurse -Severity Warning, Error -ExcludeRule PSUseShouldProcessForStateChangingFunctions
if ($analyzerResults) {
	$analyzerResults | Format-Table -AutoSize
	$errorCount = @($analyzerResults | Where-Object { $_.Severity -eq 'Error' }).Count
	Write-Warning "PSScriptAnalyzer found $($analyzerResults.Count) issue(s) ($errorCount error(s))."
	if ($errorCount -gt 0) {
		$global:LASTEXITCODE = 1
		throw "PSScriptAnalyzer found $errorCount error-level issue(s). Fix before publishing."
	}
}
else {
	Write-Host "PSScriptAnalyzer: No issues found." -ForegroundColor Green
}

# Run internal pester tests
$pesterFailed = $false
try {
	& "$PSScriptRoot\..\tests\pester.ps1"
}
catch {
	$pesterFailed = $true
	Write-Error "Pester tests failed: $_"
}

if ($pesterFailed) {
	# Propagate real failure to Azure DevOps
	$global:LASTEXITCODE = 1
	throw "Validation failed: Pester tests did not pass."
}
else {
	# Azure DevOps PowerShell@2 wrapper checks $LASTEXITCODE after this script.
	# Internal native calls (e.g. during assembly loading or code coverage) may
	# leave it non-zero even when all tests pass. Reset only on success.
	$global:LASTEXITCODE = 0
}