# Cleaner: pick categories, scan, clean.

$CleanCheck = @{}
$CleanSize = @{}
$CleanBytes = @{}

$CleanScanJob = { param([string[]]$Keys) Invoke-CleanerScan $Keys }
$CleanRunJob = { param([string[]]$Keys) Invoke-CleanerClean $Keys }

function Get-CleanAllowedKeys {
    return @($CleanTargets | Where-Object { $IsAdmin -or -not $_.Admin } | ForEach-Object { $_.Key })
}

function New-CleanRow($Target) {
    $check = New-Object System.Windows.Controls.CheckBox
    $check.IsChecked = $Target.Default
    $check.Tag = $Target.Key

    $grid = New-Object System.Windows.Controls.Grid
    Add-Column $grid 'Auto'
    Add-Column $grid '*'
    Add-Column $grid 'Auto'
    $icon = New-IconTile $Target.Glyph 'Accent' 'AccentSoft' 36
    $icon.Margin = New-Thick 0 0 14 0
    Add-ToGrid $grid $icon 0

    $text = New-Object System.Windows.Controls.StackPanel
    $text.VerticalAlignment = 'Center'
    $titleLine = New-Object System.Windows.Controls.StackPanel
    $titleLine.Orientation = 'Horizontal'
    [void]$titleLine.Children.Add((New-Text $Target.Name 13.5 'Text' -Bold))
    $badge = $null
    if ($Target.Admin -and -not $IsAdmin) { $badge = New-Pill 'Needs admin' 'Warn' 'WarnSoft' }
    elseif ($Target.Kind -eq 'recycle') { $badge = New-Pill 'Check it first' 'TextSub' 'Track' }
    if ($badge) {
        $badge.Margin = New-Thick 8 0 0 0
        [void]$titleLine.Children.Add($badge)
    }
    [void]$text.Children.Add($titleLine)
    $desc = New-Text $Target.Desc 12 'TextSub'
    $desc.Margin = New-Thick 0 3 0 0
    [void]$text.Children.Add($desc)
    Add-ToGrid $grid $text 1

    $size = New-Text '' 13.5 'Text' -Bold
    $size.Margin = New-Thick 16 0 6 0
    $size.MinWidth = 80
    $size.TextAlignment = 'Right'
    $size.VerticalAlignment = 'Center'
    Add-ToGrid $grid $size 2

    $check.Content = $grid
    if ($Target.Admin -and -not $IsAdmin) {
        $check.IsChecked = $false
        $check.IsEnabled = $false
    }
    $check.Add_Click({ Update-CleanTotal })

    $row = New-Object System.Windows.Controls.Border
    $row.Style = $app.TryFindResource('Row')
    $row.Child = $check
    $CleanCheck[$Target.Key] = $check
    $CleanSize[$Target.Key] = $size
    return $row
}

function Get-CleanSelectedKeys {
    return @($CleanTargets | Where-Object {
            $check = $CleanCheck[$_.Key]
            $check.IsEnabled -and $check.IsChecked -eq $true
        } | ForEach-Object { $_.Key })
}

function Update-CleanTotal {
    if (-not $script:CleanScanned) { return }
    $selected = 0.0
    $found = 0.0
    foreach ($key in $CleanBytes.Keys) {
        $found += $CleanBytes[$key]
        if ((Get-CleanSelectedKeys) -contains $key) { $selected += $CleanBytes[$key] }
    }
    $ui.CleanTotal.Text = '{0} selected' -f (Format-Size $selected)
    $ui.CleanTotalSub.Text = 'Out of {0} found. Untick anything you want to keep.' -f (Format-Size $found)
    $ui.CleanRunBtn.Visibility = $(if ($selected -ge 1KB) { 'Visible' } else { 'Collapsed' })
}

function Set-CleanHero([string]$Look) {
    if ($Look -eq 'done') {
        Set-Color $ui.CleanHeroTile ([System.Windows.Controls.Border]::BackgroundProperty) 'GoodSoft'
        Set-Color $ui.CleanHeroGlyph ([System.Windows.Controls.TextBlock]::ForegroundProperty) 'Good'
        $ui.CleanHeroGlyph.Text = [string][char]0xE73E
    } else {
        Set-Color $ui.CleanHeroTile ([System.Windows.Controls.Border]::BackgroundProperty) 'AccentSoft'
        Set-Color $ui.CleanHeroGlyph ([System.Windows.Controls.TextBlock]::ForegroundProperty) 'Accent'
        $ui.CleanHeroGlyph.Text = [string][char]0xE74D
    }
}

function Set-CleanBusy([bool]$Busy, [string]$Text = 'Starting...') {
    $hidden = $(if ($Busy) { 'Collapsed' } else { 'Visible' })
    $ui.CleanScanBtn.Visibility = $hidden
    $ui.CleanCancelBtn.Visibility = $(if ($Busy) { 'Visible' } else { 'Collapsed' })
    $ui.CleanProgressBox.Visibility = $(if ($Busy) { 'Visible' } else { 'Collapsed' })
    $ui.CleanList.IsEnabled = -not $Busy
    $ui.CleanSelectAll.IsEnabled = -not $Busy
    if ($Busy) {
        $ui.CleanRunBtn.Visibility = 'Collapsed'
        Reset-ProgressLine $ui.CleanProgress $ui.CleanProgressText $Text
    }
}

