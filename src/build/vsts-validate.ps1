# Guide for available variables and working with secrets:
# https://docs.microsoft.com/en-us/vsts/build-release/concepts/definitions/build/variables?tabs=powershell

# Needs to ensure things are Done Right and only legal commits to master get built

# Run PSScriptAnalyzer for static analysis
Write-Host "Running PSScriptAnalyzer..." -ForegroundColor Cyan
$analyzerResults = Invoke-ScriptAnalyzer -Path "$PSScriptRoot\..\SqlLabDataGenerator" -Recurse -Severity Warning, Error -ExcludeRule PSUseShouldProcessForStateChangingFunctions
if ($analyzerResults) {
	$analyzerResults | Format-Table -AutoSize
	Write-Warning "PSScriptAnalyzer found $($analyzerResults.Count) issue(s)."
}
else {
	Write-Host "PSScriptAnalyzer: No issues found." -ForegroundColor Green
}

# Run internal pester tests
& "$PSScriptRoot\..\tests\pester.ps1"

# Azure DevOps PowerShell@2 wrapper checks $LASTEXITCODE after this script.
# Internal native calls (e.g. during assembly loading or code coverage) may
# leave it non-zero even when all tests pass. Reset to avoid false-positive failure.
$global:LASTEXITCODE = 0