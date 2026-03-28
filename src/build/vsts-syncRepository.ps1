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
	# Azure DevOps clone: use plain URL — 'persistCredentials: true' from checkout provides auth
	$azureRepoUrl = "https://dev.azure.com/${AzureDevOpsOrganizationName}/${AzureDevOpsProjectName}/_git/${AzureDevOpsRepositoryName}"
	# GitHub push: needs explicit PAT since persistCredentials only covers Azure DevOps
	$gitHubRepoUrl = "https://${GitHubUsername}:${GitHubToken}@github.com/${GitHubUsername}/${GitHubRepositoryName}"

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
