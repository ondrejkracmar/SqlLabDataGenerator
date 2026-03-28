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
	# Azure DevOps: use basic auth via http.extraheader (same mechanism as persistCredentials uses for bearer)
	# This bypasses all credential helper/store issues
	$azureRepoUrl = ('https://dev.azure.com/{0}/{1}/_git/{2}' -f $AzureDevOpsOrganizationName, $AzureDevOpsProjectName, $AzureDevOpsRepositoryName)
	$pair = '{0}:{1}' -f $AzureDevOpsUsername, $AzureDevOpsToken
	$base64 = [System.Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes($pair))
	$azureAuthHeader = "AUTHORIZATION: basic $base64"

	$encodedGitHubToken = [System.Web.HttpUtility]::UrlEncode($GitHubToken)
	$gitHubRepoUrl = ('https://{0}:{1}@github.com/{2}/{3}' -f $GitHubUsername, $encodedGitHubToken, $GitHubUsername, $GitHubRepositoryName)

	# Clone the Azure DevOps repository in mirror mode
	Write-PSFMessage -Level Host -Message "Cloning Azure DevOps repository..."
	git -c "http.extraheader=$azureAuthHeader" clone --mirror $azureRepoUrl repo.git

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
