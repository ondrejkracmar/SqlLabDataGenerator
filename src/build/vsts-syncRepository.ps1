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

try {
	# Construct repository URLs
	# Azure DevOps: NO credentials in URL - they come from credential store (set up below)
	# If credentials are in URL, git uses that username and ignores credential store
	$azureRepoUrl = ('https://dev.azure.com/{0}/{1}/_git/{2}' -f $AzureDevOpsOrganizationName, $AzureDevOpsProjectName, $AzureDevOpsRepositoryName)
	$encodedGitHubToken = [System.Web.HttpUtility]::UrlEncode($GitHubToken)
	$gitHubRepoUrl = ('https://{0}:{1}@github.com/{2}/{3}' -f $GitHubUsername, $encodedGitHubToken, $GitHubUsername, $GitHubRepositoryName)

	# Configure Git credential helper so credential approve actually stores credentials
	Write-PSFMessage -Level Host -Message "Configuring Git credentials for Azure DevOps..."
	git config --global credential.helper store

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
	Write-PSFMessage -Level Host -Message "Cloning Azure DevOps repository..."
	git clone --mirror $azureRepoUrl repo.git

	# Navigate into the cloned repository
	Set-Location repo.git

	# Add GitHub as a remote repository
	Write-PSFMessage -Level Host -Message "Adding GitHub remote repository..."
	git remote add github $gitHubRepoUrl
	git remote -v

	# Push to GitHub
	Write-PSFMessage -Level Host -Message "Pushing to GitHub..."
	git push --mirror github

	# Return to the original directory
	Set-Location -Path ..
	Write-PSFMessage -Level Important -Message "Synchronization completed successfully."
} catch {
	Stop-PSFFunction -Message "An error occurred" -EnableException $true -ErrorRecord $_
}
