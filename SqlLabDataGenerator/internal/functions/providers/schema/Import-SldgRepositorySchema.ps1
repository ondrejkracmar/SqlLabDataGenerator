function Import-SldgRepositorySchema {
	<#
	.SYNOPSIS
		Reads the connected database's catalogue through PSSqlRepository without registering anything.
	.DESCRIPTION
		Wraps Import-PSSqlRepositorySchema -NoRegister for the schema reader. The connect
		parameters Connect-SldgDatabase used (provider parameters, authentication mode,
		credential) are replayed so the catalogue is read the same way the session was opened;
		a connection built without them (test helpers, a hand-made Connection) falls back to the
		raw connection string of its DbConnection. The result is cached on the connection
		(SchemaImport) so the entity binding sees the same snapshot the schema model was built from.
	.PARAMETER ConnectionInfo
		The active SqlLabDataGenerator.Connection.
	.OUTPUTS
		PSSqlRepository.Core.Schema.SqlSchemaImportResult
	#>
	[CmdletBinding()]
	param (
		[Parameter(Mandatory)]
		[SqlLabDataGenerator.Connection]$ConnectionInfo
	)

	if (-not (Get-Command -Name Import-PSSqlRepositorySchema -ErrorAction SilentlyContinue)) {
		Stop-PSFFunction -String 'Connect.PSSqlRepositoryMissing' -EnableException $true
	}

	$connectParams = @{}
	if ($ConnectionInfo.ConnectParameters) {
		foreach ($key in $ConnectionInfo.ConnectParameters.Keys) { $connectParams[$key] = $ConnectionInfo.ConnectParameters[$key] }
	}
	elseif ($ConnectionInfo.DbConnection) {
		$connectParams['ConnectionString'] = $ConnectionInfo.DbConnection.ConnectionString
	}
	else {
		Stop-PSFFunction -String 'Connect.NoActiveConnection' -EnableException $true
	}

	$import = Import-PSSqlRepositorySchema -ProviderName $ConnectionInfo.Provider @connectParams -NoRegister -Confirm:$false -WarningAction SilentlyContinue -ErrorAction Stop
	$ConnectionInfo.SchemaImport = $import
	$import
}
