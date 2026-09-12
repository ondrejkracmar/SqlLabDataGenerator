function Set-SldgPrimaryKeyStartValue {
	<#
	.SYNOPSIS
		Bootstraps PKStartValue for non-identity integer primary keys by querying MAX(PK).
	.DESCRIPTION
		Extracted from Invoke-SldgDataGeneration. Mutates the columns of TableInfo in place
		(PSCustomObjects are reference types so this is safe), adding a PKStartValue note
		property to each non-identity, non-FK integer PK column. Failures are logged and
		swallowed — generation can still proceed using a default starting value.
	#>
	[CmdletBinding()]
	param (
		[Parameter(Mandatory)]
		[SqlLabDataGenerator.TableInfo]$TableInfo,

		[Parameter(Mandatory)]
		[SqlLabDataGenerator.TablePlan]$TablePlan,

		[Parameter(Mandatory)]
		[SqlLabDataGenerator.Connection]$ConnectionInfo,

		[System.Data.Common.DbTransaction]$Transaction,

		[int]$CommandTimeout = 30
	)

	foreach ($col in $TableInfo.Columns) {
		if (-not ($col.IsPrimaryKey -and -not $col.IsIdentity -and -not $col.IsComputed -and -not $col.ForeignKey -and $col.DataType -match '^(int|bigint|smallint|tinyint)$')) {
			continue
		}

		try {
			$dialect = $ConnectionInfo.GetDialect()
			$safeTbl = $dialect.QualifiedName($TablePlan.SchemaName, $TablePlan.TableName)
			$safeCol = $dialect.QuoteIdentifier($col.ColumnName)
			$cmd = $ConnectionInfo.DbConnection.CreateCommand()
			if ($Transaction) { $cmd.Transaction = $Transaction }
			$cmd.CommandText = $dialect.SelectMaxOrZero($safeTbl, $safeCol)
			$cmd.CommandTimeout = $CommandTimeout
			$maxVal = $cmd.ExecuteScalar()
			$cmd.Dispose()
			$col.PKStartValue = [long]$maxVal
		}
		catch {
			Write-PSFMessage -Level Verbose -Message ($script:strings.'Generation.MaxPKQueryFailed' -f $col.ColumnName, $_)
		}
	}
}
