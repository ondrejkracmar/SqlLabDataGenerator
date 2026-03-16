Describe "SQLite Integration Tests" {
	BeforeAll {
		Remove-Module SqlLabDataGenerator -ErrorAction Ignore
		Import-Module "$PSScriptRoot\..\..\..\SqlLabDataGenerator\SqlLabDataGenerator.psd1" -Force
		$module = Get-Module SqlLabDataGenerator

		# Check if SQLite assembly is available
		$sqliteAvailable = $false
		try {
			$null = [System.Reflection.Assembly]::LoadWithPartialName('Microsoft.Data.Sqlite')
			$sqliteAvailable = $true
		}
		catch {
			try {
				$null = [System.Reflection.Assembly]::LoadWithPartialName('System.Data.SQLite')
				$sqliteAvailable = $true
			}
			catch { }
		}
	}

	Context "Full Pipeline - Connect, Schema, Plan, Generate, Validate" -Skip:(-not $sqliteAvailable) {
		BeforeAll {
			$dbPath = Join-Path $TestDrive 'test_integration.db'

			# Create a test database with schema
			if ($sqliteAvailable) {
				try {
					$null = [System.Reflection.Assembly]::LoadWithPartialName('Microsoft.Data.Sqlite')
					$conn = [Microsoft.Data.Sqlite.SqliteConnection]::new("Data Source=$dbPath")
				}
				catch {
					$null = [System.Reflection.Assembly]::LoadWithPartialName('System.Data.SQLite')
					$conn = [System.Data.SQLite.SQLiteConnection]::new("Data Source=$dbPath")
				}

				$conn.Open()
				$cmd = $conn.CreateCommand()

				# Create Department table (parent)
				$cmd.CommandText = @"
CREATE TABLE Department (
    Id INTEGER PRIMARY KEY AUTOINCREMENT,
    DepartmentName TEXT NOT NULL,
    Location TEXT
);
"@
				$null = $cmd.ExecuteNonQuery()

				# Create Employee table (child with FK)
				$cmd.CommandText = @"
CREATE TABLE Employee (
    Id INTEGER PRIMARY KEY AUTOINCREMENT,
    FirstName TEXT NOT NULL,
    LastName TEXT NOT NULL,
    Email TEXT,
    DepartmentId INTEGER NOT NULL,
    HireDate TEXT,
    Salary REAL,
    IsActive INTEGER DEFAULT 1,
    FOREIGN KEY (DepartmentId) REFERENCES Department(Id)
);
"@
				$null = $cmd.ExecuteNonQuery()

				$conn.Close()
				$conn.Dispose()
			}
		}

		It "Connects to SQLite database" -Skip:(-not $sqliteAvailable) {
			{ Connect-SldgDatabase -Provider 'SQLite' -Database $dbPath } | Should -Not -Throw
		}

		It "Discovers schema" -Skip:(-not $sqliteAvailable) {
			$script:schema = Get-SldgDatabaseSchema
			$schema | Should -Not -BeNullOrEmpty
			$schema.TableCount | Should -Be 2
		}

		It "Analyzes columns" -Skip:(-not $sqliteAvailable) {
			$script:analyzed = Get-SldgColumnAnalysis -Schema $schema
			$analyzed | Should -Not -BeNullOrEmpty

			# Check that FirstName is classified correctly
			$empTable = $analyzed.Tables | Where-Object { $_.TableName -eq 'Employee' }
			$fnCol = $empTable.Columns | Where-Object { $_.ColumnName -eq 'FirstName' }
			$fnCol.SemanticType | Should -Be 'FirstName'
		}

		It "Creates generation plan with FK order" -Skip:(-not $sqliteAvailable) {
			$script:plan = New-SldgGenerationPlan -Schema $analyzed -RowCount 5
			$plan | Should -Not -BeNullOrEmpty
			$plan.TableCount | Should -Be 2

			# Department should come before Employee (FK dependency)
			$deptOrder = ($plan.Tables | Where-Object { $_.TableName -eq 'Department' }).Order
			$empOrder = ($plan.Tables | Where-Object { $_.TableName -eq 'Employee' }).Order
			$deptOrder | Should -BeLessThan $empOrder
		}

		It "Generates data with NoInsert + PassThru" -Skip:(-not $sqliteAvailable) {
			$script:result = Invoke-SldgDataGeneration -Plan $plan -NoInsert -PassThru
			$result | Should -Not -BeNullOrEmpty
			$result.TotalRows | Should -BeGreaterThan 0
		}

		It "Generates data and inserts to database" -Skip:(-not $sqliteAvailable) {
			$planForInsert = New-SldgGenerationPlan -Schema $analyzed -RowCount 3
			$script:insertResult = Invoke-SldgDataGeneration -Plan $planForInsert -Confirm:$false
			$insertResult | Should -Not -BeNullOrEmpty
			$insertResult.SuccessCount | Should -Be 2
		}

		It "Validates generated data" -Skip:(-not $sqliteAvailable) {
			$validation = Test-SldgGeneratedData -Schema $analyzed
			$validation | Should -Not -BeNullOrEmpty
		}

		It "Disconnects cleanly" -Skip:(-not $sqliteAvailable) {
			{ Disconnect-SldgDatabase } | Should -Not -Throw
		}
	}

	Context "Masking Mode - Read, Mask PII, Delete+Insert" -Skip:(-not $sqliteAvailable) {
		BeforeAll {
			$dbPathMask = Join-Path $TestDrive 'test_masking.db'

			if ($sqliteAvailable) {
				try {
					$null = [System.Reflection.Assembly]::LoadWithPartialName('Microsoft.Data.Sqlite')
					$conn = [Microsoft.Data.Sqlite.SqliteConnection]::new("Data Source=$dbPathMask")
				}
				catch {
					$null = [System.Reflection.Assembly]::LoadWithPartialName('System.Data.SQLite')
					$conn = [System.Data.SQLite.SQLiteConnection]::new("Data Source=$dbPathMask")
				}

				$conn.Open()
				$cmd = $conn.CreateCommand()

				$cmd.CommandText = @"
CREATE TABLE Customer (
    Id INTEGER PRIMARY KEY AUTOINCREMENT,
    FirstName TEXT NOT NULL,
    LastName TEXT NOT NULL,
    Email TEXT,
    Phone TEXT
);
"@
				$null = $cmd.ExecuteNonQuery()

				# Seed with known data that will be masked
				$cmd.CommandText = "INSERT INTO Customer (FirstName, LastName, Email, Phone) VALUES ('John', 'Doe', 'john.doe@example.com', '555-1234')"
				$null = $cmd.ExecuteNonQuery()
				$cmd.CommandText = "INSERT INTO Customer (FirstName, LastName, Email, Phone) VALUES ('Jane', 'Smith', 'jane.smith@example.com', '555-5678')"
				$null = $cmd.ExecuteNonQuery()

				$conn.Close()
				$conn.Dispose()
			}
		}

		It "Connects for masking" -Skip:(-not $sqliteAvailable) {
			{ Connect-SldgDatabase -Provider 'SQLite' -Database $dbPathMask } | Should -Not -Throw
		}

		It "Masks PII columns in existing data" -Skip:(-not $sqliteAvailable) {
			$schema = Get-SldgDatabaseSchema
			$analyzed = Get-SldgColumnAnalysis -Schema $schema
			$plan = New-SldgGenerationPlan -Schema $analyzed -Mode 'Masking'

			$result = Invoke-SldgDataGeneration -Plan $plan -Confirm:$false
			$result | Should -Not -BeNullOrEmpty

			# Row count should stay the same (2 rows — masked, not added)
			$result.TotalRows | Should -Be 2

			# Verify the original values are no longer present
			$connInfo = & (Get-Module SqlLabDataGenerator) { $script:SldgState.ActiveConnection }
			$cmd = $connInfo.Connection.CreateCommand()
			$cmd.CommandText = "SELECT FirstName, Email FROM Customer"
			$reader = $cmd.ExecuteReader()
			$rows = @()
			while ($reader.Read()) {
				$rows += [PSCustomObject]@{ FirstName = $reader['FirstName']; Email = $reader['Email'] }
			}
			$reader.Close()
			$cmd.Dispose()

			$rows.Count | Should -Be 2
			$rows[0].FirstName | Should -Not -Be 'John'
			$rows[1].FirstName | Should -Not -Be 'Jane'
			$rows[0].Email | Should -Not -Be 'john.doe@example.com'
		}

		It "Disconnects after masking" -Skip:(-not $sqliteAvailable) {
			{ Disconnect-SldgDatabase } | Should -Not -Throw
		}
	}

	Context "Profile Round-Trip" -Skip:(-not $sqliteAvailable) {
		BeforeAll {
			$dbPath2 = Join-Path $TestDrive 'test_profile_rt.db'

			if ($sqliteAvailable) {
				try {
					$null = [System.Reflection.Assembly]::LoadWithPartialName('Microsoft.Data.Sqlite')
					$conn = [Microsoft.Data.Sqlite.SqliteConnection]::new("Data Source=$dbPath2")
				}
				catch {
					$null = [System.Reflection.Assembly]::LoadWithPartialName('System.Data.SQLite')
					$conn = [System.Data.SQLite.SQLiteConnection]::new("Data Source=$dbPath2")
				}

				$conn.Open()
				$cmd = $conn.CreateCommand()
				$cmd.CommandText = "CREATE TABLE Product (Id INTEGER PRIMARY KEY AUTOINCREMENT, Name TEXT NOT NULL, Price REAL, Category TEXT);"
				$null = $cmd.ExecuteNonQuery()
				$conn.Close()
				$conn.Dispose()
			}
		}

		It "Exports and imports profile" -Skip:(-not $sqliteAvailable) {
			Connect-SldgDatabase -Provider 'SQLite' -Database $dbPath2
			$schema = Get-SldgDatabaseSchema
			$analyzed = Get-SldgColumnAnalysis -Schema $schema
			$plan = New-SldgGenerationPlan -Schema $analyzed -RowCount 10

			$profilePath = Join-Path $TestDrive 'export_profile.json'
			Export-SldgGenerationProfile -Plan $plan -Path $profilePath
			Test-Path $profilePath | Should -BeTrue

			# Import into a new plan
			$plan2 = New-SldgGenerationPlan -Schema $analyzed -RowCount 5
			Import-SldgGenerationProfile -Path $profilePath -Plan $plan2
			$plan2.Tables[0].RowCount | Should -Be 10

			Disconnect-SldgDatabase
		}
	}
}
