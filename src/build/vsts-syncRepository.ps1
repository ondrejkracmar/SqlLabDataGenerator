<#
	.SYNOPSIS
		Synchronizes Azure DevOps repository with a GitHub mirror.
	.DESCRIPTION
		Pushes the current branch to the corresponding GitHub repository,
		keeping public and internal repos in sync.
#>
param (
	[Parameter(Mandatory)]
	[string]$AzureDevOpsOrganizationName,

	[Parameter(Mandatory)]
	[string]$AzureDevOpsProjectName,

	[Parameter(Mandatory)]
	[string]$AzureDevOpsRepositoryName,

	[Parameter(Mandatory)]
	[string]$AzureDevOpsUsername,

	[Parameter(Mandatory)]
	[string]$AzureDevOpsToken,

	[Parameter(Mandatory)]
	[string]$GitHubRepositoryName,

	[Parameter(Mandatory)]
	[string]$GitHubUsername,

	[Parameter(Mandatory)]
	[string]$GitHubToken
)

$encodedAzureDevOpsPAT = [System.Web.HttpUtility]::UrlEncode($AzureDevOpsToken)
$encodedGitHubToken = [System.Web.HttpUtility]::UrlEncode($GitHubToken)

$azureRepoUrl = "https://${encodedAzureDevOpsPAT}@dev.azure.com/${AzureDevOpsOrganizationName}/${AzureDevOpsProjectName}/_git/${AzureDevOpsRepositoryName}"
$gitHubRepoUrl = "https://${GitHubUsername}:${encodedGitHubToken}@github.com/${GitHubUsername}/${GitHubRepositoryName}.git"

$tempDir = Join-Path ([System.IO.Path]::GetTempPath()) "repo-sync-$([Guid]::NewGuid().ToString('N').Substring(0,8))"

try {
	# Disable any credential helper set by 'persistCredentials: true' in the pipeline checkout step
	Write-Host "Cloning $AzureDevOpsRepositoryName from Azure DevOps"
	git -c credential.helper= clone --mirror $azureRepoUrl $tempDir 2>&1
	if ($LASTEXITCODE -ne 0) { throw "Failed to clone from Azure DevOps (exit code $LASTEXITCODE)" }

	Push-Location $tempDir
	try {
		Write-Host "Adding GitHub remote: $GitHubRepositoryName"
		git remote add github $gitHubRepoUrl 2>&1

		Write-Host "Pushing to GitHub mirror: $GitHubRepositoryName"
		git -c credential.helper= push --mirror github 2>&1
		if ($LASTEXITCODE -ne 0) { throw "Failed to push to GitHub (exit code $LASTEXITCODE)" }

		Write-Host "Repository synchronized successfully"
	}
	finally {
		Pop-Location
	}
}
finally {
	if (Test-Path $tempDir) {
		Remove-Item -Path $tempDir -Recurse -Force -ErrorAction SilentlyContinue
	}
}
