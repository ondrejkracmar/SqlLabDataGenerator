function Update-SldgEntityData {
	<#
	.SYNOPSIS
		Writes masked rows back through the PSSqlRepository entity type.
	.DESCRIPTION
		The entity update path of masking mode. Every row of -Data becomes an instance of the
		table's entity type; Save-PSSqlRepositoryEntity -Mode Update loads the tracked rows by
		key in batches, copies the scalar values onto them and lets EF Core issue one UPDATE per
		changed row containing only the changed columns. Keys, identity values and every foreign
		key pointing at the table stay exactly as they were.

		EF's SetValues copies every mapped property, so the caller must hand over complete rows
		(the masking engine reads the table in full before masking). An explicit DbTransaction
		on the raw connection is enlisted on the EF context for the duration of the save.
	.PARAMETER ConnectionInfo
		The active SqlLabDataGenerator.Connection.
	.PARAMETER Binding
		The table binding from Get-SldgEntityBinding.
	.PARAMETER Data
		Complete rows, including the key column and the new values.
	.PARAMETER Transaction
		Optional DbTransaction opened on the connection to enlist in.
	.OUTPUTS
		System.Int32 - number of rows handed to the save.
	#>
	[OutputType([int])]
	[CmdletBinding()]
	param (
		[Parameter(Mandatory)]
		[SqlLabDataGenerator.Connection]$ConnectionInfo,

		[Parameter(Mandatory)]
		[PSCustomObject]$Binding,

		[Parameter(Mandatory)]
		[System.Data.DataTable]$Data,

		[System.Data.Common.DbTransaction]$Transaction
	)

	if ($Data.Rows.Count -eq 0) { return 0 }

	$entityType = $Binding.EntityType
	$setters = @{}
	foreach ($column in $Binding.Columns) {
		$setters[$column.Name] = $entityType.GetProperty($column.PropertyName)
	}

	$entities = [System.Collections.Generic.List[object]]::new($Data.Rows.Count)
	foreach ($row in $Data.Rows) {
		$entity = [System.Activator]::CreateInstance($entityType)
		foreach ($column in $Binding.Columns) {
			$value = $row[$column.Name]
			if ($value -is [DBNull]) { $value = $null }
			$property = $setters[$column.Name]
			if ($null -ne $value -and $value -isnot $column.DataType) {
				$value = [System.Convert]::ChangeType($value, $column.DataType, [System.Globalization.CultureInfo]::InvariantCulture)
			}
			$property.SetValue($entity, $value)
		}
		$entities.Add($entity)
	}

	$context = $ConnectionInfo.Repository.Session.Services.GetService([Microsoft.EntityFrameworkCore.DbContext])
	$enlisted = $false
	try {
		if ($Transaction -and $context) {
			[void][Microsoft.EntityFrameworkCore.RelationalDatabaseFacadeExtensions]::UseTransaction($context.Database, $Transaction)
			$enlisted = $true
		}

		$null = $entities | Save-PSSqlRepositoryEntity -EntityType $entityType -Mode Update -Confirm:$false -ErrorAction Stop
	}
	finally {
		if ($enlisted) {
			try { [void][Microsoft.EntityFrameworkCore.RelationalDatabaseFacadeExtensions]::UseTransaction($context.Database, $null) } catch { $null = $_ }
		}
	}

	Write-PSFMessage -Level Verbose -String 'Entity.Updated' -StringValues $entities.Count, $Binding.Table.FullName, $entityType.FullName
	$entities.Count
}
