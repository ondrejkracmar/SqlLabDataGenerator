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
	# Debug: show git config and GIT_ env vars to understand credential setup
	Write-Host "=== DEBUG: GIT_ environment variables ==="
	Get-ChildItem env: | Where-Object { $_.Name -match '^GIT_' } | ForEach-Object { Write-Host "$($_.Name) = $($_.Value)" }
	Write-Host "=== DEBUG: git config credential/http entries ==="
	git config --list --show-origin 2>&1 | Select-String -Pattern 'credential|extraheader|helper' | ForEach-Object { Write-Host $_ }
	Write-Host "=== DEBUG: parameters ==="
	Write-Host "Org=$AzureDevOpsOrganizationName Project=$AzureDevOpsProjectName Repo=$AzureDevOpsRepositoryName User=$AzureDevOpsUsername TokenLength=$($AzureDevOpsToken.Length)"
	Write-Host "GitHubUser=$GitHubUsername GitHubRepo=$GitHubRepositoryName GitHubTokenLength=$($GitHubToken.Length)"
	Write-Host "=== END DEBUG ==="

	# Exact same approach as PSMicrosoftEntraID
	$encodedAzureDevOpsPAT = [System.Web.HttpUtility]::UrlEncode($AzureDevOpsToken)
	$encodedGitHubToken = [System.Web.HttpUtility]::UrlEncode($GitHubToken)
	$azureRepoUrl = ('https://{0}@dev.azure.com/{1}/{2}/_git/{3}' -f $encodedAzureDevOpsPAT, $AzureDevOpsOrganizationName, $AzureDevOpsProjectName, $AzureDevOpsRepositoryName)
	$gitHubRepoUrl = ('https://{0}:{1}@github.com/{2}/{3}' -f $GitHubUsername, $encodedGitHubToken, $GitHubUsername, $GitHubRepositoryName)

	Write-Host "Cloning $AzureDevOpsRepositoryName from Azure DevOps..."
	git clone --mirror $azureRepoUrl repo.git 2>&1
	if ($LASTEXITCODE -ne 0) { throw "git clone failed with exit code $LASTEXITCODE" }

	Set-Location repo.git

	Write-Host "Adding GitHub remote..."
	git remote add github $gitHubRepoUrl
	git remote -v

	Write-Host "Pushing to GitHub..."
	git push --mirror github 2>&1
	if ($LASTEXITCODE -ne 0) { throw "git push failed with exit code $LASTEXITCODE" }

	Set-Location -Path ..
	Write-Host "Synchronization completed successfully."
} catch {
	Write-Error "An error occurred: $_"
	exit 1
}
