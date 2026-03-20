<#
	.SYNOPSIS
		Publishes the SqlLabDataGenerator NuGet package to Azure Artifacts.
	.DESCRIPTION
		Pushes a pre-built .nupkg file to an Azure Artifacts NuGet feed.
		The nupkg is expected to already exist (built by vsts-build.ps1
		and downloaded as a pipeline artifact).
#>
param (
	[string]$WorkingDirectory,

	[Parameter(Mandatory)]
	[string]$OrganizationName,

	[Parameter(Mandatory)]
	[string]$ProjectName,

	[Parameter(Mandatory)]
	[string]$ArtifactRepositoryName,

	[Parameter(Mandatory)]
	[string]$ArtifactFeedName,

	[Parameter(Mandatory)]
	[string]$FeedUsername,

	[Parameter(Mandatory)]
	[string]$PersonalAccessToken,

	[string]$NupkgPath
)

if (-not $WorkingDirectory) {
	if ($env:SYSTEM_DEFAULTWORKINGDIRECTORY) { $WorkingDirectory = $env:SYSTEM_DEFAULTWORKINGDIRECTORY }
	else { $WorkingDirectory = Split-Path $PSScriptRoot }
}

# Locate the nupkg — either passed explicitly or search common locations
if (-not $NupkgPath) {
	# Pipeline artifact download location
	$artifactDir = if ($env:PIPELINE_WORKSPACE) { Join-Path $env:PIPELINE_WORKSPACE 'NuGetPackage' } else { $null }

	$searchPaths = @($WorkingDirectory)
	if ($artifactDir -and (Test-Path $artifactDir)) { $searchPaths = @($artifactDir) + $searchPaths }

	foreach ($searchPath in $searchPaths) {
		$found = Get-ChildItem -Path $searchPath -Filter 'SqlLabDataGenerator*.nupkg' -ErrorAction SilentlyContinue | Select-Object -First 1
		if ($found) { $NupkgPath = $found.FullName; break }
	}
}

if (-not $NupkgPath -or -not (Test-Path $NupkgPath)) {
	throw "No .nupkg file found. Searched: $($searchPaths -join ', '). Run vsts-build.ps1 first."
}

$feedUrl = "https://pkgs.dev.azure.com/$OrganizationName/$ProjectName/_packaging/$ArtifactFeedName/nuget/v3/index.json"

Write-Host "Publishing $NupkgPath to $ArtifactRepositoryName ($feedUrl)"

dotnet nuget push $NupkgPath --source $feedUrl --api-key "az" --skip-duplicate

if ($LASTEXITCODE -ne 0) {
	throw "Failed to push NuGet package. Exit code: $LASTEXITCODE"
}

Write-Host "Successfully published $(Split-Path $NupkgPath -Leaf)"
