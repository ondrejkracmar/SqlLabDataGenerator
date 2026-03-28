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
	# Azure DevOps clone: use org name as username to match the extraheader URL from persistCredentials
	# persistCredentials sets: http.https://ORG@dev.azure.com/ORG/PROJECT/_git/REPO.extraheader=AUTHORIZATION: bearer <token>
	# Our clone URL must match this pattern exactly for the bearer token to be applied
	$azureRepoUrl = "https://${AzureDevOpsOrganizationName}@dev.azure.com/${AzureDevOpsOrganizationName}/${AzureDevOpsProjectName}/_git/${AzureDevOpsRepositoryName}"
	# GitHub: PAT in URL (no persistCredentials for github.com)
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
