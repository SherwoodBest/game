# Home: health score, one-click scan and fix, recommendations, system summary.

# The safe junk that "Fix all" removes: everything ticked by default that this
# session may clean. Never the Recycle Bin or browser caches.
function Get-FixKeys {
    return @($CleanTargets | Where-Object { $_.Default -and ($IsAdmin -or -not $_.Admin) } | ForEach-Object { $_.Key })
}

$HomeScanJob = {
    param([string[]]$Keys, [int]$StartupOn)
    Set-JobProgress 'Checking your system...' 4
    $snapshot = Get-SystemSnapshot
    Set-JobProgress 'Checking the battery...' 12
    $battery = Get-BatteryInfo
    $junk = 0.0
    for ($i = 0; $i -lt $Keys.Count; $i++) {
        $target = Get-CleanTarget $Keys[$i]
        Set-JobProgress ('Looking for junk: {0}...' -f $target.Name.ToLower()) (14 + 80 * $i / [math]::Max(1, $Keys.Count))
        $junk += (Measure-Target $target).Bytes
    }
    Set-JobProgress 'Putting it together...' 98
    [pscustomobject]@{
        Snapshot = $snapshot
        Battery  = $battery
        Junk     = $junk
        Report   = (Get-HealthReport $snapshot $battery $junk $StartupOn)
    }
}

$HomeFixJob = {
    param([string[]]$Keys)
    $result = Invoke-CleanerClean $Keys
    try { Clear-DnsClientCache -ErrorAction Stop } catch { }
    $result
}

function Set-HomeBusy([bool]$Busy, [string]$Text = 'Starting...') {
    $ui.HomeButtons.Visibility = $(if ($Busy) { 'Collapsed' } else { 'Visible' })
    $ui.HomeProgressBox.Visibility = $(if ($Busy) { 'Visible' } else { 'Collapsed' })
    if ($Busy) { Reset-ProgressLine $ui.HomeProgress $ui.HomeProgressText $Text }
}

