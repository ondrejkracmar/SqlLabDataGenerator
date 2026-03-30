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
if ($NupkgPath -and (Test-Path $NupkgPath -PathType Container)) {
	# A directory was passed — search for nupkg inside it
	$found = Get-ChildItem -Path $NupkgPath -Filter 'SqlLabDataGenerator*.nupkg' -ErrorAction SilentlyContinue | Select-Object -First 1
	if ($found) { $NupkgPath = $found.FullName }
	else { $NupkgPath = $null }
}

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

$feedUrl = "https://pkgs.dev.azure.com/$OrganizationName/$ArtifactRepositoryName/_packaging/$ArtifactFeedName/nuget/v3/index.json"

# Add authenticated source for the push
# Use NuGetAuthenticate@1 task token when available (pipeline), fall back to PAT for local use
$sourceName = "AzArtifactsPush"
$null = dotnet nuget remove source $sourceName 2>&1
if ($env:VSS_NUGET_EXTERNAL_FEED_ENDPOINTS) {
	# Pipeline context: NuGetAuthenticate@1 has already configured credentials
	dotnet nuget add source $feedUrl --name $sourceName
}
else {
	# Local/manual context: prefer Azure Artifacts Credential Provider if installed,
	# then NUGET_PAT env var, then PAT parameter (least secure)
	$credProviderPath = Join-Path $env:USERPROFILE '.nuget' 'plugins'
	$hasCredProvider = Test-Path (Join-Path $credProviderPath 'netcore') -ErrorAction SilentlyContinue

	if ($hasCredProvider) {
		Write-Host "Using Azure Artifacts Credential Provider for authentication."
		$env:VSS_NUGET_EXTERNAL_FEED_ENDPOINTS = @{
			endpointCredentials = @(@{ endpoint = $feedUrl })
		} | ConvertTo-Json -Compress
		dotnet nuget add source $feedUrl --name $sourceName
	}
	elseif ($env:NUGET_PAT) {
		Write-Host "Using NUGET_PAT environment variable for authentication."
		Write-Warning "Consider installing the Azure Artifacts Credential Provider to avoid storing credentials in config: https://github.com/microsoft/artifacts-credprovider"
		dotnet nuget add source $feedUrl --name $sourceName --username $FeedUsername --password $env:NUGET_PAT --store-password-in-clear-text
	}
	else {
		Write-Warning "Storing PAT in clear text. This is the least secure option."
		Write-Warning "Preferred alternatives (in order):"
		Write-Warning "  1. Install Azure Artifacts Credential Provider: https://github.com/microsoft/artifacts-credprovider"
		Write-Warning "  2. Set NUGET_PAT environment variable with your Personal Access Token"
		dotnet nuget add source $feedUrl --name $sourceName --username $FeedUsername --password $PersonalAccessToken --store-password-in-clear-text
	}
}

Write-Host "Publishing $NupkgPath to $ArtifactRepositoryName ($feedUrl)"

dotnet nuget push $NupkgPath --source $sourceName --api-key "az" --skip-duplicate

if ($LASTEXITCODE -ne 0) {
	throw "Failed to push NuGet package. Exit code: $LASTEXITCODE"
}

Write-Host "Successfully published $(Split-Path $NupkgPath -Leaf)"
