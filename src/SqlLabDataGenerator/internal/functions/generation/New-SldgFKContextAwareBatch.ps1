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

		[string]$TableNotes,

		[string]$TableContext
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

	# ---- Multi-FK junction table path ----
	# When 2+ FKs have descriptive parent context, provide combined context from both parents
	# and pre-assign ALL FK values so the AI generates non-FK columns coherent with both sides.
	$fksWithContext = @($fkAnalysis | Where-Object { $_.ContextColumns.Count -gt 0 } | Sort-Object UniqueCount)

	if ($fksWithContext.Count -ge 2) {
		$multiFKPrimary = $fksWithContext[0]
		$multiFKSecondary = $fksWithContext[1]

		if ($multiFKPrimary.UniqueCount -le $maxFKContextGroups) {
			Write-PSFMessage -Level Verbose -Message ($script:strings.'FKContext.MultiFKGrouping' -f $TableName, $RowCount, $multiFKPrimary.Column.ColumnName, $multiFKSecondary.Column.ColumnName)

			$mfkParentCount = $multiFKPrimary.UniqueCount
			$mfkBasePerParent = [Math]::Floor($RowCount / $mfkParentCount)
			$mfkRemainder = $RowCount % $mfkParentCount

			$mfkAllAIResults = [System.Collections.Generic.List[hashtable]]::new()
			$mfkAllFKAssignments = [System.Collections.Generic.List[hashtable]]::new()

			$mfkMaxAIBatch = Get-PSFConfigValue -FullName 'SqlLabDataGenerator.Generation.MaxAIBatchSize'
			if (-not $mfkMaxAIBatch -or $mfkMaxAIBatch -lt 1) { $mfkMaxAIBatch = 50 }

			$secondaryGlobalIdx = 0 # round-robin index across secondary FK values
			$maxSecondaryContextLines = 25 # cap per-row context lines to control token usage

			for ($pIdx = 0; $pIdx -lt $mfkParentCount; $pIdx++) {
				$groupSize = $mfkBasePerParent + $(if ($pIdx -lt $mfkRemainder) { 1 } else { 0 })
				if ($groupSize -eq 0) { continue }

				$primaryPKValue = $multiFKPrimary.ParentValues[$pIdx]

				# Build primary parent context string
				$primaryCtxParts = @()
				foreach ($ctxColName in $multiFKPrimary.ContextColumns.Keys) {
					$ctxValues = $multiFKPrimary.ContextColumns[$ctxColName]
					if ($pIdx -lt $ctxValues.Count) {
						$ctxValue = $ctxValues[$pIdx]
						if ($null -ne $ctxValue -and $ctxValue -isnot [DBNull]) {
							$primaryCtxParts += "$ctxColName = '$ctxValue'"
						}
					}
				}
				if ($primaryCtxParts.Count -gt 5) { $primaryCtxParts = $primaryCtxParts[0..4] }

				# Pre-assign secondary FK values (round-robin) and build per-row context
				$groupSecondaryPKs = [System.Collections.Generic.List[object]]::new()
				$secondaryCtxLines = [System.Collections.Generic.List[string]]::new()

				for ($ri = 0; $ri -lt $groupSize; $ri++) {
					$secIdx = $secondaryGlobalIdx % $multiFKSecondary.ParentValues.Count
					$secPKValue = $multiFKSecondary.ParentValues[$secIdx]
					$groupSecondaryPKs.Add($secPKValue)

					# Build secondary parent context for this specific row
					if ($secondaryCtxLines.Count -lt $maxSecondaryContextLines) {
						$secParts = @()
						foreach ($ctxColName in $multiFKSecondary.ContextColumns.Keys) {
							$ctxValues = $multiFKSecondary.ContextColumns[$ctxColName]
							if ($secIdx -lt $ctxValues.Count) {
								$ctxValue = $ctxValues[$secIdx]
								if ($null -ne $ctxValue -and $ctxValue -isnot [DBNull]) {
									$secParts += "$ctxColName = '$ctxValue'"
								}
							}
						}
						if ($secParts.Count -gt 3) { $secParts = $secParts[0..2] }
						if ($secParts.Count -gt 0) {
							$secondaryCtxLines.Add("  Row $($ri + 1): $($secParts -join ', ')")
						}
					}

					$secondaryGlobalIdx++
				}

				# Add overflow indicator if rows exceed context line cap
				if ($groupSize -gt $maxSecondaryContextLines) {
					$overflow = $groupSize - $maxSecondaryContextLines
					$secondaryCtxLines.Add("  ... and $overflow more rows following the same pattern")
				}

				# Build combined multi-FK parent context
				$primaryTableName = "$($multiFKPrimary.Column.ForeignKey.ReferencedSchema).$($multiFKPrimary.Column.ForeignKey.ReferencedTable)"
				$secondaryTableName = "$($multiFKSecondary.Column.ForeignKey.ReferencedSchema).$($multiFKSecondary.Column.ForeignKey.ReferencedTable)"

				$parentContext = ""
				if ($primaryCtxParts.Count -gt 0) {
					$parentContext = "Primary parent [$primaryTableName]: $($primaryCtxParts -join ', ')"
				}
				if ($secondaryCtxLines.Count -gt 0) {
					$parentContext += "`nSecondary parent assignments [$secondaryTableName] (one per row, in order):`n$($secondaryCtxLines -join "`n")"
					$parentContext += "`nGenerate each row so its values are appropriate for BOTH the primary parent and its assigned secondary parent."
				}

				# Generate AI batch for this multi-FK group
				$aiParams = @{
					Columns   = $AIColumns
					TableName = $TableName
					BatchSize = [Math]::Min($groupSize, $mfkMaxAIBatch)
					Locale    = $Locale
				}
				if ($ExistingUniqueValues) { $aiParams['ExistingUniqueValues'] = $ExistingUniqueValues }
				if ($TableNotes) { $aiParams['TableNotes'] = $TableNotes }
				if ($TableContext) { $aiParams['TableContext'] = $TableContext }
				if ($parentContext) { $aiParams['ParentContext'] = $parentContext }

				$groupBatch = New-SldgAIGeneratedBatch @aiParams

				if ($groupBatch) {
					$usableCount = [Math]::Min($groupBatch.Count, $groupSize)
					for ($bi = 0; $bi -lt $usableCount; $bi++) {
						$mfkAllAIResults.Add($groupBatch[$bi])
						$mfkAllFKAssignments.Add(@{
							$multiFKPrimary.Column.ColumnName   = $primaryPKValue
							$multiFKSecondary.Column.ColumnName  = $groupSecondaryPKs[$bi]
						})
					}
				}
			}

			if ($mfkAllAIResults.Count -eq 0) {
				return $null
			}

			return [PSCustomObject]@{
				AIBatch       = @($mfkAllAIResults)
				FKAssignments = @($mfkAllFKAssignments)
			}
		}
	}

	# ---- Single-FK path (original logic) ----
	# Select primary FK: prefer one with descriptive context columns; among those, fewest unique values
	$primaryFK = @($fkAnalysis | Where-Object { $_.ContextColumns.Count -gt 0 } | Sort-Object UniqueCount | Select-Object -First 1)
	if (-not $primaryFK -or $primaryFK.Count -eq 0) {
		# No parent has descriptive columns — no semantic context to provide
		return $null
	}
	$primaryFK = $primaryFK[0]

	if ($primaryFK.UniqueCount -gt $maxFKContextGroups) {
		Write-PSFMessage -Level Verbose -Message ($script:strings.'FKContext.ParentCountExceedsLimit' -f $primaryFK.UniqueCount, $maxFKContextGroups, $TableName)
		return $null
	}

	Write-PSFMessage -Level Verbose -Message ($script:strings.'FKContext.GroupingRows' -f $TableName, $RowCount, $primaryFK.Column.ColumnName, $primaryFK.UniqueCount)

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
		if ($TableContext) { $aiParams['TableContext'] = $TableContext }
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
