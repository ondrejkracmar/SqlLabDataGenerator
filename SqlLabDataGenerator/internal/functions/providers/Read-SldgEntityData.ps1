function Read-SldgEntityData {
	<#
	.SYNOPSIS
		Reads a table through its PSSqlRepository entity type into a DataTable.
	.DESCRIPTION
		The entity read path. Get-PSSqlRepositoryEntity materialises the rows as instances of
		the entity type PSSqlRepository emitted for the table on connect; this function turns
		them back into the DataTable shape the generator works with, using the real column
		names (the entity property Unit_Price fills the column "Unit Price").
	.PARAMETER Binding
		The table binding from Get-SldgEntityBinding.
	.PARAMETER ColumnFilter
		Optional subset of columns to return.
	.PARAMETER TopN
		Maximum number of rows; 0 reads the whole table.
	.OUTPUTS
		System.Data.DataTable
	#>
	[OutputType([System.Data.DataTable])]
	[CmdletBinding()]
	param (
		[Parameter(Mandatory)]
		[PSCustomObject]$Binding,

		[string[]]$ColumnFilter,

		[int]$TopN = 0
	)

	$columns = @($Binding.Columns)
	if ($ColumnFilter) {
		$columns = @($columns | Where-Object { $_.Name -in $ColumnFilter })
	}

	$dataTable = [System.Data.DataTable]::new($Binding.Table.Name)
	foreach ($column in $columns) {
		[void]$dataTable.Columns.Add($column.Name, $column.DataType)
	}

	$queryParams = @{
		EntityType               = $Binding.EntityType
		AsNoTracking             = $true
		SuppressUnboundedWarning = $true
	}
	if ($TopN -gt 0) { $queryParams['Top'] = $TopN }

	# Full entities rather than a -Property projection: a projected row is an object[] and a
	# single-row result would be unrolled by the pipeline into its values. Property getters are
	# resolved once per column.
	$getters = @($columns | ForEach-Object { $Binding.EntityType.GetProperty($_.PropertyName) })
	foreach ($entity in (Get-PSSqlRepositoryEntity @queryParams)) {
		$dataRow = $dataTable.NewRow()
		for ($i = 0; $i -lt $columns.Count; $i++) {
			$value = $getters[$i].GetValue($entity)
			$dataRow[$i] = if ($null -eq $value) { [DBNull]::Value } else { $value }
		}
		$dataTable.Rows.Add($dataRow)
	}

	Write-PSFMessage -Level Verbose -String 'Entity.Read' -StringValues $dataTable.Rows.Count, $Binding.Table.FullName, $Binding.EntityType.FullName
	, $dataTable
}
