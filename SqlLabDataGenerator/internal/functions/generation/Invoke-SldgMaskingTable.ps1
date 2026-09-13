function Invoke-SldgMaskingTable {
	<#
	.SYNOPSIS
		Masks PII columns in a single table by reading, replacing, and re-inserting data.
	.DESCRIPTION
		Reads existing rows from the table, replaces PII and custom-rule columns with
		generated values, then deletes and re-inserts the data. Designed to be called
		from Invoke-SldgDataGeneration for each table in Masking mode.
	#>
	[CmdletBinding()]
	param (
		[Parameter(Mandatory)]
		[SqlLabDataGenerator.TablePlan]$TablePlan,

		[Parameter(Mandatory)]
		[SqlLabDataGenerator.Connection]$ConnectionInfo,

		[Parameter(Mandatory)]
		[SqlLabDataGenerator.SqlProvider]$Provider,

		[Parameter(Mandatory)]
		[SqlLabDataGenerator.GenerationPlan]$Plan,

		[System.Data.Common.DbTransaction]$Transaction,

		[int]$BatchSize = 1000,

		[switch]$NoInsert,

		[switch]$PassThru
	)

	# Read existing data
	$readParams = @{
		ConnectionInfo = $ConnectionInfo
		SchemaName     = $TablePlan.SchemaName
		TableName      = $TablePlan.TableName
	}
	if ($Transaction) { $readParams['Transaction'] = $Transaction }
	$existingData = & $Provider.FunctionMap.ReadData @readParams

	# Safety guard: skip masking if no rows were read (prevents data loss from DELETE)
	if (-not $existingData -or $existingData.Rows.Count -eq 0) {
		Write-PSFMessage -Level Warning -Message ($script:strings.'Generation.MaskingNoRows' -f $TablePlan.FullName)
		return [SqlLabDataGenerator.TableResult]@{
			TableName = $TablePlan.FullName
			RowCount  = 0
			Success   = $true
			Error     = 'Skipped — no rows to mask'
		}
	}

	# Mask PII columns using the generation plan rules
	$tableRules = if ($Plan.GenerationRules.ContainsKey($TablePlan.FullName)) { $Plan.GenerationRules[$TablePlan.FullName] } else { $null }
	$generatorMap = if ($Plan.GeneratorMap) { $Plan.GeneratorMap } else { Get-SldgGeneratorMap }

	foreach ($row in $existingData.Rows) {
		foreach ($col in $TablePlan.Columns) {
			if (-not $col.IsPII -and -not ($tableRules -and $tableRules.ContainsKey($col.ColumnName))) { continue }
			if ($col.Skip -or $col.IsPrimaryKey) { continue }

			$colObj = [PSCustomObject]@{
				ColumnName   = $col.ColumnName
				DataType     = $col.DataType
				SemanticType = $col.SemanticType
				MaxLength    = $col.MaxLength
				IsNullable   = $col.IsNullable
				IsIdentity   = [bool]$col.IsIdentity
				IsComputed   = [bool]$col.IsComputed
				IsPrimaryKey = [bool]$col.IsPrimaryKey
				ForeignKey   = $null
			}
			$customRule = if ($tableRules -and $tableRules.ContainsKey($col.ColumnName)) { $tableRules[$col.ColumnName] } else { $null }
			$maskedValue = New-SldgGeneratedValue -Column $colObj -GeneratorMap $generatorMap -CustomRule $customRule -NullProbability 0

			# A mask that lands on the original value hides nothing: 'John' drawn from the first-name
			# pool for a row that already says 'John' leaks the PII the run is meant to remove. Draw
			# again a few times; tiny value spaces (bit, one-member rules) may legitimately repeat.
			$original = $row[$col.ColumnName]
			$attempt = 0
			while ($attempt -lt 5 -and $null -ne $maskedValue -and $null -ne $original -and $original -isnot [DBNull] -and [string]$maskedValue -eq [string]$original) {
				$maskedValue = New-SldgGeneratedValue -Column $colObj -GeneratorMap $generatorMap -CustomRule $customRule -NullProbability 0
				$attempt++
			}
			if ($null -ne $maskedValue) {
				$row[$col.ColumnName] = $maskedValue
			}
		}
	}

	$insertedCount = $existingData.Rows.Count
	$keyColumns = @($TablePlan.Columns | Where-Object IsPrimaryKey | ForEach-Object ColumnName)
	$maskedColumns = @($TablePlan.Columns | Where-Object { ($_.IsPII -or ($tableRules -and $tableRules.ContainsKey($_.ColumnName))) -and -not $_.Skip -and -not $_.IsPrimaryKey } | ForEach-Object ColumnName)
	if (-not $NoInsert -and $keyColumns.Count -gt 0) {
		# Masking with a primary key: UPDATE the masked columns in place. Keys, identity values
		# and every foreign key pointing at this table stay exactly as they were - a delete and
		# re-insert would either fail on the referencing rows or renumber the keys.
		$updateParams = @{
			ConnectionInfo = $ConnectionInfo
			SchemaName     = $TablePlan.SchemaName
			TableName      = $TablePlan.TableName
			Data           = $existingData
			KeyColumn      = $keyColumns
			Column         = $maskedColumns
		}
		if ($Transaction) { $updateParams['Transaction'] = $Transaction }
		$insertedCount = if ($maskedColumns.Count -gt 0) { Update-SldgTableData @updateParams } else { 0 }
		if ($maskedColumns.Count -eq 0) { Write-PSFMessage -Level Warning -String 'Generation.MaskingNoColumns' -StringValues $TablePlan.FullName }
	}
	elseif (-not $NoInsert) {
		# No primary key: the only way to write the rows back is delete + re-insert. Wrap it in
		# a local transaction if none was provided to prevent data loss on partial failure.
		Write-PSFMessage -Level Warning -String 'Generation.MaskingNoKey' -StringValues $TablePlan.FullName
		$localTransaction = $null
		if (-not $Transaction) {
			$localTransaction = $ConnectionInfo.DbConnection.BeginTransaction()
			$Transaction = $localTransaction
		}
		try {
			$deleteParams = @{
				ConnectionInfo = $ConnectionInfo
				SchemaName     = $TablePlan.SchemaName
				TableName      = $TablePlan.TableName
			}
			if ($Transaction) { $deleteParams['Transaction'] = $Transaction }
			if ($Provider.FunctionMap.ContainsKey('DeleteData')) {
				& $Provider.FunctionMap.DeleteData @deleteParams
			}
			else {
				# Fallback: execute DELETE directly
				$delCmd = $ConnectionInfo.DbConnection.CreateCommand()
				if ($Transaction) { $delCmd.Transaction = $Transaction }
				$safeName = Get-SldgSafeSqlName -SchemaName $TablePlan.SchemaName -TableName $TablePlan.TableName -ConnectionInfo $ConnectionInfo
				$delCmd.CommandText = "DELETE FROM $safeName"
				[void]$delCmd.ExecuteNonQuery()
				$delCmd.Dispose()
			}

			$writeParams = @{
				ConnectionInfo = $ConnectionInfo
				SchemaName     = $TablePlan.SchemaName
				TableName      = $TablePlan.TableName
				Data           = $existingData
				BatchSize      = $BatchSize
			}
			if ($Transaction) { $writeParams['Transaction'] = $Transaction }
			# The rows go back with their original keys: identity columns must keep their values,
			# or every child row that references them is orphaned by the delete/re-insert.
			if (@($TablePlan.Columns | Where-Object IsIdentity).Count -gt 0) { $writeParams['IdentityInsert'] = $true }
			$insertedCount = & $Provider.FunctionMap.WriteData @writeParams

			if ($localTransaction) { $localTransaction.Commit() }
		}
		catch {
			if ($localTransaction) {
				try { $localTransaction.Rollback() } catch { $null = $_ }
			}
			Stop-PSFFunction -Message $_.Exception.Message -ErrorRecord $_ -EnableException $true
			return
		}
		finally {
			if ($localTransaction) { $localTransaction.Dispose() }
			$existingData.Dispose()
		}
	}

	Write-PSFMessage -Level Host -Message ($script:strings.'Generation.MaskingComplete' -f $TablePlan.SchemaName, $TablePlan.TableName, $insertedCount)

	$tableResult = [SqlLabDataGenerator.TableResult]@{
		TableName = $TablePlan.FullName
		RowCount  = $insertedCount
		Success   = $true
		Error     = $null
	}
	if ($PassThru) {
		$tableResult.DataTable = $existingData
	}
	$tableResult
}
