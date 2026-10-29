# Startup apps: one switch per app, with icon, publisher and search.

function Update-StartupList {
    $ui.StartupList.Children.Clear()
    $items = @(Get-StartupItems | Sort-Object -Property Name)
    if ($items.Count -eq 0) {
        [void]$ui.StartupList.Children.Add((New-EmptyState 0xE73E 'No startup apps' 'Nothing starts by itself when you sign in. Nice and lean.'))
        Update-StartupSummary
        return
    }
    foreach ($item in $items) {
        $toggle = New-Object System.Windows.Controls.CheckBox
        $toggle.Style = $app.TryFindResource('Toggle')
        $toggle.IsChecked = $item.Enabled
        $toggle.Tag = $item
        $badge = $null
        if ($item.Admin -and -not $IsAdmin) {
            $toggle.IsEnabled = $false
            $badge = 'Needs admin'
        }
        $toggle.Add_Click({
                param($s, $e)
                Invoke-Guarded { param($box) Set-StartupFromToggle $box } $s
            })
        $subtitle = '{0}  -  {1}' -f $item.Publisher, $item.Source
        $row = New-ListRow (New-AppIcon $item.ExePath 0xE7E8 32) $item.Name $subtitle $toggle $badge
        $row.ToolTip = $item.Command
        $row.Tag = ('{0} {1} {2}' -f $item.Name, $item.Publisher, $item.Command).ToLower()
        [void]$ui.StartupList.Children.Add($row)
    }
    Update-StartupSummary
    Update-StartupFilter
}

function Get-StartupToggles {
    foreach ($row in $ui.StartupList.Children) {
        if ($row -is [System.Windows.Controls.Border] -and $row.Child -is [System.Windows.Controls.Grid]) {
            foreach ($child in $row.Child.Children) {
                if ($child -is [System.Windows.Controls.CheckBox]) { $child }
            }
        }
    }
}

function Update-StartupSummary {
    $toggles = @(Get-StartupToggles)
    $on = @($toggles | Where-Object { $_.IsChecked -eq $true }).Count
    if ($toggles.Count -eq 0) {
        $ui.StartupSummary.Text = 'No startup apps'
        return
    }
    $ui.StartupSummary.Text = '{0} of {1} apps start automatically' -f $on, $toggles.Count
    if ($on -ge 8) {
        $ui.StartupSummarySub.Text = 'That is quite a few. Turning some off makes Windows ready sooner after you sign in.'
    } else {
        $ui.StartupSummarySub.Text = 'Fewer startup apps means Windows is ready sooner after you sign in.'
    }
}

function Update-StartupFilter {
    $query = $ui.StartupSearch.Text.Trim().ToLower()
    foreach ($row in $ui.StartupList.Children) {
        if ($row.Tag -is [string]) {
            $row.Visibility = $(if (-not $query -or $row.Tag.Contains($query)) { 'Visible' } else { 'Collapsed' })
        }
    }
}

function Set-StartupFromToggle($Box) {
    $item = $Box.Tag
    $enable = ($Box.IsChecked -eq $true)
    try {
        Set-StartupEnabled $item $enable
    } catch {
        $Box.IsChecked = -not $enable
        throw
    }
    $item.Enabled = $enable
    if ($enable) {
        Write-Activity ('Startup: {0} turned on' -f $item.Name)
        Show-Toast ('{0} will start with Windows.' -f $item.Name) 'success'
    } else {
        Write-Activity ('Startup: {0} turned off' -f $item.Name)
        Show-Toast ('{0} will no longer start with Windows.' -f $item.Name) 'success'
    }
    Update-StartupSummary
}

Register-Page 'Startup' -Init {
    $ui.StartupRefresh.Add_Click({ Invoke-Guarded { Update-StartupList } })
    $ui.StartupSearch.Add_TextChanged({ Update-StartupFilter })
    $ui.StartupSettingsBtn.Add_Click({ Open-Target 'ms-settings:startupapps' })
    $ui.StartupTaskMgrBtn.Add_Click({ Open-Target 'taskmgr.exe' })
} -Show {
    Update-StartupList
}
