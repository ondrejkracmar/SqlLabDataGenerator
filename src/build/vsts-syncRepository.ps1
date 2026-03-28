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
	# Write Azure DevOps credentials directly to git-credentials file
	# and force credential.helper=store via -c (highest precedence, overrides any helper from persistCredentials)
	$azureRepoUrl = ('https://dev.azure.com/{0}/{1}/_git/{2}' -f $AzureDevOpsOrganizationName, $AzureDevOpsProjectName, $AzureDevOpsRepositoryName)
	$encodedGitHubToken = [System.Web.HttpUtility]::UrlEncode($GitHubToken)
	$gitHubRepoUrl = ('https://{0}:{1}@github.com/{2}/{3}' -f $GitHubUsername, $encodedGitHubToken, $GitHubUsername, $GitHubRepositoryName)

	$credentialUrl = 'https://{0}:{1}@dev.azure.com' -f [uri]::EscapeDataString($AzureDevOpsUsername), [uri]::EscapeDataString($AzureDevOpsToken)
	Set-Content -Path "$HOME/.git-credentials" -Value $credentialUrl -Force

	# Clone the Azure DevOps repository in mirror mode
	# -c credential.helper=store forces reading from ~/.git-credentials, bypassing any other credential config
	Write-PSFMessage -Level Host -Message "Cloning Azure DevOps repository..."
	git -c credential.helper=store clone --mirror $azureRepoUrl repo.git

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
