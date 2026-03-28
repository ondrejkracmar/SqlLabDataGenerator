param (
	[string]$AzureDevOpsOrganizationName,
	[string]$AzureDevOpsProjectName,
	[string]$AzureDevOpsRepositoryName,
	[string]$AzureDevOpsUsername,
	[string]$AzureDevOpsToken,
	[string]$GitHubUsername,
	[string]$GitHubRepositoryName,
	[string]$GitHubToken
)

$ErrorActionPreference = 'Stop'

try {
	# Azure DevOps: PAT goes as password (not username!) in basic auth
	# [uri]::EscapeDataString is available everywhere (.NET Core), unlike [System.Web.HttpUtility]
	$encodedPAT = [uri]::EscapeDataString($AzureDevOpsToken)
	$encodedGitHubToken = [uri]::EscapeDataString($GitHubToken)

	$azureRepoUrl = "https://${AzureDevOpsUsername}:${encodedPAT}@dev.azure.com/${AzureDevOpsOrganizationName}/${AzureDevOpsProjectName}/_git/${AzureDevOpsRepositoryName}"
	$gitHubRepoUrl = "https://${GitHubUsername}:${encodedGitHubToken}@github.com/${GitHubUsername}/${GitHubRepositoryName}"

	Write-Host "Cloning $AzureDevOpsRepositoryName from Azure DevOps..."
	git clone --mirror $azureRepoUrl repo.git 2>&1
	if ($LASTEXITCODE -ne 0) { throw "git clone failed with exit code $LASTEXITCODE" }

	Set-Location repo.git

	Write-Host "Adding GitHub remote..."
	git remote add github $gitHubRepoUrl

	Write-Host "Pushing to GitHub..."
	git push --mirror github 2>&1
	if ($LASTEXITCODE -ne 0) { throw "git push failed with exit code $LASTEXITCODE" }

	Set-Location -Path ..
	Write-Host "Synchronization completed successfully."
} catch {
	Write-Error "An error occurred: $_"
	exit 1
}
