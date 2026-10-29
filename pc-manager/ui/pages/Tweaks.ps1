# Tweaks: grouped switches, each showing its current state and a suggestion.

$TweakGroupInfo = [ordered]@{
    'Performance'        = @{ Glyph = 0xE945; Text = 'Make Windows feel quicker' }
    'Gaming'             = @{ Glyph = 0xE7FC; Text = 'Smoother games' }
    'Battery'            = @{ Glyph = 0xE83F; Text = 'Longer battery life' }
    'Fewer distractions' = @{ Glyph = 0xE708; Text = 'Less nagging from Windows' }
    'Storage'            = @{ Glyph = 0xEDA2; Text = 'Keep space free automatically' }
}

function Get-TweakState($Tweak) {
    try { return [bool](& $Tweak.Get) } catch { return $null }
}

function New-TweakRow($Tweak) {
    $row = New-Object System.Windows.Controls.Border
    $row.Style = $app.TryFindResource('Row')
    $row.Padding = New-Thick 14 12 14 12
    $grid = New-Object System.Windows.Controls.Grid
    Add-Column $grid '*'
    Add-Column $grid 'Auto'

    $text = New-Object System.Windows.Controls.StackPanel
    $text.VerticalAlignment = 'Center'
    $titleLine = New-Object System.Windows.Controls.WrapPanel
    [void]$titleLine.Children.Add((New-Text $Tweak.Name 13.5 'Text' -Bold))
    $pills = @()
    if ($Tweak.Suggest -eq $true) { $pills += , @('Suggested: on', 'Good', 'GoodSoft') }
    elseif ($Tweak.Suggest -eq $false) { $pills += , @('Suggested: off', 'Good', 'GoodSoft') }
    else { $pills += , @('Your choice', 'TextSub', 'Track') }
    if ($Tweak.Restart) { $pills += , @('Needs restart', 'TextSub', 'Track') }
    elseif ($Tweak.SignOut) { $pills += , @('Full effect after sign-out', 'TextSub', 'Track') }
    if ($Tweak.Admin -and -not $IsAdmin) { $pills += , @('Needs admin', 'Warn', 'WarnSoft') }
    foreach ($p in $pills) {
        $pill = New-Pill $p[0] $p[1] $p[2]
        $pill.Margin = New-Thick 8 0 0 0
        [void]$titleLine.Children.Add($pill)
    }
    [void]$text.Children.Add($titleLine)
    $desc = New-Text $Tweak.Desc 12 'TextSub'
    $desc.Margin = New-Thick 0 4 24 0
    [void]$text.Children.Add($desc)
    Add-ToGrid $grid $text 0

    $toggle = New-Object System.Windows.Controls.CheckBox
    $toggle.Style = $app.TryFindResource('Toggle')
    $toggle.VerticalAlignment = 'Center'
    $toggle.Tag = $Tweak
    $state = Get-TweakState $Tweak
    $toggle.IsChecked = ($state -eq $true)
    if ($null -eq $state -or ($Tweak.Admin -and -not $IsAdmin)) { $toggle.IsEnabled = $false }
    $toggle.Add_Click({
            param($s, $e)
            Invoke-Guarded { param($box) Set-TweakFromToggle $box } $s
        })
    Add-ToGrid $grid $toggle 1
    $row.Child = $grid
    $script:TweakToggles += , $toggle
    return $row
}

