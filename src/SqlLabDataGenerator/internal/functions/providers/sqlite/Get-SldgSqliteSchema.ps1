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

	$conn = $ConnectionInfo.Connection

	# SQLite stores schema in sqlite_master
	$tables = @()
	$cmd = $conn.CreateCommand()
	$cmd.CommandText = "SELECT name FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%' ORDER BY name"
	$reader = $cmd.ExecuteReader()
	while ($reader.Read()) {
		$tables += $reader['name']
	}
	$reader.Close()
	$cmd.Dispose()

	if ($TableFilter) {
		$tables = $tables | Where-Object { $_ -in $TableFilter }
	}

	$tableInfos = foreach ($tableName in $tables) {
		# Get column info via PRAGMA
		$columns = @()
		$cmd = $conn.CreateCommand()
		$cmd.CommandText = "PRAGMA table_info([$tableName])"
		$reader = $cmd.ExecuteReader()
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
		$reader.Close()
		$cmd.Dispose()

		# Get foreign keys via PRAGMA
		$fks = @()
		$cmd = $conn.CreateCommand()
		$cmd.CommandText = "PRAGMA foreign_key_list([$tableName])"
		$reader = $cmd.ExecuteReader()
		while ($reader.Read()) {
			$fks += [PSCustomObject]@{
				id     = $reader['id']
				seq    = $reader['seq']
				table  = $reader['table']
				from   = $reader['from']
				to     = $reader['to']
			}
		}
		$reader.Close()
		$cmd.Dispose()

		# Get unique indexes via PRAGMA
		$uniqueColumns = @{}
		$cmd = $conn.CreateCommand()
		$cmd.CommandText = "PRAGMA index_list([$tableName])"
		$reader = $cmd.ExecuteReader()
		$uniqueIndexes = @()
		while ($reader.Read()) {
			if ($reader['unique'] -eq 1) {
				$uniqueIndexes += [string]$reader['name']
			}
		}
		$reader.Close()
		$cmd.Dispose()

		foreach ($idxName in $uniqueIndexes) {
			$cmd = $conn.CreateCommand()
			$cmd.CommandText = "PRAGMA index_info([$idxName])"
			$reader = $cmd.ExecuteReader()
			while ($reader.Read()) {
				$uniqueColumns[[string]$reader['name']] = $true
			}
			$reader.Close()
			$cmd.Dispose()
		}

		# Check for autoincrement (rowid alias with INTEGER PRIMARY KEY)
		$hasAutoIncrement = @{}
		foreach ($col in $columns) {
			if ($col.pk -gt 0 -and $col.type -match '^INTEGER$') {
				$hasAutoIncrement[$col.name] = $true
			}
		}

		# Build column objects
		$colObjects = foreach ($col in $columns) {
			$fk = $fks | Where-Object { $_.from -eq $col.name } | Select-Object -First 1
			$fkInfo = if ($fk) {
				[PSCustomObject]@{
					PSTypeName       = 'SqlLabDataGenerator.ForeignKeyRef'
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

			[PSCustomObject]@{
				PSTypeName          = 'SqlLabDataGenerator.ColumnInfo'
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
				CheckConstraints    = @()
				SchemaHint          = $null
				ViewDetectedFormat  = $null
			}
		}

		# Build FK list
		$fkList = foreach ($fk in $fks) {
			[PSCustomObject]@{
				PSTypeName       = 'SqlLabDataGenerator.ForeignKeyInfo'
				ForeignKeyName   = "FK_${tableName}_$($fk.from)_$($fk.table)_$($fk.to)"
				ParentSchema     = 'main'
				ParentTable      = $tableName
				ParentColumn     = $fk.from
				ReferencedSchema = 'main'
				ReferencedTable  = $fk.table
				ReferencedColumn = $fk.to
			}
		}

		[PSCustomObject]@{
			PSTypeName  = 'SqlLabDataGenerator.TableInfo'
			SchemaName  = 'main'
			TableName   = $tableName
			FullName    = "main.$tableName"
			Columns     = $colObjects
			ColumnCount = $colObjects.Count
			ForeignKeys = @($fkList)
		}
	}

	$dbName = if ($conn.DataSource) { [System.IO.Path]::GetFileNameWithoutExtension($conn.DataSource) } else { 'SQLite' }
	[PSCustomObject]@{
		PSTypeName   = 'SqlLabDataGenerator.SchemaModel'
		Database     = $dbName
		Tables       = @($tableInfos)
		TableCount   = @($tableInfos).Count
		DiscoveredAt = Get-Date
	}
}
