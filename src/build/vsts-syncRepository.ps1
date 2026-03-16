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

$sourceUrl = "https://dev.azure.com/${AzureDevOpsOrganizationName}/${AzureDevOpsProjectName}/_git/${AzureDevOpsRepositoryName}"
$targetUrl = "https://github.com/${GitHubUsername}/${GitHubRepositoryName}.git"

# Use extraheader for auth — avoids embedding tokens in URLs (which can leak in logs/stack traces)
$azureAuthHeader = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes(":${AzureDevOpsToken}"))
$githubAuthHeader = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes(":${GitHubToken}"))

$tempDir = Join-Path ([System.IO.Path]::GetTempPath()) "repo-sync-$([Guid]::NewGuid().ToString('N').Substring(0,8))"

try {
	Write-PSFMessage -Level Important -Message "Cloning $AzureDevOpsRepositoryName from Azure DevOps"
	git -c "http.extraheader=Authorization: Basic $azureAuthHeader" clone --mirror $sourceUrl $tempDir 2>&1 | Out-Null
	if ($LASTEXITCODE -ne 0) { throw "Failed to clone from Azure DevOps" }

	Push-Location $tempDir
	try {
		Write-PSFMessage -Level Important -Message "Pushing to GitHub mirror: $GitHubRepositoryName"
		git -c "http.extraheader=Authorization: Basic $githubAuthHeader" push --mirror $targetUrl 2>&1 | Out-Null
		if ($LASTEXITCODE -ne 0) { throw "Failed to push to GitHub" }

		Write-PSFMessage -Level Important -Message "Repository synchronized successfully"
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
