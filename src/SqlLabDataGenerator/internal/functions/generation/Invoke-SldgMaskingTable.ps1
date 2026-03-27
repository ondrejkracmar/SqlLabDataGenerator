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
		$TablePlan,

		[Parameter(Mandatory)]
		$ConnectionInfo,

		[Parameter(Mandatory)]
		$Provider,

		[Parameter(Mandatory)]
		$Plan,

		$Transaction,

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
		Write-PSFMessage -Level Warning -String 'Generation.MaskingNoRows' -StringValues $TablePlan.FullName
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
			if ($null -ne $maskedValue) {
				$row[$col.ColumnName] = $maskedValue
			}
		}
	}

	$insertedCount = $existingData.Rows.Count
	if (-not $NoInsert) {
		# Masking mode: delete existing rows, then re-insert the masked data
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
			$safeName = Get-SldgSafeSqlName -SchemaName $TablePlan.SchemaName -TableName $TablePlan.TableName -SQLite:($ConnectionInfo.Provider -eq 'SQLite')
			$delCmd.CommandText = "DELETE FROM $safeName"
			[void]$delCmd.ExecuteNonQuery()
			$delCmd.Dispose()
		}

		try {
			$writeParams = @{
				ConnectionInfo = $ConnectionInfo
				SchemaName     = $TablePlan.SchemaName
				TableName      = $TablePlan.TableName
				Data           = $existingData
				BatchSize      = $BatchSize
			}
			if ($Transaction) { $writeParams['Transaction'] = $Transaction }
			$insertedCount = & $Provider.FunctionMap.WriteData @writeParams
		}
		finally {
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
