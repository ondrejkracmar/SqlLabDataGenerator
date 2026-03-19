Import-Module Pester
Remove-Module SqlLabDataGenerator -ErrorAction Ignore
Import-Module .\SqlLabDataGenerator\SqlLabDataGenerator.psd1 -Force
$module = Get-Module SqlLabDataGenerator

function New-TestDataTable {
    param([string[]]$ColumnNames, [object[][]]$Rows)
    $dt = [System.Data.DataTable]::new()
    foreach ($name in $ColumnNames) { $null = $dt.Columns.Add($name) }
    foreach ($row in $Rows) { $null = $dt.Rows.Add($row) }
    $dt
}

$tables = New-TestDataTable -ColumnNames @('TABLE_SCHEMA', 'TABLE_NAME') -Rows @(
    , @('dbo', 'Customer')
    , @('dbo', 'Order')
)

$columns = [System.Data.DataTable]::new()
$null = $columns.Columns.Add('TABLE_SCHEMA', [string])
$null = $columns.Columns.Add('TABLE_NAME', [string])
$null = $columns.Columns.Add('COLUMN_NAME', [string])
$null = $columns.Columns.Add('DATA_TYPE', [string])
$null = $columns.Columns.Add('CHARACTER_MAXIMUM_LENGTH', [object])
$null = $columns.Columns.Add('NUMERIC_PRECISION', [object])
$null = $columns.Columns.Add('NUMERIC_SCALE', [object])
$null = $columns.Columns.Add('IS_NULLABLE', [string])
$null = $columns.Columns.Add('COLUMN_DEFAULT', [object])
$null = $columns.Columns.Add('ORDINAL_POSITION', [int])
$null = $columns.Columns.Add('IsIdentity', [int])
$null = $columns.Columns.Add('IsComputed', [int])

$null = $columns.Rows.Add('dbo', 'Customer', 'Id', 'int', [DBNull]::Value, [DBNull]::Value, [DBNull]::Value, 'NO', [DBNull]::Value, 1, 1, 0)
$null = $columns.Rows.Add('dbo', 'Customer', 'FirstName', 'nvarchar', 50, [DBNull]::Value, [DBNull]::Value, 'NO', [DBNull]::Value, 2, 0, 0)
$null = $columns.Rows.Add('dbo', 'Customer', 'Email', 'nvarchar', 100, [DBNull]::Value, [DBNull]::Value, 'YES', [DBNull]::Value, 3, 0, 0)

$fks = [System.Data.DataTable]::new()
$null = $fks.Columns.Add('ForeignKeyName', [string])
$null = $fks.Columns.Add('ParentSchema', [string])
$null = $fks.Columns.Add('ParentTable', [string])
$null = $fks.Columns.Add('ParentColumn', [string])
$null = $fks.Columns.Add('ReferencedSchema', [string])
$null = $fks.Columns.Add('ReferencedTable', [string])
$null = $fks.Columns.Add('ReferencedColumn', [string])
$null = $fks.Rows.Add('FK_Order_Customer', 'dbo', 'Order', 'CustomerId', 'dbo', 'Customer', 'Id')

$uniques = [System.Data.DataTable]::new()
$null = $uniques.Columns.Add('SchemaName', [string])
$null = $uniques.Columns.Add('TableName', [string])
$null = $uniques.Columns.Add('ColumnName', [string])
$null = $uniques.Columns.Add('IsPrimaryKey', [bool])
$null = $uniques.Columns.Add('IsUnique', [bool])
$null = $uniques.Rows.Add('dbo', 'Customer', 'Id', $true, $true)
$null = $uniques.Rows.Add('dbo', 'Order', 'Id', $true, $true)

$checks = [System.Data.DataTable]::new()
$null = $checks.Columns.Add('SchemaName', [string])
$null = $checks.Columns.Add('TableName', [string])
$null = $checks.Columns.Add('ColumnName', [string])
$null = $checks.Columns.Add('ConstraintDefinition', [string])

Write-Host "tables type: $($tables.GetType().FullName), rows: $($tables.Rows.Count)"
Write-Host "columns type: $($columns.GetType().FullName), rows: $($columns.Rows.Count)"
Write-Host "fks type: $($fks.GetType().FullName), rows: $($fks.Rows.Count)"
Write-Host "uniques type: $($uniques.GetType().FullName), rows: $($uniques.Rows.Count)"
Write-Host "checks type: $($checks.GetType().FullName), rows: $($checks.Rows.Count)"

$schema = & $module {
    param($t, $c, $f, $u, $ch)
    Write-Host "Inside module:"
    Write-Host "  t type: $(if($null -ne $t){$t.GetType().FullName}else{'NULL'})"
    Write-Host "  c type: $(if($null -ne $c){$c.GetType().FullName}else{'NULL'})"
    Write-Host "  f type: $(if($null -ne $f){$f.GetType().FullName}else{'NULL'})"
    Write-Host "  u type: $(if($null -ne $u){$u.GetType().FullName}else{'NULL'})"
    Write-Host "  ch type: $(if($null -ne $ch){$ch.GetType().FullName}else{'NULL'})"
    
    ConvertTo-SldgSchemaModel -Tables $t -Columns $c -ForeignKeys $f -UniqueConstraints $u -CheckConstraints $ch -Database 'TestDB'
} $tables $columns $fks $uniques $checks

Write-Host "Schema: TableCount=$($schema.TableCount)"
if ($schema.Tables) {
    foreach ($tbl in $schema.Tables) {
        Write-Host "  Table: $($tbl.SchemaName).$($tbl.TableName), Cols=$($tbl.ColumnCount), FKs=$($tbl.ForeignKeys.Count)"
        if ($tbl.Columns) {
            foreach ($col in $tbl.Columns) {
                Write-Host "    Col: $($col.ColumnName) [$($col.DataType)] PK=$($col.IsPrimaryKey) Identity=$($col.IsIdentity) FK=$($col.ForeignKey)"
            }
        }
    }
}
