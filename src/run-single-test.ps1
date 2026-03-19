Import-Module Pester
Remove-Module SqlLabDataGenerator -ErrorAction Ignore
Import-Module .\SqlLabDataGenerator\SqlLabDataGenerator.psd1 -Force

$config = [PesterConfiguration]::Default
$config.Run.Path = @(".\tests\functions\internal\schema\ConvertTo-SldgSchemaModel.Tests.ps1")
$config.Run.PassThru = $true
$config.Output.Verbosity = "Detailed"
$config.CodeCoverage.Enabled = $false
$config.TestResult.Enabled = $false
$r = Invoke-Pester -Configuration $config
Write-Host "TOTAL: $($r.TotalCount) Passed: $($r.PassedCount) Failed: $($r.FailedCount)"
if ($r.FailedCount -gt 0) {
    $r.Failed | ForEach-Object { Write-Host "FAILED: $($_.ExpandedPath) - $($_.ErrorRecord)" }
}
