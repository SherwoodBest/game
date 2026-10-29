# Power and battery: plans as cards, battery health ring, reports.

$BatteryReportJob = {
    param([string]$Out)
    & powercfg.exe /batteryreport /output $Out | Out-Null
    Test-Path -LiteralPath $Out
}

function Update-PowerPlans {
    $ui.PowerPlans.Children.Clear()
    $plans = @(Get-PowerPlans)
    if ($plans.Count -eq 0) {
        [void]$ui.PowerPlans.Children.Add((New-Text 'Could not read the power plans on this PC.' 12.5 'TextSub'))
        return
    }
    foreach ($plan in $plans) {
        $radio = New-Object System.Windows.Controls.RadioButton
        $radio.Style = $app.TryFindResource('OptionCard')
        $radio.GroupName = 'PowerPlans'
        $radio.IsChecked = $plan.Active
        $radio.Tag = $plan
        $grid = New-Object System.Windows.Controls.Grid
        Add-Column $grid 'Auto'
        Add-Column $grid '*'
        $icon = New-IconTile $plan.Glyph 'Accent' 'AccentSoft' 36
        $icon.Margin = New-Thick 0 0 14 0
        Add-ToGrid $grid $icon 0
        $text = New-Object System.Windows.Controls.StackPanel
        $text.VerticalAlignment = 'Center'
        [void]$text.Children.Add((New-Text $plan.Name 13.5 'Text' -Bold))
        $note = New-Text $plan.Note 12 'TextSub'
        $note.Margin = New-Thick 0 2 0 0
        [void]$text.Children.Add($note)
        Add-ToGrid $grid $text 1
        $radio.Content = $grid
        $radio.Add_Click({
                param($s, $e)
                Invoke-Guarded {
                    param($r)
                    if ($r.Tag.Active) { return }
                    try {
                        Set-PowerPlan $r.Tag.Guid
                        Write-Activity ('Power plan: {0}' -f $r.Tag.Name)
                        Show-Toast ('Power plan set to {0}.' -f $r.Tag.Name) 'success'
                    } finally {
                        Update-PowerPlans
                    }
                } $s
            })
        [void]$ui.PowerPlans.Children.Add($radio)
    }
}

function Update-Battery {
    $ui.BatteryInfo.Children.Clear()
    $battery = Get-BatteryInfo
    if (-not $battery) {
        $ui.BatteryRingBox.Visibility = 'Collapsed'
        $ui.BatteryNote.Text = 'No battery found. This looks like a desktop PC, so there is nothing to check here.'
        $ui.BatteryReportBtn.IsEnabled = $false
        return
    }
    $charge = '{0}%  -  {1}' -f $battery.Charge, $(if ($battery.Plugged) { 'plugged in' } else { 'on battery' })
    Add-InfoRow $ui.BatteryInfo 'Charge' $charge
    if ($battery.Health) {
        $ui.BatteryRingLabel.Text = 'Battery health'
        $color = 'Good'
        if ($battery.Health -lt 80) { $color = 'Warn' }
        if ($battery.Health -lt 60) { $color = 'Bad' }
        Set-Color $ui.BatteryRing ([System.Windows.Shapes.Shape]::StrokeProperty) $color
        Start-RingFill $ui.BatteryRing $battery.Health $ui.BatteryRingValue
        Add-InfoRow $ui.BatteryInfo 'Capacity now' ('{0:N0} mWh' -f $battery.Full)
        Add-InfoRow $ui.BatteryInfo 'When new' ('{0:N0} mWh' -f $battery.Design)
        if ($battery.Cycles) { Add-InfoRow $ui.BatteryInfo 'Charge cycles' ('{0:N0}' -f $battery.Cycles) }
        if ($battery.Health -ge 80) {
            $ui.BatteryNote.Text = 'Your battery is in good condition.'
        } elseif ($battery.Health -ge 60) {
            $ui.BatteryNote.Text = 'Your battery has worn a little, which is normal over time. It just runs out sooner than when new.'
        } else {
            $ui.BatteryNote.Text = 'Your battery has worn a lot. A replacement would bring back much longer battery life.'
        }
    } else {
        $ui.BatteryRingLabel.Text = 'Charge'
        Set-Color $ui.BatteryRing ([System.Windows.Shapes.Shape]::StrokeProperty) 'Accent'
        Start-RingFill $ui.BatteryRing $battery.Charge $ui.BatteryRingValue
        $ui.BatteryNote.Text = 'Health details are not available here. The battery report has the full history.'
    }
}

function New-BatteryReport {
    $out = New-ReportPath 'battery-report'
    $ui.BatteryReportBtn.IsEnabled = $false
    $ui.BatteryReportBtn.Content = 'Creating report...'
    $started = Start-Work -Script $BatteryReportJob -Arguments @($out) `
        -OnDone {
        param($result)
        $ui.BatteryReportBtn.IsEnabled = $true
        $ui.BatteryReportBtn.Content = 'Battery report'
        if ($result[-1] -eq $true) {
            Write-Activity ('Battery report saved: {0}' -f $script:LastReport)
            Open-Target $script:LastReport
        } else {
            Show-Toast 'Windows could not create a battery report on this PC.' 'warn'
        }
    } `
        -OnError {
        param($err)
        $ui.BatteryReportBtn.IsEnabled = $true
        $ui.BatteryReportBtn.Content = 'Battery report'
        Show-Toast $err.Message 'error'
    }
    if ($started) {
        $script:LastReport = $out
    } else {
        $ui.BatteryReportBtn.IsEnabled = $true
        $ui.BatteryReportBtn.Content = 'Battery report'
    }
}

function Start-EnergyCheck {
    if (-not (Assert-Admin 'The energy check')) { return }
    $out = New-ReportPath 'energy-report'
    $command = @'
Write-Host '  Watching your laptop for 60 seconds. Leave it idle for the most useful result...'
Write-Host ''
powercfg.exe /energy /output "{OUT}" | Out-Host
if (Test-Path -LiteralPath "{OUT}") { Start-Process "{OUT}" }
'@
    Start-ToolWindow 'Energy check' ($command.Replace('{OUT}', $out))
}

Register-Page 'Power' -Init {
    $ui.PowerModeBtn.Add_Click({ Open-Target 'ms-settings:powersleep' })
    $ui.PowerAddPlanBtn.Add_Click({
            Invoke-Guarded {
                switch (Add-HighPerformancePlan) {
                    'exists' { Show-Toast 'A High performance plan is already in the list.' 'info' }
                    'unsupported' { Show-Toast 'This laptop does not offer a High performance plan. Use Power mode instead.' 'warn' }
                    'added' {
                        Write-Activity 'Added the High performance power plan.'
                        Show-Toast 'High performance plan added. Pick it in the list to use it.' 'success'
                        Update-PowerPlans
                    }
                }
            }
        })
    $ui.BatteryReportBtn.Add_Click({ Invoke-Guarded { New-BatteryReport } })
    $ui.EnergyReportBtn.Add_Click({ Invoke-Guarded { Start-EnergyCheck } })
} -Show {
    Update-PowerPlans
    if (-not $script:BatteryShown) {
        $script:BatteryShown = $true
        Update-Battery
    }
}
