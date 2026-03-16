<#
	.SYNOPSIS
		Publishes the SqlLabDataGenerator NuGet package to Azure Artifacts.
	.DESCRIPTION
		Registers an Azure Artifacts PowerShell repository and pushes
		the module NuGet package built by vsts-build.ps1.
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

	[Parameter(Mandatory)]
	[string]$ModuleName,

	[Parameter(Mandatory)]
	[string]$ModuleVersion,

	[string]$PreRelease,

	[string]$CommitsSinceVersion
)

if (-not $WorkingDirectory) {
	if ($env:SYSTEM_DEFAULTWORKINGDIRECTORY) { $WorkingDirectory = $env:SYSTEM_DEFAULTWORKINGDIRECTORY }
	else { $WorkingDirectory = Split-Path $PSScriptRoot }
}

$feedUrl = "https://pkgs.dev.azure.com/$OrganizationName/_packaging/$ArtifactFeedName/nuget/v2"

# Register the feed as a PS repository
$repoParams = @{
	Name               = $ArtifactRepositoryName
	SourceLocation     = $feedUrl
	PublishLocation    = $feedUrl
	InstallationPolicy = 'Trusted'
}

$existingRepo = Get-PSRepository -Name $ArtifactRepositoryName -ErrorAction SilentlyContinue
if ($existingRepo) {
	Set-PSRepository @repoParams
}
else {
	Register-PSRepository @repoParams
}

# Create credential for the feed
$password = ConvertTo-SecureString -String $PersonalAccessToken -AsPlainText -Force
$credential = [PSCredential]::new($FeedUsername, $password)

# Locate the built module
$publishDir = Join-Path $WorkingDirectory 'publish'
$modulePath = Join-Path $publishDir $ModuleName

if (-not (Test-Path $modulePath)) {
	throw "Module not found at $modulePath. Run vsts-build.ps1 first."
}

# Update manifest version to match pipeline version
$manifestPath = Join-Path $modulePath "$ModuleName.psd1"
$versionString = $ModuleVersion
if ($PreRelease -and $PreRelease -ne '') {
	$preReleaseTag = "$PreRelease$CommitsSinceVersion"
	Update-ModuleManifest -Path $manifestPath -ModuleVersion $ModuleVersion -Prerelease $preReleaseTag
}
else {
	Update-ModuleManifest -Path $manifestPath -ModuleVersion $ModuleVersion
}

Write-PSFMessage -Level Important -Message "Publishing $ModuleName v$versionString to $ArtifactRepositoryName"

Publish-Module -Path $modulePath -Repository $ArtifactRepositoryName -NuGetApiKey $PersonalAccessToken -Credential $credential -Force

Write-PSFMessage -Level Important -Message "Successfully published $ModuleName v$versionString"
