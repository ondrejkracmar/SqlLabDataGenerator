Import-Module "$PSScriptRoot\SqlLabDataGenerator\SqlLabDataGenerator.psd1" -Force
$module = Get-Module SqlLabDataGenerator

$dt = New-Object System.Data.DataTable
[void]$dt.Columns.Add('Name', [string])
$r = $dt.NewRow()
$r['Name'] = 'test'
[void]$dt.Rows.Add($r)
$r2 = $dt.NewRow()
$r2['Name'] = 'test2'
[void]$dt.Rows.Add($r2)
Write-Host "DataTable has $($dt.Rows.Count) rows"

Write-Host "--- Test A: -ArgumentList (,`$dt) ---"
try {
    & $module {
        param($d)
        Write-Host "type: $(if($null -ne $d){$d.GetType().FullName}else{'NULL'})"
    } -ArgumentList (,$dt)
} catch { Write-Host "ERR: $_" }

Write-Host "--- Test B: [ref] ---"
try {
    & $module {
        param($dref)
        $d = $dref.Value
        Write-Host "type: $($d.GetType().FullName)"
    } -ArgumentList ([ref]$dt)
} catch { Write-Host "ERR: $_" }

Write-Host "--- Test C: positional ---"
try {
    & $module {
        param($d)
        Write-Host "type: $(if($null -ne $d){$d.GetType().FullName}else{'NULL'})"
    } $dt
} catch { Write-Host "ERR: $_" }

Write-Host "--- Test D: Create inside module ---"
try {
    & $module {
        param($rows)
        Write-Host "rows type: $(if($null -ne $rows){$rows.GetType().FullName}else{'NULL'})"
    } -ArgumentList @(, @($dt.Rows[0]))
} catch { Write-Host "ERR: $_" }

Write-Host "--- Test E: variable in module scope ---"
& $module { param($d) $script:__tempDT = $d } -ArgumentList (,$dt)
$result = & $module { $script:__tempDT }
Write-Host "E result type: $(if($null -ne $result){$result.GetType().FullName}else{'NULL'})"

Write-Host "--- Test F: use InvokeReturnAsIs ---"
try {
    $sb = [scriptblock]::Create('param($d) Write-Host "F type: $($d.GetType().FullName)"')
    $sb2 = $module.NewBoundScriptBlock($sb)
    $sb2.InvokeReturnAsIs($dt)
} catch { Write-Host "ERR: $_" }
