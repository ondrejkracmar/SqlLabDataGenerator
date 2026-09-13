function Get-SldgEntityBinding {
	<#
	.SYNOPSIS
		Resolves the PSSqlRepository entity type and column-to-property map for a table.
	.DESCRIPTION
		Connect-SldgDatabase asks PSSqlRepository to import the database schema; every table with a
		single-column primary key comes back with an emitted entity type and a column list that
		says which property each column landed on (a column named "Unit Price" becomes the
		property Unit_Price). The entity read and update paths need both, so this helper turns
		the import result into one binding object per table, or $null when the table has no
		entity (keyless, composite key, view, nothing imported).
	.PARAMETER ConnectionInfo
		The active SqlLabDataGenerator.Connection.
	.PARAMETER SchemaName
		Schema of the table (ignored by engines without schemas).
	.PARAMETER TableName
		The table.
	.OUTPUTS
		PSCustomObject with EntityType, Table (the import entry), KeyColumn, KeyProperty and
		Columns (ordered list of Name / PropertyName / ClrType), or $null.
	#>
	[OutputType([PSCustomObject])]
	[CmdletBinding()]
	param (
		[Parameter(Mandatory)]
		[SqlLabDataGenerator.Connection]$ConnectionInfo,

		[Parameter(Mandatory)]
		[string]$SchemaName,

		[Parameter(Mandatory)]
		[string]$TableName
	)

	$entityType = $ConnectionInfo.FindEntityType($SchemaName, $TableName)
	if (-not $entityType -or -not $ConnectionInfo.SchemaImport) { return $null }

	$imported = $ConnectionInfo.SchemaImport.Tables | Where-Object { $_.EntityType -eq $entityType } | Select-Object -First 1
	if (-not $imported) { return $null }

	$columns = foreach ($column in $imported.Columns) {
		$clrType = $column.ClrType
		$underlying = [System.Nullable]::GetUnderlyingType($clrType)
		[PSCustomObject]@{
			Name         = $column.Name
			PropertyName = $column.PropertyName
			ClrType      = $clrType
			DataType     = if ($underlying) { $underlying } else { $clrType }
			IsPrimaryKey = [bool]$column.IsPrimaryKey
		}
	}
	$key = $columns | Where-Object IsPrimaryKey | Select-Object -First 1

	[PSCustomObject]@{
		EntityType  = $entityType
		Table       = $imported
		KeyColumn   = $key.Name
		KeyProperty = $key.PropertyName
		Columns     = @($columns)
	}
}