function Start-HomeScan {
    $startupOn = @(Get-StartupItems | Where-Object { $_.Enabled }).Count
    Set-HomeBusy $true 'Checking your system...'
    $ui.HomeStatusTitle.Text = 'Scanning your PC...'
    $ui.HomeStatusText.Text = 'This takes a few seconds. You can keep using PC Manager meanwhile.'
    $ui.HomeScore.Text = '--'
    Set-Color $ui.HomeRing ([System.Windows.Shapes.Shape]::StrokeProperty) 'Accent'
    Start-Spin $ui.HomeRing
    $started = Start-Work -Script $HomeScanJob -Arguments @((Get-FixKeys), $startupOn) `
        -OnProgress { param($text, $percent) Set-ProgressLine $ui.HomeProgress $ui.HomeProgressText $text $percent } `
        -OnDone { param($out) Show-HomeResult $out[-1] } `
        -OnError {
        param($err)
        Stop-Spin $ui.HomeRing
        Set-Ring $ui.HomeRing 0
        Set-HomeBusy $false
        $ui.HomeStatusTitle.Text = 'The scan did not finish'
        $ui.HomeStatusText.Text = $err.Message
    }
    if (-not $started) {
        Stop-Spin $ui.HomeRing
        Set-Ring $ui.HomeRing 0
        Set-HomeBusy $false
    }
}

function Show-HomeResult($Result) {
    $script:HomeResult = $Result
    $script:HomeScanned = $true
    Set-HomeBusy $false
    Stop-Spin $ui.HomeRing
    $report = $Result.Report

    $color = 'Good'
    if ($report.Score -lt 75) { $color = 'Warn' }
    if ($report.Score -lt 55) { $color = 'Bad' }
    Set-Color $ui.HomeRing ([System.Windows.Shapes.Shape]::StrokeProperty) $color
    Start-RingFill $ui.HomeRing $report.Score $ui.HomeScore

    $titles = @{
        'Excellent'       = 'Your PC is in great shape'
        'Good'            = 'Your PC is in good shape'
        'Fair'            = 'Your PC could use a tune-up'
        'Needs attention' = 'Your PC needs some attention'
    }
    $ui.HomeStatusTitle.Text = $titles[$report.Label]
    $count = @($report.Issues).Count
    if ($count -gt 0) {
        $things = $(if ($count -eq 1) { '1 thing' } else { '{0} things' -f $count })
        $ui.HomeStatusText.Text = '{0} could make it faster. Fix all removes {1} of junk files and clears the DNS cache. The rest is up to you below.' -f $things, (Format-Size $Result.Junk)
    } else {
        $ui.HomeStatusText.Text = 'Nothing needs your attention right now. Last checked at {0}.' -f (Get-Date -Format 'HH:mm')
    }

    $ui.HomeScanBtn.Visibility = 'Collapsed'
    $ui.HomeFixBtn.Visibility = $(if ($Result.Junk -ge 1MB) { 'Visible' } else { 'Collapsed' })
    $ui.HomeRescanBtn.Visibility = 'Visible'

    Update-HomeIssues $report.Issues
    Update-HomeSummary $Result.Snapshot $Result.Battery
    Write-Activity ('Health check: {0} ({1}/100)' -f $report.Label, $report.Score)
}

$HomeActionLabels = @{
    clean = 'Clean now'; storage = 'Free up space'; processes = 'View apps'
    startup = 'Review'; restart = 'Restart'; battery = 'Details'
}
$HomeLevelLooks = @{
    bad  = @{ Glyph = 0xE783; Color = 'Bad'; Soft = 'BadSoft' }
    warn = @{ Glyph = 0xE7BA; Color = 'Warn'; Soft = 'WarnSoft' }
    info = @{ Glyph = 0xE946; Color = 'Accent'; Soft = 'AccentSoft' }
}

function Update-HomeIssues($Issues) {
    $ui.HomeIssues.Children.Clear()
    $list = @($Issues)
    $ui.HomeIssuesCard.Visibility = $(if ($list.Count -gt 0) { 'Visible' } else { 'Collapsed' })
    foreach ($issue in $list) {
        $look = $HomeLevelLooks[$issue.Level]
        $button = New-Button $HomeActionLabels[$issue.Action] {
            param($s, $e)
            Invoke-Guarded { param($b) Invoke-HomeAction ([string]$b.Tag) } $s
        } $issue.Action
        $row = New-ListRow (New-IconTile $look.Glyph $look.Color $look.Soft 36) $issue.Title $issue.Detail $button
        [void]$ui.HomeIssues.Children.Add($row)
    }
}

function Invoke-HomeAction([string]$Action) {
    switch ($Action) {
        'clean' { Start-HomeFix }
        'storage' { Show-Page 'Storage' }
        'processes' { Show-Page 'Processes' }
        'startup' { Show-Page 'Startup' }
        'battery' { Show-Page 'Power' }
        'restart' {
            if (Confirm-Action 'Restart now?' 'Save your work and close your apps first. Your PC restarts in about five seconds.' 'Restart' 'warn') {
                Write-Activity 'Restart requested from Home.'
                Start-Process -FilePath 'shutdown.exe' -ArgumentList '/r /t 5' -WindowStyle Hidden
            }
        }
    }
}

function Start-HomeFix {
    $junk = 0.0
    if ($script:HomeResult) { $junk = $script:HomeResult.Junk }
    if ($Settings.ConfirmDelete) {
        $text = "PC Manager will remove {0} of temporary files, caches and leftovers, and clear the DNS cache.`n`nYour documents, photos, passwords and browsing history are not touched." -f (Format-Size $junk)
        if (-not (Confirm-Action 'Fix all?' $text 'Fix all')) { return }
    }
    Set-HomeBusy $true 'Cleaning...'
    $ui.HomeStatusTitle.Text = 'Cleaning up...'
    Start-Spin $ui.HomeRing
    $started = Start-Work -Script $HomeFixJob -Arguments @(, @(Get-FixKeys)) `
        -OnProgress { param($text, $percent) Set-ProgressLine $ui.HomeProgress $ui.HomeProgressText $text $percent } `
        -OnDone {
        param($out)
        $result = $out[-1]
        Write-Activity ('Fix all: freed {0}' -f (Format-Size $result.Total))
        Show-Toast ('All done. Freed {0}.' -f (Format-Size $result.Total)) 'success'
        Start-HomeScan
    } `
        -OnError {
        param($err)
        Stop-Spin $ui.HomeRing
        Set-HomeBusy $false
        Show-Toast ('Cleaning stopped: {0}' -f $err.Message) 'error'
    }
    if (-not $started) {
        Stop-Spin $ui.HomeRing
        Set-HomeBusy $false
    }
}

