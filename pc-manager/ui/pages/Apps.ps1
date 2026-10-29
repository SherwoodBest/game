# Installed apps: list, sort, search and uninstall.

$AppsLoadJob = { Get-InstalledApps }

function Start-AppsLoad([switch]$Quiet) {
    if ($Quiet -and (Test-WorkRunning)) { return }
    $ui.AppsSummary.Text = 'Loading apps...'
    $started = Start-Work -Script $AppsLoadJob `
        -OnDone { param($out) $script:AppsData = @($out); $script:AppsLoaded = $true; Show-AppsList } `
        -OnError { param($err) $ui.AppsSummary.Text = 'Could not read the app list'; $ui.AppsSummarySub.Text = $err.Message }
    if (-not $started) { $ui.AppsSummarySub.Text = 'Waiting for another task to finish. Press refresh in a moment.' }
}

function Get-AppsSortKey {
    foreach ($radio in @($ui.AppsSortName, $ui.AppsSortSize, $ui.AppsSortDate)) {
        if ($radio.IsChecked) { return [string]$radio.Tag }
    }
    return 'Name'
}

function Show-AppsList {
    $apps = @($script:AppsData)
    switch (Get-AppsSortKey) {
        'Size' { $apps = @($apps | Sort-Object -Property Size -Descending) }
        'Date' { $apps = @($apps | Sort-Object -Property @{ Expression = { if ($_.Installed) { $_.Installed } else { [datetime]::MinValue } } } -Descending) }
        default { $apps = @($apps | Sort-Object -Property Name) }
    }
    $total = ($apps | Measure-Object -Property Size -Sum).Sum
    $ui.AppsSummary.Text = '{0} apps installed' -f $apps.Count
    $ui.AppsSummarySub.Text = $(if ($total -gt 0) { 'Using about {0}. Uninstall opens the app''s own uninstaller.' -f (Format-Size $total) } else { 'Uninstall opens the app''s own uninstaller.' })

    $ui.AppsList.Children.Clear()
    foreach ($appInfo in $apps) {
        $right = New-Object System.Windows.Controls.StackPanel
        $right.Orientation = 'Horizontal'
        if ($appInfo.Size -gt 0) {
            $size = New-Text (Format-Size $appInfo.Size) 12.5 'TextSub'
            $size.VerticalAlignment = 'Center'
            $size.Margin = New-Thick 0 0 14 0
            [void]$right.Children.Add($size)
        }
        $button = New-Button 'Uninstall' {
            param($s, $e)
            Invoke-Guarded { param($b) Start-AppRemoval $b.Tag } $s
        } $appInfo
        $button.Padding = New-Thick 14 5 14 5
        $button.MinHeight = 30
        [void]$right.Children.Add($button)

        $parts = @()
        if ($appInfo.Publisher) { $parts += $appInfo.Publisher }
        if ($appInfo.Version) { $parts += ('version {0}' -f $appInfo.Version) }
        if ($appInfo.Installed) { $parts += ('installed {0}' -f $appInfo.Installed.ToString('yyyy-MM-dd')) }
        $row = New-ListRow (New-AppIcon $appInfo.Icon 0xE71D 32) $appInfo.Name ($parts -join '  -  ') $right
        $row.Tag = ('{0} {1}' -f $appInfo.Name, $appInfo.Publisher).ToLower()
        [void]$ui.AppsList.Children.Add($row)
    }
    Update-AppsFilter
}

function Update-AppsFilter {
    $query = $ui.AppsSearch.Text.Trim().ToLower()
    foreach ($row in $ui.AppsList.Children) {
        if ($row.Tag -is [string]) {
            $row.Visibility = $(if (-not $query -or $row.Tag.Contains($query)) { 'Visible' } else { 'Collapsed' })
        }
    }
}

function Start-AppRemoval($AppInfo) {
    $text = "The uninstaller for {0} will open. Follow its steps to finish.`n`nWhen it is done, press refresh to update this list." -f $AppInfo.Name
    if (-not (Confirm-Action ('Uninstall {0}?' -f $AppInfo.Name) $text 'Uninstall' 'warn')) { return }
    Start-AppUninstall $AppInfo
    Write-Activity ('Started uninstall: {0}' -f $AppInfo.Name)
    Show-Toast ('Opening the uninstaller for {0}...' -f $AppInfo.Name) 'info'
}

Register-Page 'Apps' -Init {
    $ui.AppsRefresh.Add_Click({ Invoke-Guarded { Start-AppsLoad } })
    $ui.AppsSearch.Add_TextChanged({ Update-AppsFilter })
    foreach ($radio in @($ui.AppsSortName, $ui.AppsSortSize, $ui.AppsSortDate)) {
        $radio.Add_Checked({ if ($script:AppsLoaded) { Invoke-Guarded { Show-AppsList } } })
    }
    $ui.AppsSettingsBtn.Add_Click({ Open-Target 'ms-settings:appsfeatures' })
} -Show {
    if (-not $script:AppsLoaded) { Start-AppsLoad -Quiet }
}
