function Group-SldgTablesByLevel {
	<#
	.SYNOPSIS
		Groups topologically-ordered tables into dependency levels for parallel processing.
	.DESCRIPTION
		Assigns each table a dependency level: level 0 has no FK dependencies, level 1
		depends only on level 0 tables, etc. Tables at the same level are independent
		and can be generated in parallel.
	#>
	[CmdletBinding()]
	param (
		[Parameter(Mandatory)]
		[object[]]$Tables
	)

	$levelMap = @{}
	foreach ($table in $Tables) {
		$levelMap[$table.FullName] = 0
	}

	# Iteratively compute levels based on FK dependencies
	# Safety limit prevents infinite loop with circular FK dependencies (A→B→A)
	$maxIterations = $Tables.Count
	$iteration = 0
	$changed = $true
	while ($changed) {
		if ($iteration++ -ge $maxIterations) {
			Write-PSFMessage -Level Warning -Message "Level computation stopped after $maxIterations iterations — possible circular FK dependency. Results may be approximate."
			break
		}
		$changed = $false
		foreach ($table in $Tables) {
			if (-not $table.ForeignKeys) { continue }

			$deps = $table.ForeignKeys |
				Where-Object { "$($_.ReferencedSchema).$($_.ReferencedTable)" -ne $table.FullName } |
				ForEach-Object { "$($_.ReferencedSchema).$($_.ReferencedTable)" } |
				Select-Object -Unique

			foreach ($dep in $deps) {
				if ($levelMap.ContainsKey($dep)) {
					$requiredLevel = $levelMap[$dep] + 1
					if ($requiredLevel -gt $levelMap[$table.FullName]) {
						$levelMap[$table.FullName] = $requiredLevel
						$changed = $true
					}
				}
			}
		}
	}

	# Group by level, preserving original order within each level
	$maxLevel = 0
	foreach ($v in $levelMap.Values) { if ($v -gt $maxLevel) { $maxLevel = $v } }

	$groups = [System.Collections.Generic.List[object]]::new()
	for ($level = 0; $level -le $maxLevel; $level++) {
		$levelTables = @($Tables | Where-Object { $levelMap[$_.FullName] -eq $level })
		if ($levelTables.Count -gt 0) {
			$groups.Add([PSCustomObject]@{
				Level  = $level
				Tables = $levelTables
			})
		}
	}

	Write-PSFMessage -Level Verbose -Message "Table dependency levels: $($groups.Count) levels, max parallelism at level 0: $($groups[0].Tables.Count) tables"
	$groups.ToArray()
}
