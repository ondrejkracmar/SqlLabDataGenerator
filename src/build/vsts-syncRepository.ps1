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
	# Read the bearer token that persistCredentials stored in the checkout's .git/config
	# This token is KNOWN to work (the checkout step used it successfully)
	$extraHeaderEntry = git config --local --get-regexp 'http\..*\.extraheader' 2>$null
	if (-not $extraHeaderEntry) { throw "No extraheader found in checkout git config. Is persistCredentials: true set?" }

	# Parse: "http.https://org@dev.azure.com/org/project/_git/repo.extraheader AUTHORIZATION: bearer TOKEN"
	$parts = $extraHeaderEntry -split '\s+', 2
	$headerValue = $parts[1]  # AUTHORIZATION: bearer TOKEN

	# Copy the extraheader to global git config so git clone (new repo, no local config) picks it up
	git config --global "http.https://dev.azure.com.extraheader" "$headerValue"

	$azureRepoUrl = ('https://dev.azure.com/{0}/{1}/_git/{2}' -f $AzureDevOpsOrganizationName, $AzureDevOpsProjectName, $AzureDevOpsRepositoryName)
	$encodedGitHubToken = [System.Web.HttpUtility]::UrlEncode($GitHubToken)
	$gitHubRepoUrl = ('https://{0}:{1}@github.com/{2}/{3}' -f $GitHubUsername, $encodedGitHubToken, $GitHubUsername, $GitHubRepositoryName)

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