function Update-HomeSummary($Snapshot, $Battery) {
    $ui.HomeInfo.Children.Clear()
    Add-InfoRow $ui.HomeInfo 'Device' $Snapshot.Model
    Add-InfoRow $ui.HomeInfo 'Windows' ('{0} (build {1})' -f $Snapshot.OS, $Snapshot.Build)
    Add-InfoRow $ui.HomeInfo 'Processor' ('{0} ({1} threads)' -f $Snapshot.Cpu, $Snapshot.Cores)
    if ($Snapshot.Gpu) { Add-InfoRow $ui.HomeInfo 'Graphics' $Snapshot.Gpu }
    Add-InfoRow $ui.HomeInfo 'Memory' (Format-Size $Snapshot.RamTotal)
    Add-InfoRow $ui.HomeInfo 'Up time' (Format-Duration $Snapshot.Uptime)
    if ($Battery) {
        $text = '{0}%, {1}' -f $Battery.Charge, $(if ($Battery.Plugged) { 'plugged in' } else { 'on battery' })
        if ($Battery.Health) { $text += (' - health {0}%' -f $Battery.Health) }
        Add-InfoRow $ui.HomeInfo 'Battery' $text
    }

    $ui.HomeUsage.Children.Clear()
    $ramUsed = $Snapshot.RamTotal - $Snapshot.RamFree
    $ramPct = $(if ($Snapshot.RamTotal -gt 0) { $ramUsed * 100 / $Snapshot.RamTotal } else { 0 })
    Add-UsageRow $ui.HomeUsage 'Memory' $ramPct ('{0} of {1}' -f (Format-Size $ramUsed), (Format-Size $Snapshot.RamTotal))
    if ($null -ne $Snapshot.CpuLoad) {
        Add-UsageRow $ui.HomeUsage 'Processor' $Snapshot.CpuLoad ('{0:N0}% busy' -f $Snapshot.CpuLoad)
    }
    foreach ($drive in $Snapshot.Drives) {
        if ($drive.Total -le 0) { continue }
        $usedPct = ($drive.Total - $drive.Free) * 100 / $drive.Total
        Add-UsageRow $ui.HomeUsage ('{0} {1}' -f $drive.Label, $drive.Name) $usedPct ('{0} free of {1}' -f (Format-Size $drive.Free), (Format-Size $drive.Total))
    }
}

Register-Page 'Home' -Init {
    $hour = (Get-Date).Hour
    $greeting = 'Good evening'
    if ($hour -lt 18) { $greeting = 'Good afternoon' }
    if ($hour -lt 12) { $greeting = 'Good morning' }
    $name = $env:USERNAME
    if ($name) { $name = $name.Substring(0, 1).ToUpper() + $name.Substring(1) }
    $ui.HomeGreeting.Text = $(if ($name) { '{0}, {1}' -f $greeting, $name } else { $greeting })

    $ui.HomeScanBtn.Add_Click({ Invoke-Guarded { Start-HomeScan } })
    $ui.HomeRescanBtn.Add_Click({ Invoke-Guarded { Start-HomeScan } })
    $ui.HomeFixBtn.Add_Click({ Invoke-Guarded { Start-HomeFix } })

    $go = { param($s, $e) Show-Page ([string]$s.Tag) }
    foreach ($tile in @(
            (New-QuickTile 0xE74D 'Clean junk' 'Temp files and caches' $go 'Cleaner'),
            (New-QuickTile 0xEDA2 'Free up space' 'Find large files' $go 'Storage'),
            (New-QuickTile 0xE7E8 'Startup apps' 'Start Windows faster' $go 'Startup'),
            (New-QuickTile 0xE83F 'Battery' 'Health and power plans' $go 'Power'),
            (New-QuickTile 0xE90F 'Toolbox' 'Repairs and updates' $go 'Toolbox')
        )) {
        [void]$ui.HomeQuick.Children.Add($tile)
    }
} -Show {
    if (-not $script:HomeAutoStarted) {
        $script:HomeAutoStarted = $true
        Start-HomeScan
    }
}
