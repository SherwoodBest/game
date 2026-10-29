# Settings: theme, confirmations, recent activity, about.

function Update-ActivityList {
    $ui.SetActivity.Children.Clear()
    $recent = @($Activity | Select-Object -First 30)
    if ($recent.Count -eq 0) {
        $empty = New-Text 'Nothing yet. Scans, clean-ups and changes you make will show up here.' 12.5 'TextSub'
        $empty.Margin = New-Thick 10 4 0 8
        [void]$ui.SetActivity.Children.Add($empty)
        return
    }
    foreach ($entry in $recent) {
        $row = New-Object System.Windows.Controls.Border
        $row.Style = $app.TryFindResource('Row')
        $row.Padding = New-Thick 10 7 10 7
        $grid = New-Object System.Windows.Controls.Grid
        Add-Column $grid 110
        Add-Column $grid '*'
        $when = $(if ($entry.Time.Date -eq (Get-Date).Date) { $entry.Time.ToString('HH:mm') } else { $entry.Time.ToString('MM-dd HH:mm') })
        Add-ToGrid $grid (New-Text $when 12.5 'TextMuted') 0
        Add-ToGrid $grid (New-Text $entry.Text 12.5 'Text') 1
        $row.Child = $grid
        [void]$ui.SetActivity.Children.Add($row)
    }
}

Register-Page 'Settings' -Init {
    switch ($Settings.Theme) {
        'Light' { $ui.SetThemeLight.IsChecked = $true }
        'Dark' { $ui.SetThemeDark.IsChecked = $true }
        default { $ui.SetThemeSystem.IsChecked = $true }
    }
    foreach ($radio in @($ui.SetThemeSystem, $ui.SetThemeLight, $ui.SetThemeDark)) {
        $radio.Add_Checked({
                param($s, $e)
                $Settings.Theme = [string]$s.Tag
                Set-Theme $Settings.Theme
                Save-Settings
            })
    }

    $ui.SetConfirm.IsChecked = [bool]$Settings.ConfirmDelete
    $ui.SetConfirm.Add_Click({
            $Settings.ConfirmDelete = ($ui.SetConfirm.IsChecked -eq $true)
            Save-Settings
        })

    $ui.SetOpenLog.Add_Click({
            if (Test-Path -LiteralPath $LogFile) { Open-Target 'notepad.exe' ('"{0}"' -f $LogFile) }
            else { Show-Toast 'There is no activity log yet.' 'info' }
        })
    $ui.SetOpenReports.Add_Click({
            $dir = Join-Path ([Environment]::GetFolderPath('MyDocuments')) 'PC Manager Reports'
            New-Item -ItemType Directory -Path $dir -Force | Out-Null
            Open-Target 'explorer.exe' ('"{0}"' -f $dir)
        })

    $ui.SetShortcutBtn.Add_Click({
            Invoke-Guarded {
                $shell = New-Object -ComObject WScript.Shell
                $link = $shell.CreateShortcut((Join-Path ([Environment]::GetFolderPath('Desktop')) 'PC Manager.lnk'))
                $link.TargetPath = "$env:SystemRoot\System32\WindowsPowerShell\v1.0\powershell.exe"
                $link.Arguments = "-NoProfile -ExecutionPolicy Bypass -STA -WindowStyle Hidden -File `"$AppScript`""
                $link.WorkingDirectory = $AppRoot
                $link.IconLocation = "$env:SystemRoot\System32\shell32.dll,15"
                $link.Description = 'Keep your PC fast, tidy and healthy'
                $link.Save()
                Write-Activity 'Added a desktop shortcut.'
                Show-Toast 'Shortcut added to your desktop.' 'success'
            }
        })

    $ui.SetAdminText.Text = $(if ($IsAdmin) { 'Running with administrator rights - every feature is available.' } else { 'Running in limited mode. Restart as administrator to use every feature.' })
    $ui.SetDataText.Text = 'Settings and activity log are stored in {0}' -f $DataDir
} -Show {
    Update-ActivityList
}