function Start-CleanScan([switch]$Quiet) {
    if ($Quiet -and (Test-WorkRunning)) { return }
    Set-CleanHero 'neutral'
    Set-CleanBusy $true 'Scanning...'
    $ui.CleanTotal.Text = 'Scanning...'
    $ui.CleanTotalSub.Text = 'Looking through temporary folders and caches.'
    foreach ($key in @($CleanSize.Keys)) {
        $CleanSize[$key].Text = ''
        Set-Color $CleanSize[$key] ([System.Windows.Controls.TextBlock]::ForegroundProperty) 'Text'
    }
    $started = Start-Work -Script $CleanScanJob -Arguments @(, @(Get-CleanAllowedKeys)) `
        -OnProgress { param($text, $percent) Set-ProgressLine $ui.CleanProgress $ui.CleanProgressText $text $percent } `
        -OnDone { param($out) Show-CleanScan $out[-1] } `
        -OnError {
        param($err)
        Set-CleanBusy $false
        $ui.CleanTotal.Text = 'Scan stopped'
        $ui.CleanTotalSub.Text = $err.Message
    }
    if (-not $started) {
        Set-CleanBusy $false
        $ui.CleanTotal.Text = 'Ready to scan'
    }
}

function Show-CleanScan($Sizes) {
    $script:CleanScanned = $true
    $CleanBytes.Clear()
    foreach ($target in $CleanTargets) {
        if (-not $Sizes.ContainsKey($target.Key)) { continue }
        $bytes = [double]$Sizes[$target.Key]
        $CleanBytes[$target.Key] = $bytes
        $CleanSize[$target.Key].Text = Format-Size $bytes
    }
    Set-CleanBusy $false
    $ui.CleanScanBtn.Content = 'Scan again'
    Update-CleanTotal
    if ($global:Sync.Cancel) { $ui.CleanTotalSub.Text = 'Scan cancelled - sizes may be incomplete.' }
}

function Start-CleanRun {
    $keys = @(Get-CleanSelectedKeys)
    if ($keys.Count -eq 0) { Show-Toast 'Tick at least one item to clean.' 'info'; return }
    $names = ($keys | ForEach-Object { '  -  ' + (Get-CleanTarget $_).Name }) -join "`n"
    $hasBin = $keys -contains 'RecycleBin'
    if ($Settings.ConfirmDelete -or $hasBin) {
        $text = "These will be deleted:`n`n$names"
        if ($hasBin) { $text += "`n`nEmptying the Recycle Bin cannot be undone." }
        $kind = $(if ($hasBin) { 'warn' } else { 'question' })
        if (-not (Confirm-Action 'Clean the selected items?' $text 'Clean now' $kind)) { return }
    }
    Set-CleanBusy $true 'Cleaning...'
    $ui.CleanTotal.Text = 'Cleaning...'
    $ui.CleanTotalSub.Text = 'Files that are in use are skipped automatically.'
    $started = Start-Work -Script $CleanRunJob -Arguments @(, $keys) `
        -OnProgress { param($text, $percent) Set-ProgressLine $ui.CleanProgress $ui.CleanProgressText $text $percent } `
        -OnDone { param($out) Show-CleanResult $out[-1] } `
        -OnError {
        param($err)
        Set-CleanBusy $false
        Show-Toast ('Cleaning stopped: {0}' -f $err.Message) 'error'
    }
    if (-not $started) { Set-CleanBusy $false }
}

function Show-CleanResult($Result) {
    Set-CleanBusy $false
    $skipped = 0
    foreach ($item in @($Result.Items)) {
        $CleanBytes[$item.Key] = 0.0
        $CleanSize[$item.Key].Text = 'Cleaned'
        Set-Color $CleanSize[$item.Key] ([System.Windows.Controls.TextBlock]::ForegroundProperty) 'Good'
        $skipped += $item.Skipped
        Write-Activity ('Cleaner: {0} - freed {1}' -f $item.Name, (Format-Size $item.Freed))
    }
    Set-CleanHero 'done'
    $ui.CleanTotal.Text = '{0} freed' -f (Format-Size $Result.Total)
    if ($skipped -gt 0) {
        $ui.CleanTotalSub.Text = '{0} files were in use and were skipped. Close those apps and clean again to remove them.' -f $skipped
    } else {
        $ui.CleanTotalSub.Text = 'All selected items were cleaned.'
    }
    $ui.CleanRunBtn.Visibility = 'Collapsed'
    Show-Toast ('Freed {0}.' -f (Format-Size $Result.Total)) 'success'
}

Register-Page 'Cleaner' -Init {
    foreach ($target in $CleanTargets) { [void]$ui.CleanList.Children.Add((New-CleanRow $target)) }
    $ui.CleanScanBtn.Add_Click({ Invoke-Guarded { Start-CleanScan } })
    $ui.CleanRunBtn.Add_Click({ Invoke-Guarded { Start-CleanRun } })
    $ui.CleanCancelBtn.Add_Click({ Stop-Work; $ui.CleanProgressText.Text = 'Stopping...' })
    $ui.CleanSelectAll.Add_Click({
            $boxes = @($CleanCheck.Values | Where-Object { $_.IsEnabled })
            $allOn = -not ($boxes | Where-Object { $_.IsChecked -ne $true })
            foreach ($box in $boxes) { $box.IsChecked = -not $allOn }
            $ui.CleanSelectAll.Content = $(if ($allOn) { 'Select all' } else { 'Clear all' })
            Update-CleanTotal
        })
    $ui.CleanDiskCleanupBtn.Add_Click({ Open-Target 'cleanmgr.exe' })
    $ui.CleanStorageSenseBtn.Add_Click({ Open-Target 'ms-settings:storagesense' })
} -Show {
    if (-not $script:CleanScanned) { Start-CleanScan -Quiet }
}
