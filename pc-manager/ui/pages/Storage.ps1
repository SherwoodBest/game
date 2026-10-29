# Storage: drive usage and a large-file finder.

$LargeFindJob = { param([double]$MinBytes) Find-LargeFiles $MinBytes 300 }

function Update-StorageDrives {
    $ui.StorageDrives.Children.Clear()
    foreach ($drive in @(Get-DriveUsage)) {
        if ($drive.Total -le 0) { continue }
        $usedPct = ($drive.Total - $drive.Free) * 100 / $drive.Total
        $card = New-Object System.Windows.Controls.Border
        $card.Style = $app.TryFindResource('Card')
        $card.Width = 318
        $card.Margin = New-Thick 0 0 16 16
        $grid = New-Object System.Windows.Controls.Grid
        Add-Column $grid 'Auto'
        Add-Column $grid '*'
        $icon = New-IconTile 0xEDA2 (Get-LevelColor $usedPct) $(if ($usedPct -ge 90) { 'BadSoft' } elseif ($usedPct -ge 75) { 'WarnSoft' } else { 'AccentSoft' }) 40
        $icon.Margin = New-Thick 0 0 14 0
        $icon.VerticalAlignment = 'Top'
        Add-ToGrid $grid $icon 0
        $text = New-Object System.Windows.Controls.StackPanel
        $title = '{0} ({1})' -f $drive.Label, $drive.Name
        if ($drive.System) { $title += ' - Windows' }
        [void]$text.Children.Add((New-Text $title 13.5 'Text' -Bold -Trim))
        $sub = New-Text ('{0} free of {1}' -f (Format-Size $drive.Free), (Format-Size $drive.Total)) 12 'TextSub'
        $sub.Margin = New-Thick 0 3 0 10
        [void]$text.Children.Add($sub)
        [void]$text.Children.Add((New-Bar $usedPct (Get-LevelColor $usedPct) 6))
        Add-ToGrid $grid $text 1
        $card.Child = $grid
        [void]$ui.StorageDrives.Children.Add($card)
    }
}

function Get-LargeThreshold {
    foreach ($radio in @($ui.LargeSize100, $ui.LargeSize500, $ui.LargeSize1000)) {
        if ($radio.IsChecked) { return [double]$radio.Tag }
    }
    return [double]500MB
}

function Set-LargeBusy([bool]$Busy) {
    $ui.LargeFindBtn.Visibility = $(if ($Busy) { 'Collapsed' } else { 'Visible' })
    $ui.LargeCancelBtn.Visibility = $(if ($Busy) { 'Visible' } else { 'Collapsed' })
    $ui.LargeProgressBox.Visibility = $(if ($Busy) { 'Visible' } else { 'Collapsed' })
    if ($Busy) { Reset-ProgressLine $ui.LargeProgress $ui.LargeProgressText 'Starting...' }
}

