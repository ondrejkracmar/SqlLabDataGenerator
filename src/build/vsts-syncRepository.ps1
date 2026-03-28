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
	$azureRepoUrl = "https://dev.azure.com/${AzureDevOpsOrganizationName}/${AzureDevOpsProjectName}/_git/${AzureDevOpsRepositoryName}"
	$gitHubRepoUrl = "https://${GitHubUsername}:${GitHubToken}@github.com/${GitHubUsername}/${GitHubRepositoryName}"

	# Build URL-specific extraheader — highest specificity overrides persistCredentials config
	$base64Auth = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes("${AzureDevOpsUsername}:${AzureDevOpsToken}"))
	$headerConfig = "http.${azureRepoUrl}.extraheader=Authorization: Basic ${base64Auth}"

	Write-Host "Cloning $AzureDevOpsRepositoryName from Azure DevOps..."
	git -c $headerConfig clone --mirror $azureRepoUrl repo.git 2>&1
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
