$script:ModuleRoot = $PSScriptRoot

foreach ($file in (Get-ChildItem -Path "$script:ModuleRoot\internal\configurations" -Recurse -Filter '*.ps1' -ErrorAction SilentlyContinue))
{
	try { . $file.FullName }
	catch { Write-Warning "Failed to load configuration file '$($file.Name)': $_" }
}
foreach ($file in (Get-ChildItem -Path "$script:ModuleRoot\internal\functions" -Recurse -Filter '*.ps1' -ErrorAction SilentlyContinue))
{
	try { . $file.FullName }
	catch { Write-Warning "Failed to load internal function '$($file.Name)': $_" }
}
foreach ($file in (Get-ChildItem -Path "$script:ModuleRoot\functions" -Recurse -Filter '*.ps1' -ErrorAction SilentlyContinue))
{
	try { . $file.FullName }
	catch { Write-Warning "Failed to load function '$($file.Name)': $_" }
}