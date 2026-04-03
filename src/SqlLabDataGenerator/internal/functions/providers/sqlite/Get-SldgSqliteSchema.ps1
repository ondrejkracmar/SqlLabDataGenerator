function Get-SldgSqliteSchema {
	<#
	.SYNOPSIS
		Reads the schema from a SQLite database.
	#>
	[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSReviewUnusedParameter', 'SchemaFilter', Justification = 'Provider interface parameter')]
	[CmdletBinding()]
	param (
		[Parameter(Mandatory)]
		$ConnectionInfo,

		[string[]]$TableFilter,

		[string[]]$SchemaFilter
	)

	$conn = $ConnectionInfo.DbConnection

	# SQLite stores schema in sqlite_master
	$tables = @()
	$cmd = $conn.CreateCommand()
	try {
		$cmd.CommandText = "SELECT name FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%' ORDER BY name"
		$reader = $cmd.ExecuteReader()
		try {
			while ($reader.Read()) {
				$tables += $reader['name']
			}
		}
		finally {
			$reader.Close()
			$reader.Dispose()
		}
	}
	finally {
		$cmd.Dispose()
	}

	if ($TableFilter) {
		$tables = $tables | Where-Object { $_ -in $TableFilter }
	}

	$tableInfos = foreach ($tableName in $tables) {
		$safeTableName = $tableName -replace '"', '""'

		# Get column info via PRAGMA
		$columns = @()
		$cmd = $conn.CreateCommand()
		try {
			$cmd.CommandText = "PRAGMA table_info(`"$safeTableName`")"
			$reader = $cmd.ExecuteReader()
			try {
				while ($reader.Read()) {
					$columns += [PSCustomObject]@{
						cid       = $reader['cid']
						name      = $reader['name']
						type      = $reader['type']
						notnull   = $reader['notnull']
						dflt      = $reader['dflt_value']
						pk        = $reader['pk']
					}
				}
			}
			finally {
				$reader.Close()
				$reader.Dispose()
			}
		}
		finally {
			$cmd.Dispose()
		}

		# Get foreign keys via PRAGMA
		$fks = @()
		$cmd = $conn.CreateCommand()
		try {
			$cmd.CommandText = "PRAGMA foreign_key_list(`"$safeTableName`")"
			$reader = $cmd.ExecuteReader()
			try {
				while ($reader.Read()) {
					$fks += [PSCustomObject]@{
						id     = $reader['id']
						seq    = $reader['seq']
						table  = $reader['table']
						from   = $reader['from']
						to     = $reader['to']
					}
				}
			}
			finally {
				$reader.Close()
				$reader.Dispose()
			}
		}
		finally {
			$cmd.Dispose()
		}

		# Get unique indexes via PRAGMA
		$uniqueColumns = @{}
		$cmd = $conn.CreateCommand()
		try {
			$cmd.CommandText = "PRAGMA index_list(`"$safeTableName`")"
			$reader = $cmd.ExecuteReader()
			$uniqueIndexes = @()
			try {
				while ($reader.Read()) {
					if ($reader['unique'] -eq 1) {
						$uniqueIndexes += [string]$reader['name']
					}
				}
			}
			finally {
				$reader.Close()
				$reader.Dispose()
			}
		}
		finally {
			$cmd.Dispose()
		}

		foreach ($idxName in $uniqueIndexes) {
			$safeIdxName = $idxName -replace '"', '""'
			$cmd = $conn.CreateCommand()
			try {
				$cmd.CommandText = "PRAGMA index_info(`"$safeIdxName`")"
				$reader = $cmd.ExecuteReader()
				try {
					while ($reader.Read()) {
						$uniqueColumns[[string]$reader['name']] = $true
					}
				}
				finally {
					$reader.Close()
					$reader.Dispose()
				}
			}
			finally {
				$cmd.Dispose()
			}
		}

		# Check for autoincrement (rowid alias with INTEGER PRIMARY KEY)
		$hasAutoIncrement = @{}
		foreach ($col in $columns) {
			if ($col.pk -gt 0 -and $col.type -match '^INTEGER$') {
				$hasAutoIncrement[$col.name] = $true
			}
		}

		# Extract CHECK constraints from CREATE TABLE SQL
		$checkConstraintMap = @{}
		$createCmd = $conn.CreateCommand()
		try {
			$createCmd.CommandText = "SELECT sql FROM sqlite_master WHERE type='table' AND name=`"$safeTableName`""
			$createSql = $createCmd.ExecuteScalar()
			if ($createSql) {
				# Match inline column CHECK constraints: CHECK(expression)
				# Use regex with timeout to prevent ReDoS on pathological CREATE TABLE statements
				$regexTimeout = [timespan]::FromSeconds(2)
				try {
					# Match per-column CHECK: "colname" TYPE ... CHECK(expr)
					# Also match table-level CHECK constraints and try to associate them by column name reference
					$checkRegex = [regex]::new('CHECK\s*\(([^)]+)\)', 'IgnoreCase', $regexTimeout)
					$checkMatches = $checkRegex.Matches($createSql)
					foreach ($m in $checkMatches) {
						$checkExpr = $m.Groups[1].Value.Trim()
						# Try to associate the check with a specific column by finding which column name appears in it
						foreach ($col in $columns) {
							$escapedName = [regex]::Escape($col.name)
							if ([regex]::IsMatch($checkExpr, "(?i)\b$escapedName\b", 'None', $regexTimeout)) {
								if (-not $checkConstraintMap.ContainsKey($col.name)) { $checkConstraintMap[$col.name] = [System.Collections.Generic.List[string]]::new() }
								$checkConstraintMap[$col.name].Add($checkExpr)
						}
						}
					}
				}
				catch [System.Text.RegularExpressions.RegexMatchTimeoutException] {
					Write-PSFMessage -Level Warning -Message ($script:strings.'Schema.SQLite.CheckParseTimeout' -f $tableName)
				}
			}
		}
		finally {
			$createCmd.Dispose()
		}

		# Build column objects
		$colObjects = foreach ($col in $columns) {
			$fk = $fks | Where-Object { $_.from -eq $col.name } | Select-Object -First 1
			$fkInfo = if ($fk) {
				[SqlLabDataGenerator.ForeignKeyRef]@{
					ForeignKeyName   = "FK_${tableName}_$($fk.from)_$($fk.table)_$($fk.to)"
					ReferencedSchema = 'main'
					ReferencedTable  = $fk.table
					ReferencedColumn = $fk.to
				}
			} else { $null }

			# Map SQLite types to standard types
			$dataType = switch -Regex ($col.type.ToUpper()) {
				'INT'       { 'integer' }
				'TEXT|CHAR|CLOB|VARCHAR' { 'nvarchar' }
				'BLOB'      { 'varbinary' }
				'REAL|FLOA|DOUB' { 'float' }
				'NUMERIC|DECIMAL' { 'decimal' }
				'BOOL'      { 'bit' }
				'DATE'      { 'datetime' }
				'TIME'      { 'time' }
				default     { 'nvarchar' }
			}

			# Extract max length from type like VARCHAR(255)
			$maxLength = $null
			if ($col.type -match '\((\d+)\)') {
				$maxLength = [int]$Matches[1]
			}

			[SqlLabDataGenerator.ColumnInfo]@{
				ColumnName          = $col.name
				DataType            = $dataType
				MaxLength           = $maxLength
				Precision           = $null
				Scale               = $null
				IsNullable          = $col.notnull -eq 0
				IsPrimaryKey        = $col.pk -gt 0
				IsIdentity          = $hasAutoIncrement.ContainsKey($col.name)
				IsComputed          = $false
				IsUnique            = $col.pk -gt 0 -or $uniqueColumns.ContainsKey($col.name)
				DefaultValue        = $col.dflt
				ForeignKey          = $fkInfo
				SemanticType        = $null
				Classification      = $null
				GenerationRule      = $null
				CheckConstraints    = if ($checkConstraintMap.ContainsKey($col.name)) { @($checkConstraintMap[$col.name]) } else { @() }
				SchemaHint          = $null
				ViewDetectedFormat  = $null
			}
		}

		# Build FK list
		$fkList = foreach ($fk in $fks) {
			[SqlLabDataGenerator.ForeignKeyInfo]@{
				ForeignKeyName   = "FK_${tableName}_$($fk.from)_$($fk.table)_$($fk.to)"
				ParentSchema     = 'main'
				ParentTable      = $tableName
				ParentColumn     = $fk.from
				ReferencedSchema = 'main'
				ReferencedTable  = $fk.table
				ReferencedColumn = $fk.to
			}
		}

		[SqlLabDataGenerator.TableInfo]@{
			SchemaName  = 'main'
			TableName   = $tableName
			FullName    = "main.$tableName"
			Columns     = $colObjects
			ColumnCount = $colObjects.Count
			ForeignKeys = @($fkList)
		}
	}

	$dbName = if ($conn.DataSource) { [System.IO.Path]::GetFileNameWithoutExtension($conn.DataSource) } else { 'SQLite' }
	[SqlLabDataGenerator.SchemaModel]@{
		Database     = $dbName
		Tables       = @($tableInfos)
		TableCount   = @($tableInfos).Count
		DiscoveredAt = Get-Date
	}
}
