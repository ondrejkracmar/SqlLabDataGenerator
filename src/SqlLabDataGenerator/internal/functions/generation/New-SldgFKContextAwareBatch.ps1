function New-SldgFKContextAwareBatch {
	<#
	.SYNOPSIS
		Generates AI batches grouped by FK parent values for semantic consistency.
	.DESCRIPTION
		Pre-assigns FK values to rows, groups them by the most semantically meaningful
		parent relationship, and calls AI batch generation per group with parent context
		injected into the prompt. This ensures AI-generated values (e.g., city names)
		are semantically consistent with their FK parent (e.g., country).

		Returns $null when FK-context-aware generation is not applicable (no descriptive
		parent columns available, or too many parent groups).
	#>
	[CmdletBinding()]
	param (
		[Parameter(Mandatory)]
		[array]$AIColumns,

		[Parameter(Mandatory)]
		[array]$FKColumns,

		[Parameter(Mandatory)]
		[hashtable]$ForeignKeyValues,

		[Parameter(Mandatory)]
		[string]$TableName,

		[int]$RowCount = 100,

		[string]$Locale,

		[hashtable]$ExistingUniqueValues,

		[string]$TableNotes
	)

	$maxFKContextGroups = Get-PSFConfigValue -FullName 'SqlLabDataGenerator.Generation.MaxFKContextGroups' -Fallback 20

	# Analyze each FK column: find parent values and descriptive context columns
	$fkAnalysis = foreach ($col in $FKColumns) {
		$refKey = "$($col.ForeignKey.ReferencedSchema).$($col.ForeignKey.ReferencedTable).$($col.ForeignKey.ReferencedColumn)"
		$parentValues = $ForeignKeyValues[$refKey]
		if (-not $parentValues -or $parentValues.Count -eq 0) { continue }

		$refPrefix = "$($col.ForeignKey.ReferencedSchema).$($col.ForeignKey.ReferencedTable)."

		# Find descriptive columns from the same parent table stored in ForeignKeyValues
		# These include PK/unique columns AND text columns stored as context by New-SldgRowSet
		$contextColumns = @{}
		foreach ($key in $ForeignKeyValues.Keys) {
			if ($key.StartsWith($refPrefix) -and $key -ne $refKey) {
				$colName = $key.Substring($refPrefix.Length)
				$vals = $ForeignKeyValues[$key]
				# Only use columns that have at least one non-null string-like value
				$hasDescriptive = $false
				foreach ($v in $vals) {
					if ($null -ne $v -and $v -isnot [DBNull] -and "$v".Length -gt 0 -and "$v".Length -le 200) {
						$hasDescriptive = $true
						break
					}
				}
				if ($hasDescriptive) {
					$contextColumns[$colName] = $vals
				}
			}
		}

		[PSCustomObject]@{
			Column         = $col
			RefKey         = $refKey
			ParentValues   = $parentValues
			ContextColumns = $contextColumns
			UniqueCount    = $parentValues.Count
		}
	}

	if (-not $fkAnalysis -or @($fkAnalysis).Count -eq 0) {
		return $null
	}

	# Select primary FK: prefer one with descriptive context columns; among those, fewest unique values
	$primaryFK = @($fkAnalysis | Where-Object { $_.ContextColumns.Count -gt 0 } | Sort-Object UniqueCount | Select-Object -First 1)
	if (-not $primaryFK -or $primaryFK.Count -eq 0) {
		# No parent has descriptive columns — no semantic context to provide
		return $null
	}
	$primaryFK = $primaryFK[0]

	if ($primaryFK.UniqueCount -gt $maxFKContextGroups) {
		Write-PSFMessage -Level Verbose -String 'FKContext.ParentCountExceedsLimit' -StringValues $primaryFK.UniqueCount, $maxFKContextGroups, $TableName
		return $null
	}

	Write-PSFMessage -Level Verbose -String 'FKContext.GroupingRows' -StringValues $TableName, $RowCount, $primaryFK.Column.ColumnName, $primaryFK.UniqueCount

	# Distribute rows proportionally across parent values
	$parentCount = $primaryFK.UniqueCount
	$basePerParent = [Math]::Floor($RowCount / $parentCount)
	$remainder = $RowCount % $parentCount

	$allAIResults = [System.Collections.Generic.List[hashtable]]::new()
	$allFKAssignments = [System.Collections.Generic.List[hashtable]]::new()

	$maxAIBatch = Get-PSFConfigValue -FullName 'SqlLabDataGenerator.Generation.MaxAIBatchSize'
	if (-not $maxAIBatch -or $maxAIBatch -lt 1) { $maxAIBatch = 50 }

	for ($parentIdx = 0; $parentIdx -lt $parentCount; $parentIdx++) {
		$groupSize = $basePerParent + $(if ($parentIdx -lt $remainder) { 1 } else { 0 })
		if ($groupSize -eq 0) { continue }

		$parentPKValue = $primaryFK.ParentValues[$parentIdx]

		# Build human-readable parent context string from parallel column arrays
		$contextParts = @()
		foreach ($ctxColName in $primaryFK.ContextColumns.Keys) {
			$ctxValues = $primaryFK.ContextColumns[$ctxColName]
			if ($parentIdx -lt $ctxValues.Count) {
				$ctxValue = $ctxValues[$parentIdx]
				if ($null -ne $ctxValue -and $ctxValue -isnot [DBNull]) {
					$contextParts += "$ctxColName = '$ctxValue'"
				}
			}
		}

		$parentContext = $null
		if ($contextParts.Count -gt 0) {
			# Limit to first 5 context columns to avoid prompt token explosion
			if ($contextParts.Count -gt 5) {
				$contextParts = $contextParts[0..4]
			}
			$parentTableName = "$($primaryFK.Column.ForeignKey.ReferencedSchema).$($primaryFK.Column.ForeignKey.ReferencedTable)"
			$parentContext = "Parent table [$parentTableName]: $($contextParts -join ', ')"
		}

		# Generate AI batch for this parent group
		$aiParams = @{
			Columns   = $AIColumns
			TableName = $TableName
			BatchSize = [Math]::Min($groupSize, $maxAIBatch)
			Locale    = $Locale
		}
		if ($ExistingUniqueValues) { $aiParams['ExistingUniqueValues'] = $ExistingUniqueValues }
		if ($TableNotes) { $aiParams['TableNotes'] = $TableNotes }
		if ($parentContext) { $aiParams['ParentContext'] = $parentContext }

		$groupBatch = New-SldgAIGeneratedBatch @aiParams

		if ($groupBatch) {
			$usableCount = [Math]::Min($groupBatch.Count, $groupSize)
			for ($i = 0; $i -lt $usableCount; $i++) {
				$allAIResults.Add($groupBatch[$i])
				$allFKAssignments.Add(@{ $primaryFK.Column.ColumnName = $parentPKValue })
			}
		}
	}

	if ($allAIResults.Count -eq 0) {
		return $null
	}

	[PSCustomObject]@{
		AIBatch       = @($allAIResults)
		FKAssignments = @($allFKAssignments)
	}
}
