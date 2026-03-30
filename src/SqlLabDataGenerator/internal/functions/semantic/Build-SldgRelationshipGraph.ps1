function Build-SldgRelationshipGraph {
	<#
	.SYNOPSIS
		Builds a textual relationship graph from a schema model for AI prompt injection.
	#>
	[CmdletBinding()]
	param (
		[Parameter(Mandatory)]
		$SchemaModel
	)

	$parentChildMap = @{}
	$childParentMap = @{}
	foreach ($table in $SchemaModel.Tables) {
		foreach ($fk in $table.ForeignKeys) {
			$parentFull = "$($fk.ReferencedSchema).$($fk.ReferencedTable)"
			$childFull = $table.FullName
			if ($parentFull -eq $childFull) { continue }
			if (-not $parentChildMap.ContainsKey($parentFull)) { $parentChildMap[$parentFull] = [System.Collections.Generic.List[string]]::new() }
			$parentChildMap[$parentFull].Add("$childFull.$($fk.ColumnName)")
			if (-not $childParentMap.ContainsKey($childFull)) { $childParentMap[$childFull] = [System.Collections.Generic.List[string]]::new() }
			$childParentMap[$childFull].Add("$parentFull ($($fk.ColumnName) -> $($fk.ReferencedColumn))")
		}
	}

	$relationshipLines = [System.Collections.Generic.List[string]]::new()
	$relationshipLines.Add("RELATIONSHIP GRAPH (parent → child tables):")
	foreach ($table in $SchemaModel.Tables) {
		$children = if ($parentChildMap.ContainsKey($table.FullName)) { $parentChildMap[$table.FullName] } else { $null }
		$parents = if ($childParentMap.ContainsKey($table.FullName)) { $childParentMap[$table.FullName] } else { $null }

		$pkCols = @($table.Columns | Where-Object { $_.IsPrimaryKey })
		$fkCols = @($table.Columns | Where-Object { $null -ne $_.ForeignKey })
		$allPKsAreFK = $pkCols.Count -gt 1 -and $fkCols.Count -ge $pkCols.Count -and ($pkCols | Where-Object { $null -ne $_.ForeignKey }).Count -eq $pkCols.Count
		$nonKeyNonFKCols = @($table.Columns | Where-Object { -not $_.IsPrimaryKey -and -not $_.IsIdentity -and $null -eq $_.ForeignKey -and $_.DataType -notmatch 'timestamp|rowversion' })
		$hasChildren = $children -and $children.Count -gt 0
		$hasParents = $parents -and $parents.Count -gt 0

		$role = 'Entity'
		if ($allPKsAreFK) { $role = 'Junction' }
		elseif (-not $hasParents -and $hasChildren -and $nonKeyNonFKCols.Count -le 3) { $role = 'Lookup' }
		elseif (-not $hasParents -and $hasChildren) { $role = 'Root' }
		elseif ($hasParents -and $hasChildren) { $role = 'Intermediate' }
		elseif ($hasParents -and -not $hasChildren) { $role = 'Leaf' }

		$line = "  $($table.FullName) [$role]"
		if ($parents) { $line += " parents: $($parents -join '; ')" }
		if ($children) { $line += " children: $($children -join '; ')" }
		$relationshipLines.Add($line)
	}

	$relationshipLines -join "`n"
}
