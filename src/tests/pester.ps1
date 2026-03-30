param (
	$TestGeneral = $true,
	
	$TestFunctions = $true,
	
	[ValidateSet('None', 'Normal', 'Detailed', 'Diagnostic')]
	[Alias('Show')]
	$Output = "None",
	
	$Include = "*",
	
	$Exclude = ""
)

Write-PSFMessage -Level Important -Message "Starting Tests"

Write-PSFMessage -Level Important -Message "Importing Module"

$global:testroot = $PSScriptRoot
$global:__pester_data = @{ }

Remove-Module SqlLabDataGenerator -ErrorAction Ignore
Import-Module "$PSScriptRoot\..\SqlLabDataGenerator\SqlLabDataGenerator.psd1" -Force

# Need to import explicitly so we can use the configuration class
Import-Module Pester

Write-PSFMessage -Level Important -Message "Creating test result folder"
$null = New-Item -Path "$PSScriptRoot\.." -Name TestResults -ItemType Directory -Force

$totalFailed = 0
$totalRun = 0

$testresults = @()
$config = [PesterConfiguration]::Default
$config.TestResult.Enabled = $true

# Code coverage will run in a single aggregated pass at the end
$coveragePaths = @("$PSScriptRoot\..\SqlLabDataGenerator\functions", "$PSScriptRoot\..\SqlLabDataGenerator\internal\functions") |
	Resolve-Path | ForEach-Object { $_.Path }
$coverageOutputPath = Join-Path (Resolve-Path "$PSScriptRoot\..\TestResults").Path "coverage.xml"
$allTestFiles = [System.Collections.Generic.List[string]]::new()

#region Run General Tests
if ($TestGeneral)
{
	Write-PSFMessage -Level Important -Message "Modules imported, proceeding with general tests"
	foreach ($file in (Get-ChildItem "$PSScriptRoot\general" | Where-Object Name -like "*.Tests.ps1"))
	{
		if ($file.Name -notlike $Include) { continue }
		if ($file.Name -like $Exclude) { continue }

		Write-PSFMessage -Level Significant -Message "  Executing <c='em'>$($file.Name)</c>"
		$config.TestResult.OutputPath = Join-Path "$PSScriptRoot\..\TestResults" "TEST-$($file.BaseName).xml"
		$config.Run.Path = $file.FullName
		$config.Run.PassThru = $true
		$config.Output.Verbosity = $Output
		$config.CodeCoverage.Enabled = $false
    	$results = Invoke-Pester -Configuration $config
		$allTestFiles.Add($file.FullName)
		foreach ($result in $results)
		{
			$totalRun += $result.TotalCount
			$totalFailed += $result.FailedCount
			$result.Tests | Where-Object Result -ne 'Passed' | ForEach-Object {
				$testresults += [pscustomobject]@{
					Block    = $_.Block
					Name	 = "It $($_.Name)"
					Result   = $_.Result
					Message  = $_.ErrorRecord.DisplayErrorMessage
				}
			}
		}
	}
}
#endregion Run General Tests

$global:__pester_data.ScriptAnalyzer | Out-Host

#region Test Commands
if ($TestFunctions)
{
	Write-PSFMessage -Level Important -Message "Proceeding with individual tests"
	foreach ($file in (Get-ChildItem "$PSScriptRoot\functions" -Recurse -File | Where-Object Name -like "*Tests.ps1"))
	{
		if ($file.Name -notlike $Include) { continue }
		if ($file.Name -like $Exclude) { continue }
		
		Write-PSFMessage -Level Significant -Message "  Executing $($file.Name)"
		$config.TestResult.OutputPath = Join-Path "$PSScriptRoot\..\TestResults" "TEST-$($file.BaseName).xml"
		$config.Run.Path = $file.FullName
		$config.Run.PassThru = $true
		$config.Output.Verbosity = $Output
		$config.CodeCoverage.Enabled = $false
    	$results = Invoke-Pester -Configuration $config
		$allTestFiles.Add($file.FullName)
		foreach ($result in $results)
		{
			$totalRun += $result.TotalCount
			$totalFailed += $result.FailedCount
			$result.Tests | Where-Object Result -ne 'Passed' | ForEach-Object {
				$testresults += [pscustomobject]@{
					Block    = $_.Block
					Name	 = "It $($_.Name)"
					Result   = $_.Result
					Message  = $_.ErrorRecord.DisplayErrorMessage
				}
			}
		}
	}
}
#endregion Test Commands

#region Aggregated Code Coverage
if ($allTestFiles.Count -gt 0) {
	Write-PSFMessage -Level Important -Message "Running aggregated code coverage pass ($($allTestFiles.Count) test files)"

	# Force dot-sourcing so Pester breakpoints can track executed lines back to source files.
	# Without this, Import-ModuleFile uses ScriptBlock.Create(ReadAllText()) which severs the
	# file-path association and Pester reports 0% coverage.
	Set-PSFConfig -FullName 'SqlLabDataGenerator.Import.DoDotSource' -Value $true

	$ccConfig = [PesterConfiguration]::Default
	$ccConfig.Run.Path = $allTestFiles.ToArray()
	$ccConfig.Run.PassThru = $false
	$ccConfig.Output.Verbosity = 'None'
	$ccConfig.TestResult.Enabled = $false
	$ccConfig.CodeCoverage.Enabled = $true
	$ccConfig.CodeCoverage.Path = $coveragePaths
	$ccConfig.CodeCoverage.OutputPath = $coverageOutputPath
	$ccConfig.CodeCoverage.OutputFormat = 'JaCoCo'
	$null = Invoke-Pester -Configuration $ccConfig

	# Restore default for subsequent module loads
	Set-PSFConfig -FullName 'SqlLabDataGenerator.Import.DoDotSource' -Value $false

	Write-PSFMessage -Level Important -Message "Code coverage report written to $coverageOutputPath"
}
#endregion Aggregated Code Coverage

$testresults | Sort-Object Describe, Context, Name, Result, Message | Format-List

if ($totalFailed -eq 0) { Write-PSFMessage -Level Host -Message "All <c='em'>$totalRun</c> tests executed without a single failure!" }
else { Write-PSFMessage -Level Warning -Message "<c='em'>$totalFailed tests</c> out of <c='sub'>$totalRun</c> tests failed!" }

if ($totalFailed -gt 0)
{
	throw "$totalFailed / $totalRun tests failed!"
}