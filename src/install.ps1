<#
	.SYNOPSIS
		Installs the SqlLabDataGenerator Module from github
		
	.DESCRIPTION
		This script installs the SqlLabDataGenerator Module from github.
		
		It does so by ...
		- downloading the specified branch as zip to $env:TEMP
		- Unpacking that zip file to a folder in $env:TEMP
		- Moving that content to a module folder in either program files (default) or the user profile
	
	.PARAMETER Branch
		The branch to install. Installs main by default.
		Unknown branches will terminate the script in error.
	
	.PARAMETER Scope
		By default, the downloaded module will be moved to program files (AllUsers).
		Setting this to 'CurrentUser' installs to the user profile of the current user.

	.PARAMETER Force
		The install script will overwrite an existing module.
#>
[CmdletBinding()]
Param (
	[string]
	$Branch = "main",
	
	[ValidateSet('AllUsers', 'CurrentUser')]
	[string]
	$Scope = "AllUsers",
	
	[switch]
	$Force
)

#region Configuration for cloning script
# Name of the module that is being cloned
$ModuleName = "SqlLabDataGenerator"

# Base path to the github repository
$BaseUrl = "https://github.com/KBConsulting/SqlLabDataGenerator"

# If the module is in a subfolder of the cloned repository, specify relative path here. Empty string to skip.
$SubFolder = "SqlLabDataGenerator"
#endregion Configuration for cloning script

#region Parameter Calculation
$doUserMode = $false
if ($Scope -eq 'CurrentUser') { $doUserMode = $true }

if ($install_Branch) { $Branch = $install_Branch }
#endregion Parameter Calculation

#region Utility Functions
# Note: Expand-Archive polyfill removed — native cmdlet available since PS 5.0+ (module requires PS 5.1+)

function Write-LocalMessage
{
    [CmdletBinding()]
    Param (
        [string]$Message
    )

    if (Test-Path function:Write-PSFMessage) { Write-PSFMessage -Level Important -Message $Message }
    else { Write-Host $Message }
}
#endregion Utility Functions

try
{
	[System.Net.ServicePointManager]::SecurityProtocol = "Tls12"

	Write-LocalMessage -Message "Downloading repository from '$($BaseUrl)/archive/$($Branch).zip'"
	$zipPath = "$($env:TEMP)\$($ModuleName).zip"
	Invoke-WebRequest -Uri "$($BaseUrl)/archive/$($Branch).zip" -UseBasicParsing -OutFile $zipPath -ErrorAction Stop

	# Verify download integrity via SHA256 checksum file (if available)
	$checksumUrl = "$($BaseUrl)/releases/download/$($Branch)/$($ModuleName).sha256"
	try {
		$expectedHash = (Invoke-WebRequest -Uri $checksumUrl -UseBasicParsing -ErrorAction Stop).Content.Trim().Split(' ')[0]
		$actualHash = (Get-FileHash -Path $zipPath -Algorithm SHA256).Hash
		if ($expectedHash -ne $actualHash) {
			Remove-Item -Path $zipPath -Force -ErrorAction SilentlyContinue
			throw "SHA256 checksum mismatch! Expected: $expectedHash, Got: $actualHash. Download may be corrupted or tampered with."
		}
		Write-LocalMessage -Message "SHA256 checksum verified successfully."
	}
	catch [System.Net.WebException] {
		Write-LocalMessage -Message "WARNING: No checksum file found at $checksumUrl — skipping integrity verification."
	}

	Write-LocalMessage -Message "Creating temporary project folder: '$($env:TEMP)\$($ModuleName)'"
	$null = New-Item -Path $env:TEMP -Name $ModuleName -ItemType Directory -Force -ErrorAction Stop
	
	Write-LocalMessage -Message "Extracting archive to '$($env:TEMP)\$($ModuleName)'"
	Expand-Archive -Path "$($env:TEMP)\$($ModuleName).zip" -DestinationPath "$($env:TEMP)\$($ModuleName)" -ErrorAction Stop
	
	$basePath = Get-ChildItem "$($env:TEMP)\$($ModuleName)\*" | Select-Object -First 1
	if ($SubFolder) { $basePath = "$($basePath)\$($SubFolder)" }
	
	# Only needed for PS v5+ but doesn't hurt anyway
	$manifest = "$($basePath)\$($ModuleName).psd1"
	$manifestData = Import-PowerShellDataFile -Path $manifest
	$moduleVersion = $manifestData.ModuleVersion
	Write-LocalMessage -Message "Download concluded: $($ModuleName) | Branch $($Branch) | Version $($moduleVersion)"
	
	# Determine output path
	$path = "$($env:ProgramFiles)\WindowsPowerShell\Modules\$($ModuleName)"
	if ($doUserMode) { $path = "$(Split-Path $profile.CurrentUserAllHosts)\Modules\$($ModuleName)" }
	if ($PSVersionTable.PSVersion.Major -ge 5) { $path += "\$moduleVersion" }
	
	if ((Test-Path $path) -and (-not $Force))
	{
		Write-LocalMessage -Message "Module already installed, interrupting installation"
		return
	}
	
	Write-LocalMessage -Message "Creating folder: $($path)"
	$null = New-Item -Path $path -ItemType Directory -Force -ErrorAction Stop
	
	Write-LocalMessage -Message "Copying files to $($path)"
	foreach ($file in (Get-ChildItem -Path $basePath))
	{
		Move-Item -Path $file.FullName -Destination $path -ErrorAction Stop
	}
	
	Write-LocalMessage -Message "Cleaning up temporary files"
	Remove-Item -Path "$($env:TEMP)\$($ModuleName)" -Force -Recurse
	Remove-Item -Path "$($env:TEMP)\$($ModuleName).zip" -Force
	
	Write-LocalMessage -Message "Installation of the module $($ModuleName), Branch $($Branch), Version $($moduleVersion) completed successfully!"
}
catch
{
	Write-LocalMessage -Message "Installation of the module $($ModuleName) failed!"
	
	Write-LocalMessage -Message "Cleaning up temporary files"
	Remove-Item -Path "$($env:TEMP)\$($ModuleName)" -Force -Recurse
	Remove-Item -Path "$($env:TEMP)\$($ModuleName).zip" -Force
	
	throw
}
