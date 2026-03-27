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

# Verify output in module bin folder (csproj OutputPath places DLL directly there)
$targetDll = Join-Path $WorkingDirectory 'SqlLabDataGenerator\bin\SqlLabDataGenerator.dll'
if (-not (Test-Path $targetDll)) {
	throw "DLL not found at $targetDll after successful build — check csproj OutputPath configuration."
}
Write-PSFMessage -Level Important -Message "SqlLabDataGenerator.dll built successfully at $targetDll"
