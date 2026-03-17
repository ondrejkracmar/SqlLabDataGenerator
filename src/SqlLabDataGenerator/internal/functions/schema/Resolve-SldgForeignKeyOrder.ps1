function Resolve-SldgForeignKeyOrder {
	<#
	.SYNOPSIS
		Determines the correct table insertion order based on foreign key dependencies.
	.DESCRIPTION
		Uses Kahn's topological sort algorithm. Tables with no dependencies come first.
		Self-referencing FKs are ignored. Circular dependencies are detected and appended at the end.
	#>
	[CmdletBinding()]
	param (
		[Parameter(Mandatory)]
		[object[]]$Tables
	)

	$tableMap = @{}
	$graph = @{}      # table -> list of dependents (tables that reference this one)
	$inDegree = @{}   # table -> number of tables it depends on

	# Initialize
	foreach ($table in $Tables) {
		$fullName = $table.FullName
		$tableMap[$fullName] = $table
		if (-not $graph.ContainsKey($fullName)) { $graph[$fullName] = [System.Collections.Generic.List[string]]::new() }
		if (-not $inDegree.ContainsKey($fullName)) { $inDegree[$fullName] = 0 }
	}

	# Build dependency graph
	foreach ($table in $Tables) {
		$fullName = $table.FullName
		$uniqueDeps = $table.ForeignKeys |
			Where-Object { "$($_.ReferencedSchema).$($_.ReferencedTable)" -ne $fullName } |
			ForEach-Object { "$($_.ReferencedSchema).$($_.ReferencedTable)" } |
			Select-Object -Unique

		foreach ($dep in $uniqueDeps) {
			if ($tableMap.ContainsKey($dep)) {
				# dep must come before fullName
				$graph[$dep].Add($fullName)
				$inDegree[$fullName]++
			}
		}
	}

	# Kahn's algorithm
	$queue = [System.Collections.Generic.Queue[string]]::new()
	foreach ($name in $inDegree.Keys) {
		if ($inDegree[$name] -eq 0) { $queue.Enqueue($name) }
	}

	$sorted = [System.Collections.Generic.List[object]]::new()
	while ($queue.Count -gt 0) {
		$current = $queue.Dequeue()
		$sorted.Add($tableMap[$current])

		foreach ($dependent in $graph[$current]) {
			$inDegree[$dependent]--
			if ($inDegree[$dependent] -eq 0) { $queue.Enqueue($dependent) }
		}
	}

	# Handle circular dependencies — flag tables so consumers can disable FK constraints
	if ($sorted.Count -lt $Tables.Count) {
		$remaining = $Tables | Where-Object { $_.FullName -notin @($sorted | ForEach-Object { $_.FullName }) }
		Write-PSFMessage -Level Warning -Message ($script:strings.'Generation.CyclicDependency' -f ($remaining.FullName -join ', '))
		foreach ($table in $remaining) {
			$table | Add-Member -NotePropertyName 'HasCircularDependency' -NotePropertyValue $true -Force
			$sorted.Add($table)
		}
	}

	Write-PSFMessage -Level Verbose -Message ($script:strings.'Generation.TableOrder' -f ($sorted.FullName -join ' -> '))
	$sorted.ToArray()
}
