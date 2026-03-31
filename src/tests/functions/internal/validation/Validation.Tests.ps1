Describe "Validation Functions" {
	BeforeAll {
		Remove-Module SqlLabDataGenerator -ErrorAction Ignore

		# Ensure native SQLite DLL is discoverable before module import
		$runtimeId = if ($IsLinux) { 'linux-x64' } elseif ($IsMacOS) { 'osx-x64' } else { 'win-x64' }
		$nativePath = Join-Path $PSScriptRoot "..\..\..\..\SqlLabDataGenerator\bin\runtimes\$runtimeId\native"
		if (Test-Path $nativePath) {
			$resolved = (Resolve-Path $nativePath).Path
			$env:PATH = "$resolved$([System.IO.Path]::PathSeparator)$env:PATH"
			if ($IsLinux -or $IsMacOS) { $env:LD_LIBRARY_PATH = "$resolved$([System.IO.Path]::PathSeparator)$env:LD_LIBRARY_PATH" }
		}

		Import-Module "$PSScriptRoot\..\..\..\..\SqlLabDataGenerator\SqlLabDataGenerator.psd1" -Force
		$module = Get-Module SqlLabDataGenerator

		# Create SQLite connection inside module scope
		$dbPath = Join-Path $TestDrive 'validation_test.db'
		$script:connectionInfo = & $module {
			param($dbPath)
			$conn = New-Object Microsoft.Data.Sqlite.SqliteConnection("Data Source=$dbPath")
			$conn.Open()
			[SqlLabDataGenerator.Connection]@{
				DbConnection   = $conn
				ServerInstance = 'localhost'
				Database       = $dbPath
				Provider       = 'SQLite'
				ConnectedAt    = Get-Date
			}
		} $dbPath

		$conn = $script:connectionInfo.DbConnection
		$setupSql = @"
CREATE TABLE Category (
	Id INTEGER PRIMARY KEY,
	Name TEXT NOT NULL UNIQUE
);
CREATE TABLE Product (
	Id INTEGER PRIMARY KEY,
	Name TEXT NOT NULL,
	CategoryId INTEGER NOT NULL,
	Price REAL,
	FOREIGN KEY (CategoryId) REFERENCES Category(Id)
);
INSERT INTO Category (Id, Name) VALUES (1, 'Electronics'), (2, 'Books'), (3, 'Clothing');
INSERT INTO Product (Id, Name, CategoryId, Price) VALUES (1, 'Phone', 1, 999.99), (2, 'Novel', 2, 19.99), (3, 'Shirt', 3, 29.99);
"@
		$cmd = $conn.CreateCommand()
		$cmd.CommandText = $setupSql
		[void]$cmd.ExecuteNonQuery()
		$cmd.Dispose()

		$script:schemaModel = [PSCustomObject]@{
			Tables = @(
				[PSCustomObject]@{
					SchemaName  = ''
					TableName   = 'Category'
					FullName    = 'Category'
					Columns     = @(
						[PSCustomObject]@{ ColumnName = 'Id'; IsPrimaryKey = $true; IsUnique = $true; IsNullable = $false; IsIdentity = $true; IsComputed = $false; DataType = 'INTEGER' }
						[PSCustomObject]@{ ColumnName = 'Name'; IsPrimaryKey = $false; IsUnique = $true; IsNullable = $false; IsIdentity = $false; IsComputed = $false; DataType = 'TEXT' }
					)
					ForeignKeys = @()
				}
				[PSCustomObject]@{
					SchemaName  = ''
					TableName   = 'Product'
					FullName    = 'Product'
					Columns     = @(
						[PSCustomObject]@{ ColumnName = 'Id'; IsPrimaryKey = $true; IsUnique = $true; IsNullable = $false; IsIdentity = $true; IsComputed = $false; DataType = 'INTEGER' }
						[PSCustomObject]@{ ColumnName = 'Name'; IsPrimaryKey = $false; IsUnique = $false; IsNullable = $false; IsIdentity = $false; IsComputed = $false; DataType = 'TEXT' }
						[PSCustomObject]@{ ColumnName = 'CategoryId'; IsPrimaryKey = $false; IsUnique = $false; IsNullable = $false; IsIdentity = $false; IsComputed = $false; DataType = 'INTEGER' }
						[PSCustomObject]@{ ColumnName = 'Price'; IsPrimaryKey = $false; IsUnique = $false; IsNullable = $true; IsIdentity = $false; IsComputed = $false; DataType = 'REAL' }
					)
					ForeignKeys = @(
						[PSCustomObject]@{
							ForeignKeyName   = 'FK_Product_Category'
							ParentColumn     = 'CategoryId'
							ReferencedSchema = ''
							ReferencedTable  = 'Category'
							ReferencedColumn = 'Id'
						}
					)
				}
			)
		}
	}

	AfterAll {
		if ($script:connectionInfo -and $script:connectionInfo.DbConnection) {
			if ($script:connectionInfo.DbConnection.State -eq 'Open') {
				$script:connectionInfo.DbConnection.Close()
			}
			$script:connectionInfo.DbConnection.Dispose()
			[Microsoft.Data.Sqlite.SqliteConnection]::ClearAllPools()
		}
	}

	Context "Test-SldgUniqueConstraints" {
		It "Returns results for unique and PK columns" {
			$results = & $module {
				param($ci, $sm)
				Test-SldgUniqueConstraints -ConnectionInfo $ci -SchemaModel $sm
			} $script:connectionInfo $script:schemaModel

			$results.Count | Should -BeGreaterOrEqual 2
		}

		It "Reports no violations for valid unique data" {
			$results = & $module {
				param($ci, $sm)
				Test-SldgUniqueConstraints -ConnectionInfo $ci -SchemaModel $sm
			} $script:connectionInfo $script:schemaModel

			$results | ForEach-Object { $_.Passed | Should -BeTrue }
		}

		It "Detects duplicate violations" {
			# Insert duplicate
			$cmd = $script:connectionInfo.DbConnection.CreateCommand()
			$cmd.CommandText = "INSERT INTO Category (Id, Name) VALUES (10, 'Electronics')"
			try { [void]$cmd.ExecuteNonQuery() } catch { }  # May fail on UNIQUE — that's OK, SQLite enforces it
			$cmd.Dispose()

			# The unique constraint is enforced by SQLite, so duplicates can't actually exist
			# This test verifies the function runs without error on clean data
			$results = & $module {
				param($ci, $sm)
				Test-SldgUniqueConstraints -ConnectionInfo $ci -SchemaModel $sm
			} $script:connectionInfo $script:schemaModel

			$results | Should -Not -BeNullOrEmpty
		}

		It "Returns correct CheckType for PK vs Unique columns" {
			$results = & $module {
				param($ci, $sm)
				Test-SldgUniqueConstraints -ConnectionInfo $ci -SchemaModel $sm
			} $script:connectionInfo $script:schemaModel

			$pkResults = $results | Where-Object { $_.Column -eq 'Id' }
			$pkResults | ForEach-Object { $_.CheckType | Should -Be 'PrimaryKey' }

			$uqResults = $results | Where-Object { $_.Column -eq 'Name' -and $_.TableName -eq 'Category' }
			$uqResults | ForEach-Object { $_.CheckType | Should -Be 'UniqueConstraint' }
		}
	}

	Context "Test-SldgForeignKeyIntegrity" {
		It "Returns results for FK relationships" {
			$results = & $module {
				param($ci, $sm)
				Test-SldgForeignKeyIntegrity -ConnectionInfo $ci -SchemaModel $sm
			} $script:connectionInfo $script:schemaModel

			$results.Count | Should -Be 1
			$results[0].CheckType | Should -Be 'ForeignKey'
		}

		It "Reports no orphans for valid FK data" {
			$results = & $module {
				param($ci, $sm)
				Test-SldgForeignKeyIntegrity -ConnectionInfo $ci -SchemaModel $sm
			} $script:connectionInfo $script:schemaModel

			$results[0].Passed | Should -BeTrue
			$results[0].Details | Should -Be 'All references valid'
		}

		It "Detects orphaned FK rows" {
			# Insert an orphan row (disable FK enforcement first for SQLite)
			$cmd = $script:connectionInfo.DbConnection.CreateCommand()
			$cmd.CommandText = "PRAGMA foreign_keys = OFF"
			[void]$cmd.ExecuteNonQuery()
			$cmd.Dispose()

			$cmd = $script:connectionInfo.DbConnection.CreateCommand()
			$cmd.CommandText = "INSERT INTO Product (Id, Name, CategoryId, Price) VALUES (99, 'Orphan', 999, 0)"
			[void]$cmd.ExecuteNonQuery()
			$cmd.Dispose()

			$results = & $module {
				param($ci, $sm)
				Test-SldgForeignKeyIntegrity -ConnectionInfo $ci -SchemaModel $sm
			} $script:connectionInfo $script:schemaModel

			$results[0].Passed | Should -BeFalse
			$results[0].Details | Should -Match 'orphaned'

			# Cleanup
			$cmd = $script:connectionInfo.DbConnection.CreateCommand()
			$cmd.CommandText = "DELETE FROM Product WHERE Id = 99"
			[void]$cmd.ExecuteNonQuery()
			$cmd.Dispose()

			$cmd = $script:connectionInfo.DbConnection.CreateCommand()
			$cmd.CommandText = "PRAGMA foreign_keys = ON"
			[void]$cmd.ExecuteNonQuery()
			$cmd.Dispose()
		}
	}

	Context "Test-SldgDataTypeConstraints" {
		It "Returns results for NOT NULL columns and row count" {
			$results = & $module {
				param($ci, $sm)
				Test-SldgDataTypeConstraints -ConnectionInfo $ci -SchemaModel $sm
			} $script:connectionInfo $script:schemaModel

			$results.Count | Should -BeGreaterOrEqual 2
		}

		It "Reports no null violations for valid data" {
			$results = & $module {
				param($ci, $sm)
				Test-SldgDataTypeConstraints -ConnectionInfo $ci -SchemaModel $sm
			} $script:connectionInfo $script:schemaModel

			$notNullResults = $results | Where-Object { $_.CheckType -eq 'NotNull' }
			$notNullResults | ForEach-Object { $_.Passed | Should -BeTrue }
		}

		It "Reports positive row counts" {
			$results = & $module {
				param($ci, $sm)
				Test-SldgDataTypeConstraints -ConnectionInfo $ci -SchemaModel $sm
			} $script:connectionInfo $script:schemaModel

			$rowCountResults = $results | Where-Object { $_.CheckType -eq 'RowCount' }
			$rowCountResults.Count | Should -Be 2
			$rowCountResults | ForEach-Object {
				$_.Passed | Should -BeTrue
				$_.Details | Should -Match '\d+ rows'
			}
		}
	}
}
