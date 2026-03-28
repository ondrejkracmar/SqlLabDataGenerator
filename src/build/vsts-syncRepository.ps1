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
	# Construct the Azure DevOps and GitHub repository URLs
	$encodedAzureDevOpsPAT = [uri]::EscapeDataString($AzureDevOpsToken)
	$encodedGitHubToken = [uri]::EscapeDataString($GitHubToken)
	$azureRepoUrl = ('https://{0}@dev.azure.com/{1}/{2}/_git/{3}' -f $encodedAzureDevOpsPAT, $AzureDevOpsOrganizationName, $AzureDevOpsProjectName, $AzureDevOpsRepositoryName)
	$gitHubRepoUrl = ('https://{0}:{1}@github.com/{2}/{3}' -f $GitHubUsername, $encodedGitHubToken, $GitHubUsername, $GitHubRepositoryName)

	# Configure Git to use credentials for Azure DevOps (double-quoted so variables expand)
	Write-Host "Configuring Git credentials for Azure DevOps..."
	$credentialAzureDevOpsContent = @"
protocol=https
host=dev.azure.com
username=$AzureDevOpsUsername
password=$AzureDevOpsToken
"@

	$tempCredentialFile = New-TemporaryFile
	$credentialAzureDevOpsContent | Set-Content -Path $tempCredentialFile.FullName

	# Pipe credentials to Git credential helper
	Get-Content $tempCredentialFile.FullName | git credential approve

	# Remove temporary credential file
	Remove-Item $tempCredentialFile.FullName

	# Clone the Azure DevOps repository in mirror mode
	Write-Host "Cloning Azure DevOps repository..."
	git clone --mirror $azureRepoUrl repo.git
	if ($LASTEXITCODE -ne 0) { throw "git clone failed with exit code $LASTEXITCODE" }

	Set-Location repo.git

	# Add GitHub as a remote repository
	Write-Host "Adding GitHub remote repository..."
	git remote add github $gitHubRepoUrl
	git remote -v

	# Push to GitHub
	Write-Host "Pushing to GitHub..."
	git push --mirror github
	if ($LASTEXITCODE -ne 0) { throw "git push failed with exit code $LASTEXITCODE" }

	# Return to the original directory
	Set-Location -Path ..
	Write-Host "Synchronization completed successfully."
} catch {
	Write-Error "An error occurred: $_"
	exit 1
}
