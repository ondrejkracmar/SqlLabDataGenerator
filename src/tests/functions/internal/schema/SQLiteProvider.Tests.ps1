Describe "Get-SldgSqliteSchema (SQLite Provider)" {
	BeforeAll {
		Remove-Module SqlLabDataGenerator -ErrorAction Ignore
		Import-Module "$PSScriptRoot\..\..\..\..\SqlLabDataGenerator\SqlLabDataGenerator.psd1" -Force
		$module = Get-Module SqlLabDataGenerator

		# Check if SQLite assembly is available
		$script:sqliteAvailable = $false
		try {
			$null = [System.Reflection.Assembly]::LoadWithPartialName('Microsoft.Data.Sqlite')
			$script:sqliteAvailable = $true
			$script:sqliteType = 'Microsoft.Data.Sqlite'
		}
		catch {
			try {
				$null = [System.Reflection.Assembly]::LoadWithPartialName('System.Data.SQLite')
				$script:sqliteAvailable = $true
				$script:sqliteType = 'System.Data.SQLite'
			}
			catch { }
		}

		function New-TestSqliteConnection {
			param ([string]$DbPath)
			if ($script:sqliteType -eq 'Microsoft.Data.Sqlite') {
				$conn = [Microsoft.Data.Sqlite.SqliteConnection]::new("Data Source=$DbPath")
			}
			else {
				$conn = [System.Data.SQLite.SQLiteConnection]::new("Data Source=$DbPath")
			}
			$conn.Open()
			$conn
		}

		function Invoke-SqliteNonQuery {
			param ($Connection, [string]$Sql)
			$cmd = $Connection.CreateCommand()
			$cmd.CommandText = $Sql
			$null = $cmd.ExecuteNonQuery()
			$cmd.Dispose()
		}
	}

	Context "SchemaModel Wrapper" -Skip:(-not $script:sqliteAvailable) {
		BeforeAll {
			$dbPath = Join-Path $TestDrive 'test_schema_model.db'
			$conn = New-TestSqliteConnection -DbPath $dbPath
			Invoke-SqliteNonQuery -Connection $conn -Sql "CREATE TABLE Simple (Id INTEGER PRIMARY KEY, Name TEXT NOT NULL)"

			$connInfo = [PSCustomObject]@{ Connection = $conn; Provider = 'SQLite' }
			$script:result = & $module { Get-SldgSqliteSchema -ConnectionInfo $args[0] } $connInfo
		}

		AfterAll {
			if ($conn) { $conn.Close(); $conn.Dispose() }
		}

		It "Returns a SchemaModel object" {
			$result.PSTypeNames | Should -Contain 'SqlLabDataGenerator.SchemaModel'
		}

		It "Has Database property" {
			$result.Database | Should -Not -BeNullOrEmpty
		}

		It "Has TableCount property" {
			$result.TableCount | Should -Be 1
		}

		It "Has Tables array" {
			$result.Tables | Should -HaveCount 1
		}

		It "Has DiscoveredAt timestamp" {
			$result.DiscoveredAt | Should -BeOfType [datetime]
		}
	}

	Context "UNIQUE Constraint Detection" -Skip:(-not $script:sqliteAvailable) {
		BeforeAll {
			$dbPath = Join-Path $TestDrive 'test_unique.db'
			$conn = New-TestSqliteConnection -DbPath $dbPath
			Invoke-SqliteNonQuery -Connection $conn -Sql @"
CREATE TABLE Users (
    Id INTEGER PRIMARY KEY AUTOINCREMENT,
    Username TEXT NOT NULL UNIQUE,
    Email TEXT NOT NULL,
    Code TEXT
);
CREATE UNIQUE INDEX idx_users_email ON Users(Email);
"@

			$connInfo = [PSCustomObject]@{ Connection = $conn; Provider = 'SQLite' }
			$script:schema = & $module { Get-SldgSqliteSchema -ConnectionInfo $args[0] } $connInfo
			$script:table = $schema.Tables | Where-Object TableName -eq 'Users'
		}

		AfterAll {
			if ($conn) { $conn.Close(); $conn.Dispose() }
		}

		It "Detects PK column as unique" {
			($table.Columns | Where-Object ColumnName -eq 'Id').IsUnique | Should -BeTrue
		}

		It "Detects UNIQUE constraint column" {
			($table.Columns | Where-Object ColumnName -eq 'Username').IsUnique | Should -BeTrue
		}

		It "Detects UNIQUE index column" {
			($table.Columns | Where-Object ColumnName -eq 'Email').IsUnique | Should -BeTrue
		}

		It "Does not mark non-unique column" {
			($table.Columns | Where-Object ColumnName -eq 'Code').IsUnique | Should -BeFalse
		}
	}

	Context "Foreign Key Normalization" -Skip:(-not $script:sqliteAvailable) {
		BeforeAll {
			$dbPath = Join-Path $TestDrive 'test_fk.db'
			$conn = New-TestSqliteConnection -DbPath $dbPath
			Invoke-SqliteNonQuery -Connection $conn -Sql @"
CREATE TABLE Department (Id INTEGER PRIMARY KEY, Name TEXT NOT NULL);
CREATE TABLE Employee (
    Id INTEGER PRIMARY KEY,
    Name TEXT NOT NULL,
    DeptId INTEGER NOT NULL,
    FOREIGN KEY (DeptId) REFERENCES Department(Id)
);
"@

			$connInfo = [PSCustomObject]@{ Connection = $conn; Provider = 'SQLite' }
			$script:schema = & $module { Get-SldgSqliteSchema -ConnectionInfo $args[0] } $connInfo
			$script:empTable = $schema.Tables | Where-Object TableName -eq 'Employee'
		}

		AfterAll {
			if ($conn) { $conn.Close(); $conn.Dispose() }
		}

		It "FK list includes ForeignKeyName" {
			$empTable.ForeignKeys[0].ForeignKeyName | Should -Not -BeNullOrEmpty
		}

		It "FK list includes ParentSchema" {
			$empTable.ForeignKeys[0].ParentSchema | Should -Be 'main'
		}

		It "FK list includes ParentTable" {
			$empTable.ForeignKeys[0].ParentTable | Should -Be 'Employee'
		}

		It "FK list includes ParentColumn" {
			$empTable.ForeignKeys[0].ParentColumn | Should -Be 'DeptId'
		}

		It "FK list includes ReferencedTable" {
			$empTable.ForeignKeys[0].ReferencedTable | Should -Be 'Department'
		}

		It "FK list includes ReferencedColumn" {
			$empTable.ForeignKeys[0].ReferencedColumn | Should -Be 'Id'
		}

		It "Column ForeignKey ref has ForeignKeyName" {
			$deptCol = $empTable.Columns | Where-Object ColumnName -eq 'DeptId'
			$deptCol.ForeignKey.ForeignKeyName | Should -Not -BeNullOrEmpty
		}

		It "Column ForeignKey ref has PSTypeName" {
			$deptCol = $empTable.Columns | Where-Object ColumnName -eq 'DeptId'
			$deptCol.ForeignKey.PSTypeNames | Should -Contain 'SqlLabDataGenerator.ForeignKeyRef'
		}
	}

	Context "Table Filtering" -Skip:(-not $script:sqliteAvailable) {
		BeforeAll {
			$dbPath = Join-Path $TestDrive 'test_filter.db'
			$conn = New-TestSqliteConnection -DbPath $dbPath
			Invoke-SqliteNonQuery -Connection $conn -Sql "CREATE TABLE Alpha (Id INTEGER PRIMARY KEY)"
			Invoke-SqliteNonQuery -Connection $conn -Sql "CREATE TABLE Beta (Id INTEGER PRIMARY KEY)"
			Invoke-SqliteNonQuery -Connection $conn -Sql "CREATE TABLE Gamma (Id INTEGER PRIMARY KEY)"

			$connInfo = [PSCustomObject]@{ Connection = $conn; Provider = 'SQLite' }
			$script:filtered = & $module { Get-SldgSqliteSchema -ConnectionInfo $args[0] -TableFilter @('Alpha', 'Gamma') } $connInfo
		}

		AfterAll {
			if ($conn) { $conn.Close(); $conn.Dispose() }
		}

		It "Returns only filtered tables" {
			$filtered.TableCount | Should -Be 2
		}

		It "Contains requested tables" {
			$filtered.Tables.TableName | Should -Contain 'Alpha'
			$filtered.Tables.TableName | Should -Contain 'Gamma'
		}

		It "Excludes non-filtered tables" {
			$filtered.Tables.TableName | Should -Not -Contain 'Beta'
		}
	}

	Context "Data Type Mapping" -Skip:(-not $script:sqliteAvailable) {
		BeforeAll {
			$dbPath = Join-Path $TestDrive 'test_types.db'
			$conn = New-TestSqliteConnection -DbPath $dbPath
			Invoke-SqliteNonQuery -Connection $conn -Sql @"
CREATE TABLE TypeTest (
    IntCol INTEGER,
    TextCol TEXT,
    VarcharCol VARCHAR(100),
    RealCol REAL,
    BlobCol BLOB,
    BoolCol BOOLEAN,
    DateCol DATE,
    DecCol DECIMAL(10,2)
);
"@

			$connInfo = [PSCustomObject]@{ Connection = $conn; Provider = 'SQLite' }
			$script:schema = & $module { Get-SldgSqliteSchema -ConnectionInfo $args[0] } $connInfo
			$script:cols = $schema.Tables[0].Columns
		}

		AfterAll {
			if ($conn) { $conn.Close(); $conn.Dispose() }
		}

		It "Maps INTEGER to integer" {
			($cols | Where-Object ColumnName -eq 'IntCol').DataType | Should -Be 'integer'
		}

		It "Maps TEXT to nvarchar" {
			($cols | Where-Object ColumnName -eq 'TextCol').DataType | Should -Be 'nvarchar'
		}

		It "Maps VARCHAR(100) to nvarchar with MaxLength" {
			$col = $cols | Where-Object ColumnName -eq 'VarcharCol'
			$col.DataType | Should -Be 'nvarchar'
			$col.MaxLength | Should -Be 100
		}

		It "Maps REAL to float" {
			($cols | Where-Object ColumnName -eq 'RealCol').DataType | Should -Be 'float'
		}

		It "Maps BLOB to varbinary" {
			($cols | Where-Object ColumnName -eq 'BlobCol').DataType | Should -Be 'varbinary'
		}

		It "Maps BOOLEAN to bit" {
			($cols | Where-Object ColumnName -eq 'BoolCol').DataType | Should -Be 'bit'
		}

		It "Maps DATE to datetime" {
			($cols | Where-Object ColumnName -eq 'DateCol').DataType | Should -Be 'datetime'
		}

		It "Maps DECIMAL to decimal" {
			($cols | Where-Object ColumnName -eq 'DecCol').DataType | Should -Be 'decimal'
		}
	}

	Context "Autoincrement Detection" -Skip:(-not $script:sqliteAvailable) {
		BeforeAll {
			$dbPath = Join-Path $TestDrive 'test_autoinc.db'
			$conn = New-TestSqliteConnection -DbPath $dbPath
			Invoke-SqliteNonQuery -Connection $conn -Sql @"
CREATE TABLE AutoTable (
    Id INTEGER PRIMARY KEY AUTOINCREMENT,
    Name TEXT NOT NULL
);
"@

			$connInfo = [PSCustomObject]@{ Connection = $conn; Provider = 'SQLite' }
			$script:schema = & $module { Get-SldgSqliteSchema -ConnectionInfo $args[0] } $connInfo
			$script:cols = $schema.Tables[0].Columns
		}

		AfterAll {
			if ($conn) { $conn.Close(); $conn.Dispose() }
		}

		It "Detects INTEGER PRIMARY KEY as identity" {
			($cols | Where-Object ColumnName -eq 'Id').IsIdentity | Should -BeTrue
		}

		It "Does not mark non-PK column as identity" {
			($cols | Where-Object ColumnName -eq 'Name').IsIdentity | Should -BeFalse
		}
	}
}