function Start-LargeFind {
    Set-LargeBusy $true
    $ui.LargeList.Children.Clear()
    $ui.LargeSummary.Visibility = 'Collapsed'
    $started = Start-Work -Script $LargeFindJob -Arguments @(Get-LargeThreshold) `
        -OnProgress { param($text, $percent) Set-ProgressLine $ui.LargeProgress $ui.LargeProgressText $text $percent } `
        -OnDone { param($out) Show-LargeFiles @($out) } `
        -OnError { param($err) Set-LargeBusy $false; Show-Toast ('The search stopped: {0}' -f $err.Message) 'error' }
    if (-not $started) { Set-LargeBusy $false }
}

function Show-LargeFiles($Files) {
    Set-LargeBusy $false
    $ui.LargeList.Children.Clear()
    $script:LargeFiles = New-Object System.Collections.Generic.List[object]
    foreach ($file in $Files) { $script:LargeFiles.Add($file) }
    if ($script:LargeFiles.Count -eq 0) {
        $ui.LargeSummary.Visibility = 'Collapsed'
        [void]$ui.LargeList.Children.Add((New-EmptyState 0xE73E 'No large files found' 'Nothing in your folders is over the size you picked. Try a smaller size.'))
        return
    }
    Update-LargeSummary
    foreach ($file in $script:LargeFiles) {
        $show = New-Button ([string][char]0xE838) {
            param($s, $e)
            Invoke-Guarded { param($b) Start-Process -FilePath 'explorer.exe' -ArgumentList ('/select,"{0}"' -f $b.Tag.FullName) } $s
        } $file 'Btn.Icon'
        $show.ToolTip = 'Show in folder'
        $delete = New-Button ([string][char]0xE74D) {
            param($s, $e)
            Invoke-Guarded { param($b) Remove-LargeFile $b } $s
        } $null 'Btn.Icon'
        $delete.ToolTip = 'Move to Recycle Bin'

        $right = New-Object System.Windows.Controls.StackPanel
        $right.Orientation = 'Horizontal'
        $size = New-Text (Format-Size $file.Size) 13.5 'Text' -Bold
        $size.VerticalAlignment = 'Center'
        $size.Margin = New-Thick 0 0 12 0
        [void]$right.Children.Add($size)
        [void]$right.Children.Add($show)
        [void]$right.Children.Add($delete)

        $subtitle = '{0}  -  {1}' -f $file.Folder, $file.Modified.ToString('d MMM yyyy')
        $row = New-ListRow (New-AppIcon $file.FullName 0xE8A5 32) $file.Name $subtitle $right
        $delete.Tag = @{ File = $file; Row = $row }
        [void]$ui.LargeList.Children.Add($row)
    }
}

function Update-LargeSummary {
    $total = ($script:LargeFiles | Measure-Object -Property Size -Sum).Sum
    $count = $script:LargeFiles.Count
    $ui.LargeSummary.Text = '{0} {1}, using {2} in total' -f $count, $(if ($count -eq 1) { 'file' } else { 'files' }), (Format-Size $total)
    $ui.LargeSummary.Visibility = 'Visible'
}

function Remove-LargeFile($Button) {
    $file = $Button.Tag.File
    $row = $Button.Tag.Row
    $text = "{0}`n{1}`n`nIt goes to the Recycle Bin, so you can still restore it." -f $file.Name, (Format-Size $file.Size)
    if (-not (Confirm-Action 'Move this file to the Recycle Bin?' $text 'Move to Recycle Bin' 'warn')) { return }
    [Microsoft.VisualBasic.FileIO.FileSystem]::DeleteFile($file.FullName, 'OnlyErrorDialogs', 'SendToRecycleBin')
    if (Test-Path -LiteralPath $file.FullName) {
        Show-Toast 'The file is still there. It may be open in another app.' 'warn'
        return
    }
    for ($i = $script:LargeFiles.Count - 1; $i -ge 0; $i--) {
        if ($script:LargeFiles[$i].FullName -eq $file.FullName) { $script:LargeFiles.RemoveAt($i) }
    }
    $fade = New-Anim 1 0 200
    $fade.Add_Completed({ Remove-FadedRows })
    $row.Tag = 'removed'
    $row.BeginAnimation([System.Windows.UIElement]::OpacityProperty, $fade)
    Write-Activity ('Moved to Recycle Bin: {0} ({1})' -f $file.FullName, (Format-Size $file.Size))
    Show-Toast ('Moved {0} to the Recycle Bin.' -f $file.Name) 'success'
    if ($script:LargeFiles.Count -gt 0) { Update-LargeSummary } else { $ui.LargeSummary.Text = 'All gone. Nice and tidy.' }
    Update-StorageDrives
}

function Remove-FadedRows {
    foreach ($child in @($ui.LargeList.Children)) {
        if ($child.Tag -eq 'removed') { [void]$ui.LargeList.Children.Remove($child) }
    }
}

Register-Page 'Storage' -Init {
    $ui.LargeFindBtn.Add_Click({ Invoke-Guarded { Start-LargeFind } })
    $ui.LargeCancelBtn.Add_Click({ Stop-Work; $ui.LargeProgressText.Text = 'Stopping...' })
    $ui.StorageDownloadsBtn.Add_Click({ Open-Target 'explorer.exe' 'shell:Downloads' })
    $ui.StorageRecycleBtn.Add_Click({ Open-Target 'explorer.exe' 'shell:RecycleBinFolder' })
    $ui.StorageSettingsBtn.Add_Click({ Open-Target 'ms-settings:storagesense' })
    $ui.StorageCleanupBtn.Add_Click({ Open-Target 'cleanmgr.exe' })
} -Show {
    Update-StorageDrives
}
