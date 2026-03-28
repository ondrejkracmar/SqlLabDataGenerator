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
	Write-Host "Cloning $AzureDevOpsRepositoryName from Azure DevOps"
	$output = git -c "http.extraheader=Authorization: Basic $azureAuthHeader" clone --mirror $sourceUrl $tempDir 2>&1
	if ($LASTEXITCODE -ne 0) {
		$errorLines = $output | Where-Object { $_ -is [System.Management.Automation.ErrorRecord] } | ForEach-Object { $_.ToString() }
		throw "Failed to clone from Azure DevOps (exit code $LASTEXITCODE): $($errorLines -join '; ')"
	}

	Push-Location $tempDir
	try {
		Write-Host "Pushing to GitHub mirror: $GitHubRepositoryName"
		$output = git -c "http.extraheader=Authorization: Basic $githubAuthHeader" push --mirror $targetUrl 2>&1
		if ($LASTEXITCODE -ne 0) {
			$errorLines = $output | Where-Object { $_ -is [System.Management.Automation.ErrorRecord] } | ForEach-Object { $_.ToString() }
			throw "Failed to push to GitHub (exit code $LASTEXITCODE): $($errorLines -join '; ')"
		}

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
