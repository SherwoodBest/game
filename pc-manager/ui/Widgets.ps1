# Reusable pieces that pages build their lists from.

function New-Button([string]$Content, [scriptblock]$OnClick, $Tag = $null, [string]$Style = '') {
    $button = New-Object System.Windows.Controls.Button
    $button.Content = $Content
    if ($Style) { $button.Style = $app.TryFindResource($Style) }
    $button.Tag = $Tag
    if ($OnClick) { $button.Add_Click($OnClick) }
    return $button
}

# A list row: [icon]  Title / subtitle  ...  [right-hand element]
function New-ListRow {
    param($Icon, [string]$Title, [string]$Subtitle, $Right, [string]$Badge)
    $row = New-Object System.Windows.Controls.Border
    $row.Style = $app.TryFindResource('Row')
    $grid = New-Object System.Windows.Controls.Grid
    Add-Column $grid 'Auto'
    Add-Column $grid '*'
    Add-Column $grid 'Auto'
    if ($Icon) {
        $Icon.Margin = New-Thick 0 0 14 0
        Add-ToGrid $grid $Icon 0
    }
    $text = New-Object System.Windows.Controls.StackPanel
    $text.VerticalAlignment = 'Center'
    $titleLine = New-Object System.Windows.Controls.StackPanel
    $titleLine.Orientation = 'Horizontal'
    [void]$titleLine.Children.Add((New-Text $Title 13.5 'Text' -Bold -Trim))
    if ($Badge) {
        $pill = New-Pill $Badge 'TextSub' 'Track'
        $pill.Margin = New-Thick 8 0 0 0
        [void]$titleLine.Children.Add($pill)
    }
    [void]$text.Children.Add($titleLine)
    if ($Subtitle) {
        $sub = New-Text $Subtitle 12 'TextSub' -Trim
        $sub.Margin = New-Thick 0 3 0 0
        [void]$text.Children.Add($sub)
    }
    Add-ToGrid $grid $text 1
    if ($Right) {
        $Right.Margin = New-Thick 16 0 0 0
        $Right.VerticalAlignment = 'Center'
        Add-ToGrid $grid $Right 2
    }
    $row.Child = $grid
    return $row
}

# "Label      value" pairs for detail cards.
function Add-InfoRow($Panel, [string]$Label, [string]$Value) {
    $grid = New-Object System.Windows.Controls.Grid
    $grid.Margin = New-Thick 0 0 0 10
    Add-Column $grid 120
    Add-Column $grid '*'
    Add-ToGrid $grid (New-Text $Label 12.5 'TextSub') 0
    Add-ToGrid $grid (New-Text $Value 12.5 'Text') 1
    [void]$Panel.Children.Add($grid)
}

# Title, value on the right, and a bar underneath.
function Add-UsageRow($Panel, [string]$Label, [double]$Percent, [string]$Detail, [string]$Color = '') {
    if (-not $Color) { $Color = Get-LevelColor $Percent }
    $box = New-Object System.Windows.Controls.StackPanel
    $box.Margin = New-Thick 0 0 0 16
    $top = New-Object System.Windows.Controls.Grid
    Add-Column $top '*'
    Add-Column $top 'Auto'
    Add-ToGrid $top (New-Text $Label 13 'Text' -Bold) 0
    Add-ToGrid $top (New-Text $Detail 12 'TextSub') 1
    [void]$box.Children.Add($top)
    $bar = New-Bar $Percent $Color 6
    $bar.Margin = New-Thick 0 8 0 0
    [void]$box.Children.Add($bar)
    [void]$Panel.Children.Add($box)
}

# Small clickable card with an icon, title and one line of text.
function New-QuickTile([int]$Glyph, [string]$Title, [string]$Text, [scriptblock]$OnClick, $Tag = $null, [string]$Color = 'Accent', [string]$Soft = 'AccentSoft') {
    $tile = New-Object System.Windows.Controls.Button
    $tile.Style = $app.TryFindResource('Tile')
    $tile.Width = 204
    $tile.Height = 112
    $tile.Tag = $Tag
    $stack = New-Object System.Windows.Controls.StackPanel
    $icon = New-IconTile $Glyph $Color $Soft 34
    $icon.HorizontalAlignment = 'Left'
    [void]$stack.Children.Add($icon)
    $title = New-Text $Title 13.5 'Text' -Bold -Trim
    $title.Margin = New-Thick 0 12 0 2
    [void]$stack.Children.Add($title)
    [void]$stack.Children.Add((New-Text $Text 12 'TextSub' -Trim))
    $tile.Content = $stack
    if ($OnClick) { $tile.Add_Click($OnClick) }
    return $tile
}

# Empty-state message shown in place of a list.
function New-EmptyState([int]$Glyph, [string]$Title, [string]$Text) {
    $stack = New-Object System.Windows.Controls.StackPanel
    $stack.HorizontalAlignment = 'Center'
    $stack.Margin = New-Thick 0 26 0 26
    $icon = New-IconTile $Glyph 'Good' 'GoodSoft' 48
    $icon.HorizontalAlignment = 'Center'
    [void]$stack.Children.Add($icon)
    $titleText = New-Text $Title 15 'Text' -Bold
    $titleText.HorizontalAlignment = 'Center'
    $titleText.Margin = New-Thick 0 14 0 4
    [void]$stack.Children.Add($titleText)
    $body = New-Text $Text 12.5 'TextSub'
    $body.HorizontalAlignment = 'Center'
    $body.TextAlignment = 'Center'
    $body.MaxWidth = 420
    [void]$stack.Children.Add($body)
    return $stack
}

# Shows a determinate progress line: bar + text, used by long scans.
function Set-ProgressLine($Bar, $Label, [string]$Text, [double]$Percent) {
    if ($Text) { $Label.Text = $Text }
    if ($Percent -ge 0) {
        $Bar.BeginAnimation([System.Windows.Controls.Primitives.RangeBase]::ValueProperty, (New-Anim $Bar.Value $Percent 300))
    }
}

# Puts a bar back to zero (an animation would otherwise keep holding its value).
function Reset-ProgressLine($Bar, $Label, [string]$Text = 'Starting...') {
    $Bar.BeginAnimation([System.Windows.Controls.Primitives.RangeBase]::ValueProperty, $null)
    $Bar.Value = 0
    $Label.Text = $Text
}
