Describe "Circular FK Constraint Functions" {
	BeforeAll {
		Remove-Module SqlLabDataGenerator -ErrorAction Ignore
		Import-Module "$PSScriptRoot\..\..\..\..\SqlLabDataGenerator\SqlLabDataGenerator.psd1" -Force
		$module = Get-Module SqlLabDataGenerator

		# Check if SQLite assembly is available
		$script:sqliteAvailable = $false
		try {
			$null = [Microsoft.Data.Sqlite.SqliteConnection]::new("Data Source=:memory:")
			$script:sqliteAvailable = $true
		}
		catch { }

		if ($script:sqliteAvailable) {
			$dbPath = Join-Path $TestDrive 'circular_fk_test.db'
			$conn = [Microsoft.Data.Sqlite.SqliteConnection]::new("Data Source=$dbPath")
			$conn.Open()

			$script:connectionInfo = [SqlLabDataGenerator.Connection]@{
				DbConnection   = $conn
				ServerInstance = 'localhost'
				Database       = $dbPath
				Provider       = 'SQLite'
				ConnectedAt    = Get-Date
			}

			$cmd = $conn.CreateCommand()
			$cmd.CommandText = "PRAGMA foreign_keys = ON; CREATE TABLE A (Id INTEGER PRIMARY KEY, BId INTEGER); CREATE TABLE B (Id INTEGER PRIMARY KEY, AId INTEGER);"
			[void]$cmd.ExecuteNonQuery()
			$cmd.Dispose()
		}

		$script:circularTables = @(
			[PSCustomObject]@{
				SchemaName = ''
				TableName  = 'A'
				FullName   = 'A'
				ForeignKeys = @(
					[PSCustomObject]@{
						ForeignKeyName   = 'FK_A_B'
						ParentColumn     = 'BId'
						ReferencedSchema = ''
						ReferencedTable  = 'B'
						ReferencedColumn = 'Id'
					}
				)
			}
			[PSCustomObject]@{
				SchemaName = ''
				TableName  = 'B'
				FullName   = 'B'
				ForeignKeys = @(
					[PSCustomObject]@{
						ForeignKeyName   = 'FK_B_A'
						ParentColumn     = 'AId'
						ReferencedSchema = ''
						ReferencedTable  = 'A'
						ReferencedColumn = 'Id'
					}
				)
			}
		)
	}

	AfterAll {
		if ($script:connectionInfo -and $script:connectionInfo.DbConnection) {
			if ($script:connectionInfo.DbConnection.State -eq 'Open') {
				$script:connectionInfo.DbConnection.Close()
			}
			$script:connectionInfo.DbConnection.Dispose()
			try { [Microsoft.Data.Sqlite.SqliteConnection]::ClearAllPools() } catch { }
		}
	}

	Context "Disable-SldgCircularFKConstraint (SQLite)" -Skip:(-not $script:sqliteAvailable) {
		It "Disables FK constraints for SQLite" {
			$result = & $module {
				param($tables, $ci)
				Disable-SldgCircularFKConstraint -CircularTables $tables -ConnectionInfo $ci
			} $script:circularTables $script:connectionInfo

			$result | Should -Not -BeNullOrEmpty
			$result.DisabledTables.Count | Should -Be 2
		}

		It "Returns a result with DisabledTables and DisabledConstraintNames" {
			$result = & $module {
				param($tables, $ci)
				Disable-SldgCircularFKConstraint -CircularTables $tables -ConnectionInfo $ci
			} $script:circularTables $script:connectionInfo

			$result.PSObject.Properties.Name | Should -Contain 'DisabledTables'
			$result.PSObject.Properties.Name | Should -Contain 'DisabledConstraintNames'
		}
	}

	Context "Enable-SldgCircularFKConstraint (SQLite)" -Skip:(-not $script:sqliteAvailable) {
		It "Re-enables FK constraints for SQLite" {
			$disabledInfo = & $module {
				param($tables, $ci)
				Disable-SldgCircularFKConstraint -CircularTables $tables -ConnectionInfo $ci
			} $script:circularTables $script:connectionInfo

			$failures = & $module {
				param($di, $ci)
				Enable-SldgCircularFKConstraint -DisabledInfo $di -ConnectionInfo $ci
			} $disabledInfo $script:connectionInfo

			$failures.Count | Should -Be 0
		}

		It "Returns empty list when nothing was disabled" {
			$emptyInfo = [PSCustomObject]@{
				DisabledTables          = [System.Collections.Generic.List[object]]::new()
				DisabledConstraintNames = [System.Collections.Generic.List[string]]::new()
			}

			$failures = & $module {
				param($di, $ci)
				Enable-SldgCircularFKConstraint -DisabledInfo $di -ConnectionInfo $ci
			} $emptyInfo $script:connectionInfo

			$failures.Count | Should -Be 0
		}
	}

	Context "Round-trip Disable/Enable" -Skip:(-not $script:sqliteAvailable) {
		It "Disable then Enable leaves database in original state" {
			# Check FK pragma is ON before
			$cmd = $script:connectionInfo.DbConnection.CreateCommand()
			$cmd.CommandText = "PRAGMA foreign_keys"
			$before = $cmd.ExecuteScalar()
			$cmd.Dispose()

			$disabledInfo = & $module {
				param($tables, $ci)
				Disable-SldgCircularFKConstraint -CircularTables $tables -ConnectionInfo $ci
			} $script:circularTables $script:connectionInfo

			# FK should be off now
			$cmd = $script:connectionInfo.DbConnection.CreateCommand()
			$cmd.CommandText = "PRAGMA foreign_keys"
			$during = $cmd.ExecuteScalar()
			$cmd.Dispose()
			$during | Should -Be 0

			$null = & $module {
				param($di, $ci)
				Enable-SldgCircularFKConstraint -DisabledInfo $di -ConnectionInfo $ci
			} $disabledInfo $script:connectionInfo

			# FK should be back on
			$cmd = $script:connectionInfo.DbConnection.CreateCommand()
			$cmd.CommandText = "PRAGMA foreign_keys"
			$after = $cmd.ExecuteScalar()
			$cmd.Dispose()
			$after | Should -Be 1
		}
	}
}
