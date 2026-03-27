<#
	.SYNOPSIS
		Builds the SqlLabDataGenerator C# library.
	.DESCRIPTION
		Compiles the SqlLabDataGenerator.dll from the library/ solution.
		Only needed if the module uses a companion .NET assembly.
#>
param (
	[string]$WorkingDirectory
)

if (-not $WorkingDirectory) {
	if ($env:SYSTEM_DEFAULTWORKINGDIRECTORY) { $WorkingDirectory = $env:SYSTEM_DEFAULTWORKINGDIRECTORY }
	else { $WorkingDirectory = Split-Path $PSScriptRoot }
}

$solutionPath = Join-Path $WorkingDirectory 'library\SqlLabDataGenerator.sln'

if (-not (Test-Path $solutionPath)) {
	Write-PSFMessage -Level Warning -Message "Solution not found at $solutionPath — skipping library build."
	return
}

Write-PSFMessage -Level Important -Message "Building SqlLabDataGenerator library"
dotnet build $solutionPath --configuration Release

if ($LASTEXITCODE -ne 0) {
	throw "Failed to build SqlLabDataGenerator.dll! Exit code: $LASTEXITCODE"
}

# Copy output to module bin folder
$outputDll = Join-Path $WorkingDirectory 'library\SqlLabDataGenerator\SqlLabDataGenerator\bin\Release\net*\SqlLabDataGenerator.dll'
$targetBin = Join-Path $WorkingDirectory 'SqlLabDataGenerator\bin'

$dll = Get-ChildItem -Path $outputDll -ErrorAction SilentlyContinue | Select-Object -First 1
if (-not $dll) {
	throw "DLL not found at $outputDll after successful build — check build output configuration."
}
Copy-Item -Path $dll.FullName -Destination $targetBin -Force
Write-PSFMessage -Level Important -Message "Copied $($dll.Name) to module bin folder"
