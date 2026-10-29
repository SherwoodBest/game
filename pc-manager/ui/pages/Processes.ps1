# Running apps: memory and CPU per app, with End task.

# Parts of Windows (and PC Manager itself) that should never be ended from here.
$ProtectedProcesses = @(
    'System', 'Idle', 'Registry', 'Secure System', 'Memory Compression', 'smss', 'csrss', 'wininit', 'winlogon',
    'services', 'lsass', 'LsaIso', 'svchost', 'dwm', 'explorer', 'fontdrvhost', 'sihost', 'ctfmon', 'conhost',
    'MsMpEng', 'NisSrv', 'SecurityHealthService', 'SgrmBroker', 'spoolsv', 'audiodg', 'WUDFHost', 'dllhost',
    'taskhostw', 'RuntimeBroker', 'smartscreen', 'StartMenuExperienceHost', 'ShellExperienceHost', 'SearchHost',
    'SearchIndexer', 'TextInputHost', 'WmiPrvSE', 'powershell', 'pwsh'
)
$ProcShowLimit = 80
$ProcScanJob = { Get-ProcessUsage }

function Start-ProcScan([switch]$Quiet) {
    if ($Quiet -and (Test-WorkRunning)) { return }
    $ui.ProcSummarySub.Text = 'Watching your apps for a second...'
    $started = Start-Work -Script $ProcScanJob `
        -OnDone { param($out) Show-ProcList @($out) } `
        -OnError { param($err) Show-Toast ('Could not read running apps: {0}' -f $err.Message) 'error' }
    if (-not $started) { $ui.ProcSummarySub.Text = 'Waiting for another task to finish. Press refresh in a moment.' }
}

function Show-ProcList($Rows) {
    $script:ProcLoaded = $true
    $info = New-Object Microsoft.VisualBasic.Devices.ComputerInfo
    $total = [double]$info.TotalPhysicalMemory
    $free = [double]$info.AvailablePhysicalMemory
    $usedPct = $(if ($total -gt 0) { ($total - $free) * 100 / $total } else { 0 })
    $processCount = ($Rows | Measure-Object -Property Count -Sum).Sum
    $ui.ProcSummary.Text = 'Memory {0:N0}% used' -f $usedPct
    $ui.ProcSummarySub.Text = '{0} of {1} in use by {2} apps and background tasks ({3} processes).' -f (Format-Size ($total - $free)), (Format-Size $total), $Rows.Count, $processCount
    $ui.ProcMemBar.Value = $usedPct
    Set-Color $ui.ProcMemBar ([System.Windows.Controls.Control]::ForegroundProperty) (Get-LevelColor $usedPct)

    $ui.ProcList.Children.Clear()
    $shown = @($Rows | Select-Object -First $ProcShowLimit)
    $biggest = [math]::Max(1, ($shown | Measure-Object -Property Memory -Maximum).Maximum)
    foreach ($row in $shown) {
        [void]$ui.ProcList.Children.Add((New-ProcRow $row $biggest))
    }
    $ui.ProcFooter.Text = $(if ($Rows.Count -gt $ProcShowLimit) { 'Showing the {0} biggest of {1}. Updated at {2}.' -f $ProcShowLimit, $Rows.Count, (Get-Date -Format 'HH:mm:ss') } else { 'Updated at {0}.' -f (Get-Date -Format 'HH:mm:ss') })
    Update-ProcFilter
}

function New-ProcRow($Proc, [double]$Biggest) {
    $right = New-Object System.Windows.Controls.Grid
    Add-Column $right 200
    Add-Column $right 64
    Add-Column $right 104

    $memory = New-Object System.Windows.Controls.StackPanel
    $memory.VerticalAlignment = 'Center'
    $memory.Margin = New-Thick 16 0 0 0
    [void]$memory.Children.Add((New-Text (Format-Size $Proc.Memory) 12.5 'Text' -Bold))
    $bar = New-Bar ($Proc.Memory * 100 / $Biggest) 'Accent' 4
    $bar.Margin = New-Thick 0 5 20 0
    [void]$memory.Children.Add($bar)
    Add-ToGrid $right $memory 0

    $cpu = New-Text ('{0:N1}%' -f $Proc.Cpu) 12.5 $(if ($Proc.Cpu -ge 25) { 'Warn' } else { 'TextSub' })
    $cpu.HorizontalAlignment = 'Right'
    $cpu.VerticalAlignment = 'Center'
    Add-ToGrid $right $cpu 1

    if ($ProtectedProcesses -contains $Proc.Name) {
        $action = New-Pill 'Windows' 'TextSub' 'Track'
        $action.HorizontalAlignment = 'Right'
        $action.ToolTip = 'Part of Windows. It cannot be ended here.'
    } else {
        $action = New-Button 'End task' {
            param($s, $e)
            Invoke-Guarded { param($b) Stop-ProcGroup $b.Tag } $s
        } $Proc 'Btn.Subtle'
        $action.HorizontalAlignment = 'Right'
        $action.Padding = New-Thick 12 5 12 5
        $action.MinHeight = 30
    }
    Add-ToGrid $right $action 2

    $subtitle = '{0}.exe' -f $Proc.Name
    if ($Proc.Count -gt 1) { $subtitle += ('  -  {0} processes' -f $Proc.Count) }
    $row = New-ListRow (New-AppIcon $Proc.Path 0xE9D9 32) $Proc.Description $subtitle $right
    $row.Tag = ('{0} {1}' -f $Proc.Name, $Proc.Description).ToLower()
    return $row
}

function Update-ProcFilter {
    $query = $ui.ProcSearch.Text.Trim().ToLower()
    foreach ($row in $ui.ProcList.Children) {
        if ($row.Tag -is [string]) {
            $row.Visibility = $(if (-not $query -or $row.Tag.Contains($query)) { 'Visible' } else { 'Collapsed' })
        }
    }
}

function Stop-ProcGroup($Proc) {
    $text = "This closes {0} straight away{1}. Anything unsaved in it will be lost." -f $Proc.Description, $(if ($Proc.Count -gt 1) { (' ({0} processes)' -f $Proc.Count) } else { '' })
    if (-not (Confirm-Action ('End {0}?' -f $Proc.Description) $text 'End task' 'warn')) { return }
    $ended = 0
    $failed = 0
    foreach ($p in @(Get-Process -Name $Proc.Name -ErrorAction SilentlyContinue)) {
        if ($p.Id -eq $PID) { continue }
        try { $p.Kill(); $ended++ } catch { $failed++ }
    }
    Write-Activity ('Ended {0} ({1} processes)' -f $Proc.Name, $ended)
    if ($failed -gt 0) {
        Show-Toast ('{0} could not be fully ended. It may need administrator rights.' -f $Proc.Description) 'warn'
    } else {
        Show-Toast ('{0} was closed.' -f $Proc.Description) 'success'
    }
    Start-ProcScan
}

Register-Page 'Processes' -Init {
    $ui.ProcRefresh.Add_Click({ Invoke-Guarded { Start-ProcScan } })
    $ui.ProcSearch.Add_TextChanged({ Update-ProcFilter })
} -Show {
    Start-ProcScan -Quiet
}