function Update-Tweaks {
    $ui.TweakGroups.Children.Clear()
    $script:TweakToggles = @()
    foreach ($groupName in $TweakGroupInfo.Keys) {
        $members = @($Tweaks | Where-Object { $_.Group -eq $groupName })
        if ($members.Count -eq 0) { continue }
        $info = $TweakGroupInfo[$groupName]

        $header = New-Object System.Windows.Controls.StackPanel
        $header.Orientation = 'Horizontal'
        $header.Margin = New-Thick 2 4 0 10
        $icon = New-IconTile $info.Glyph 'Accent' 'AccentSoft' 28
        $icon.Margin = New-Thick 0 0 10 0
        [void]$header.Children.Add($icon)
        $name = New-Text $groupName 15 'Text' -Bold
        $name.VerticalAlignment = 'Center'
        [void]$header.Children.Add($name)
        $hint = New-Text ('  -  {0}' -f $info.Text) 12.5 'TextSub'
        $hint.VerticalAlignment = 'Center'
        [void]$header.Children.Add($hint)
        [void]$ui.TweakGroups.Children.Add($header)

        $card = New-Object System.Windows.Controls.Border
        $card.Style = $app.TryFindResource('CardStyle')
        $card.Padding = New-Thick 6 6 6 6
        $list = New-Object System.Windows.Controls.StackPanel
        foreach ($tweak in $members) { [void]$list.Children.Add((New-TweakRow $tweak)) }
        $card.Child = $list
        [void]$ui.TweakGroups.Children.Add($card)
    }
}

function Set-TweakFromToggle($Box) {
    $tweak = $Box.Tag
    $on = ($Box.IsChecked -eq $true)
    try {
        & $tweak.Set $on
    } catch {
        $Box.IsChecked = -not $on
        throw
    }
    $state = $(if ($on) { 'on' } else { 'off' })
    Write-Activity ('Tweak: {0} turned {1}' -f $tweak.Name, $state)
    $message = '{0} turned {1}.' -f $tweak.Name, $state
    if ($tweak.Restart) { $message += ' Restart to apply it.' }
    elseif ($tweak.SignOut) { $message += ' Sign out and back in for the full effect.' }
    Show-Toast $message 'success'
}

function Invoke-SuggestedTweaks {
    $changes = @()
    foreach ($toggle in $script:TweakToggles) {
        $tweak = $toggle.Tag
        if ($null -eq $tweak.Suggest -or -not $toggle.IsEnabled) { continue }
        if (($toggle.IsChecked -eq $true) -ne $tweak.Suggest) { $changes += , $toggle }
    }
    if ($changes.Count -eq 0) {
        Show-Toast 'Everything already matches the suggestions.' 'success'
        return
    }
    $list = ($changes | ForEach-Object {
            '  -  {0}: turn {1}' -f $_.Tag.Name, $(if ($_.Tag.Suggest) { 'on' } else { 'off' })
        }) -join "`n"
    if (-not (Confirm-Action 'Apply suggested settings?' "These will change:`n`n$list`n`nYou can switch any of them back afterwards." 'Apply')) { return }
    $done = 0
    foreach ($toggle in $changes) {
        try {
            & $toggle.Tag.Set ([bool]$toggle.Tag.Suggest)
            $toggle.IsChecked = [bool]$toggle.Tag.Suggest
            Write-Activity ('Tweak: {0} set to suggested ({1})' -f $toggle.Tag.Name, $(if ($toggle.Tag.Suggest) { 'on' } else { 'off' }))
            $done++
        } catch {
            Write-Activity ('Tweak failed: {0} - {1}' -f $toggle.Tag.Name, $_.Exception.Message)
        }
    }
    Show-Toast ('Applied {0} suggested {1}. Some need a restart or sign-out.' -f $done, $(if ($done -eq 1) { 'setting' } else { 'settings' })) 'success'
}

Register-Page 'Tweaks' -Init {
    $ui.TweaksRefresh.Add_Click({ Invoke-Guarded { Update-Tweaks } })
    $ui.TweaksApplyBtn.Add_Click({ Invoke-Guarded { Invoke-SuggestedTweaks } })
    $ui.TweaksVisualBtn.Add_Click({ Open-Target 'SystemPropertiesPerformance.exe' })
} -Show {
    if (-not $script:TweaksShown) {
        $script:TweaksShown = $true
        Update-Tweaks
    }
}
