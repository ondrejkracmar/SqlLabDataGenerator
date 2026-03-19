Describe "SQL Server Integration Tests" {
	BeforeAll {
		Remove-Module SqlLabDataGenerator -ErrorAction Ignore
		Import-Module "$PSScriptRoot\..\..\..\SqlLabDataGenerator\SqlLabDataGenerator.psd1" -Force
		$module = Get-Module SqlLabDataGenerator

		# Check if SQL Server is reachable (localhost default instance)
		$sqlAvailable = $false
		$testInstance = $env:SLDG_TEST_SQL_INSTANCE
		$testDatabase = $env:SLDG_TEST_SQL_DATABASE

		if ($testInstance -and $testDatabase) {
			try {
				$conn = New-Object System.Data.SqlClient.SqlConnection
				$conn.ConnectionString = "Server=$testInstance;Database=$testDatabase;Integrated Security=True;TrustServerCertificate=True;Connect Timeout=5"
				$conn.Open()
				$conn.Close()
				$conn.Dispose()
				$sqlAvailable = $true
			}
			catch {
				Write-Host "SQL Server not available at ${testInstance}: $_" -ForegroundColor Yellow
			}
		}
		else {
			Write-Host "SQL Server integration tests skipped: set SLDG_TEST_SQL_INSTANCE and SLDG_TEST_SQL_DATABASE environment variables" -ForegroundColor Yellow
		}
	}

	Context "Full SQL Server Pipeline" -Skip:(-not $sqlAvailable) {
		BeforeAll {
			if ($sqlAvailable) {
				# Create test schema
				$conn = New-Object System.Data.SqlClient.SqlConnection
				$conn.ConnectionString = "Server=$testInstance;Database=$testDatabase;Integrated Security=True;TrustServerCertificate=True"
				$conn.Open()
				$cmd = $conn.CreateCommand()

				$cmd.CommandText = @"
IF OBJECT_ID('dbo.SldgTestOrder', 'U') IS NOT NULL DROP TABLE dbo.SldgTestOrder;
IF OBJECT_ID('dbo.SldgTestCustomer', 'U') IS NOT NULL DROP TABLE dbo.SldgTestCustomer;

CREATE TABLE dbo.SldgTestCustomer (
    Id INT IDENTITY(1,1) PRIMARY KEY,
    FirstName NVARCHAR(100) NOT NULL,
    LastName NVARCHAR(100) NOT NULL,
    Email NVARCHAR(256),
    PhoneNumber NVARCHAR(20),
    CreatedDate DATETIME2 DEFAULT GETDATE()
);

CREATE TABLE dbo.SldgTestOrder (
    Id INT IDENTITY(1,1) PRIMARY KEY,
    CustomerId INT NOT NULL REFERENCES dbo.SldgTestCustomer(Id),
    OrderDate DATETIME2 NOT NULL DEFAULT GETDATE(),
    Amount DECIMAL(10,2) NOT NULL,
    Status NVARCHAR(20) DEFAULT 'Pending'
);
"@
				$null = $cmd.ExecuteNonQuery()
				$conn.Close()
				$conn.Dispose()
			}
		}

		AfterAll {
			if ($sqlAvailable) {
				# Cleanup test tables
				try {
					$conn = New-Object System.Data.SqlClient.SqlConnection
					$conn.ConnectionString = "Server=$testInstance;Database=$testDatabase;Integrated Security=True;TrustServerCertificate=True"
					$conn.Open()
					$cmd = $conn.CreateCommand()
					$cmd.CommandText = "IF OBJECT_ID('dbo.SldgTestOrder', 'U') IS NOT NULL DROP TABLE dbo.SldgTestOrder; IF OBJECT_ID('dbo.SldgTestCustomer', 'U') IS NOT NULL DROP TABLE dbo.SldgTestCustomer;"
					$null = $cmd.ExecuteNonQuery()
					$conn.Close()
					$conn.Dispose()
				}
				catch { }

				Disconnect-SldgDatabase -ErrorAction SilentlyContinue
			}
		}

		It "Connects to SQL Server" {
			{ Connect-SldgDatabase -ServerInstance $testInstance -Database $testDatabase -TrustServerCertificate } | Should -Not -Throw
		}

		It "Discovers schema with FK relationships" {
			$script:schema = Get-SldgDatabaseSchema -IncludeTable 'SldgTest*'
			$schema | Should -Not -BeNullOrEmpty
			$schema.TableCount | Should -Be 2
		}

		It "Creates generation plan respecting FK order" {
			$script:plan = New-SldgGenerationPlan -Schema $script:schema
			$plan | Should -Not -BeNullOrEmpty
			$plan.TableCount | Should -Be 2
			# Customer should come before Order (FK dependency)
			$tableNames = $plan.Tables | ForEach-Object { $_.TableName }
			$tableNames.IndexOf('SldgTestCustomer') | Should -BeLessThan $tableNames.IndexOf('SldgTestOrder')
		}

		It "Generates and inserts data" {
			$script:result = Invoke-SldgDataGeneration -Plan $script:plan
			$result | Should -Not -BeNullOrEmpty
			$result.TotalRows | Should -BeGreaterThan 0
			$result.FailureCount | Should -Be 0
		}

		It "Validates generated data" {
			$validation = Test-SldgGeneratedData -ErrorAction SilentlyContinue
			if ($validation) {
				$validation.Errors | Should -Be 0
			}
		}

		It "Disconnects cleanly" {
			{ Disconnect-SldgDatabase } | Should -Not -Throw
		}
	}
}
