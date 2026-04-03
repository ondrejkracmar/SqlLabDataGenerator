param (
    [string]
    $Repository = 'PSGallery'
)

$modules = @(
    'Pester'
    'PSFramework'
    'PSModuleDevelopment'
    'PSScriptAnalyzer'
)

# Automatically add missing dependencies from module manifest
$data = Import-PowerShellDataFile -Path "$PSScriptRoot\..\SqlLabDataGenerator\SqlLabDataGenerator.psd1"
foreach ($dependency in $data.RequiredModules) {
    $name = if ($dependency -is [string]) { $dependency } else { $dependency.ModuleName }
    if ($name -notin $modules) { $modules += $name }
}

foreach ($module in $modules) {
    Write-Host "Installing $module"
    Install-Module $module -Force -SkipPublisherCheck -Repository $Repository -ErrorAction Stop
    Import-Module $module -Force -PassThru
}