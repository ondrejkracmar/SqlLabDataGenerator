<#
Built-in provider registration.
Loaded after configuration.ps1 (alphabetical order) so $script:SldgState is already initialized.
#>
Register-SldgProviderInternal -Name 'SqlServer' -FunctionMap @{
	Connect    = 'Connect-SldgSqlServer'
	GetSchema  = 'Get-SldgSqlServerSchema'
	WriteData  = 'Write-SldgSqlServerData'
	ReadData   = 'Read-SldgSqlServerData'
	Disconnect = 'Disconnect-SldgSqlServer'
}

Register-SldgProviderInternal -Name 'SQLite' -FunctionMap @{
	Connect    = 'Connect-SldgSqlite'
	GetSchema  = 'Get-SldgSqliteSchema'
	WriteData  = 'Write-SldgSqliteData'
	ReadData   = 'Read-SldgSqliteData'
	Disconnect = 'Disconnect-SldgSqlite'
}
