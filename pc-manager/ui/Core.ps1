# Window plumbing: theme, page loading, dialogs, notifications, background work.

$XamlNs = 'http://schemas.microsoft.com/winfx/2006/xaml'
$IconFont = New-Object System.Windows.Media.FontFamily('Segoe Fluent Icons, Segoe MDL2 Assets')
$ui = @{}

# --- Theme -------------------------------------------------------------------

$Palettes = @{
    Light = @{
        Bg = '#F3F5F9'; Card = '#FFFFFF'; CardHover = '#FAFBFD'; Border = '#E4E8EF'
        Text = '#1A1E26'; TextSub = '#596272'; TextMuted = '#8D96A5'
        Accent = '#2F6BEA'; AccentHover = '#285FD6'; AccentPressed = '#2253BD'; AccentSoft = '#E8EFFD'; AccentText = '#FFFFFF'
        Good = '#15995A'; GoodSoft = '#E2F4E9'; Warn = '#BF7300'; WarnSoft = '#FCF0DA'; Bad = '#D13A3A'; BadSoft = '#FBE7E7'
        Control = '#FFFFFF'; ControlHover = '#F3F5F9'; ControlPressed = '#E8EBF1'; ControlBorder = '#D7DCE5'
        Track = '#E6E9EF'; Overlay = '#590B1220'; Input = '#FFFFFF'
        ToggleOff = '#FFFFFF'; ToggleBorder = '#8D96A5'; ToggleKnob = '#596272'
        Divider = '#ECEEF3'; NavHover = '#E8EBF2'; NavSelected = '#E2E7F1'; RowHover = '#F5F7FA'
        ScrollThumb = '#C3C9D3'; ToastBg = '#222833'; ToastText = '#FFFFFF'
    }
    Dark  = @{
        Bg = '#191B20'; Card = '#23262D'; CardHover = '#282C34'; Border = '#30343C'
        Text = '#EEF1F5'; TextSub = '#AEB5C1'; TextMuted = '#828A97'
        Accent = '#6393FF'; AccentHover = '#76A0FF'; AccentPressed = '#5283F0'; AccentSoft = '#26324D'; AccentText = '#0D1424'
        Good = '#47C982'; GoodSoft = '#1B3326'; Warn = '#F2AA3C'; WarnSoft = '#392D17'; Bad = '#FF6E6E'; BadSoft = '#3E2226'
        Control = '#2A2E36'; ControlHover = '#323741'; ControlPressed = '#393F4A'; ControlBorder = '#3B414C'
        Track = '#343944'; Overlay = '#99000000'; Input = '#1E2127'
        ToggleOff = '#1E2127'; ToggleBorder = '#828A97'; ToggleKnob = '#AEB5C1'
        Divider = '#2B2F37'; NavHover = '#22252B'; NavSelected = '#2A2E36'; RowHover = '#2A2E35'
        ScrollThumb = '#4A505B'; ToastBg = '#3A404C'; ToastText = '#FFFFFF'
    }
}

function Test-WindowsDarkMode {
    return ((Get-RegValue 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize' 'AppsUseLightTheme') -eq 0)
}

function Set-Theme([string]$Mode) {
    $dark = ($Mode -eq 'Dark') -or ($Mode -eq 'System' -and (Test-WindowsDarkMode))
    $palette = if ($dark) { $Palettes.Dark } else { $Palettes.Light }
    $converter = New-Object System.Windows.Media.BrushConverter
    foreach ($key in $palette.Keys) {
        $brush = $converter.ConvertFromString($palette[$key])
        $brush.Freeze()
        $app.Resources[$key] = $brush
    }
    $script:IsDark = $dark
}

# --- Loading XAML --------------------------------------------------------------

# The deepest message usually names the real cause.
function Get-InnerMessage($Exception) {
    $messages = @()
    while ($Exception) {
        if ($Exception.Message -and $messages -notcontains $Exception.Message) { $messages += $Exception.Message }
        $Exception = $Exception.InnerException
    }
    return ($messages -join "`n")
}

function Import-Xaml([string]$Path) {
    $text = Get-Content -LiteralPath $Path -Raw -Encoding UTF8
    [xml]$doc = $text
    # Parse (not Load) so that any error names the line it happened on.
    try {
        $root = [Windows.Markup.XamlReader]::Parse($text)
    } catch {
        throw ('{0}: {1}' -f (Split-Path -Leaf $Path), (Get-InnerMessage $_.Exception))
    }
    $ns = New-Object System.Xml.XmlNamespaceManager $doc.NameTable
    $ns.AddNamespace('x', $XamlNs)
    foreach ($node in $doc.SelectNodes('//*[@x:Name]', $ns)) {
        $name = $node.GetAttribute('Name', $XamlNs)
        $element = $root.FindName($name)
        if ($null -ne $element) { $ui[$name] = $element }
    }
    return $root
}

# --- Small builders (colors are theme keys, so they follow light/dark) --------

function New-Thick([double]$Left, [double]$Top, [double]$Right, [double]$Bottom) {
    return New-Object System.Windows.Thickness -ArgumentList $Left, $Top, $Right, $Bottom
}

function Set-Color($Element, $Property, [string]$Key) {
    $Element.SetResourceReference($Property, $Key)
}

function New-Text {
    param([string]$Text, [double]$Size = 13, [string]$Color = 'Text', [switch]$Bold, [switch]$Trim)
    $tb = New-Object System.Windows.Controls.TextBlock
    $tb.Text = $Text
    $tb.FontSize = $Size
    if ($Trim) { $tb.TextTrimming = 'CharacterEllipsis' } else { $tb.TextWrapping = 'Wrap' }
    if ($Bold) { $tb.FontWeight = [System.Windows.FontWeights]::SemiBold }
    Set-Color $tb ([System.Windows.Controls.TextBlock]::ForegroundProperty) $Color
    return $tb
}

function New-Glyph([int]$Code, [double]$Size = 16, [string]$Color = 'Text') {
    $tb = New-Object System.Windows.Controls.TextBlock
    $tb.Text = [string][char]$Code
    $tb.FontFamily = $IconFont
    $tb.FontSize = $Size
    $tb.VerticalAlignment = 'Center'
    $tb.HorizontalAlignment = 'Center'
    Set-Color $tb ([System.Windows.Controls.TextBlock]::ForegroundProperty) $Color
    return $tb
}

function New-IconTile([int]$Code, [string]$Color = 'Accent', [string]$Soft = 'AccentSoft', [double]$Size = 36) {
    $tile = New-Object System.Windows.Controls.Border
    $tile.Width = $Size
    $tile.Height = $Size
    $tile.CornerRadius = New-Object System.Windows.CornerRadius -ArgumentList ($Size / 4.5)
    $tile.VerticalAlignment = 'Center'
    Set-Color $tile ([System.Windows.Controls.Border]::BackgroundProperty) $Soft
    $tile.Child = New-Glyph $Code ($Size * 0.45) $Color
    return $tile
}

function New-Pill([string]$Text, [string]$Color = 'Accent', [string]$Soft = 'AccentSoft') {
    $pill = New-Object System.Windows.Controls.Border
    $pill.CornerRadius = New-Object System.Windows.CornerRadius -ArgumentList 10
    $pill.Padding = New-Thick 9 2 9 2
    $pill.VerticalAlignment = 'Center'
    Set-Color $pill ([System.Windows.Controls.Border]::BackgroundProperty) $Soft
    $pill.Child = New-Text $Text 11 $Color -Bold
    return $pill
}

function New-Bar([double]$Percent, [string]$Color = 'Accent', [double]$Height = 6) {
    $bar = New-Object System.Windows.Controls.ProgressBar
    $bar.Style = $app.TryFindResource('Bar')
    $bar.Height = $Height
    $bar.Value = [math]::Max(0, [math]::Min(100, $Percent))
    Set-Color $bar ([System.Windows.Controls.Control]::ForegroundProperty) $Color
    return $bar
}

function Get-LevelColor([double]$UsedPercent) {
    if ($UsedPercent -ge 90) { return 'Bad' }
    if ($UsedPercent -ge 75) { return 'Warn' }
    return 'Accent'
}

function Add-Column($Grid, $Width) {
    $col = New-Object System.Windows.Controls.ColumnDefinition
    $text = [string]$Width
    if ($text -eq '*') {
        $col.Width = New-Object System.Windows.GridLength -ArgumentList 1, ([System.Windows.GridUnitType]::Star)
    } elseif ($text -eq 'Auto') {
        $col.Width = [System.Windows.GridLength]::Auto
    } else {
        $col.Width = New-Object System.Windows.GridLength -ArgumentList ([double]$Width)
    }
    $Grid.ColumnDefinitions.Add($col)
}

function Add-ToGrid($Grid, $Element, [int]$Column) {
    [System.Windows.Controls.Grid]::SetColumn($Element, $Column)
    [void]$Grid.Children.Add($Element)
}

# --- Icons from programs --------------------------------------------------------

$IconCache = @{}
function Get-FileIcon([string]$Path) {
    if (-not $Path) { return $null }
    if ($IconCache.ContainsKey($Path)) { return $IconCache[$Path] }
    $source = $null
    try {
        $icon = [System.Drawing.Icon]::ExtractAssociatedIcon($Path)
        if ($icon) {
            $source = [System.Windows.Interop.Imaging]::CreateBitmapSourceFromHIcon($icon.Handle,
                [System.Windows.Int32Rect]::Empty, [System.Windows.Media.Imaging.BitmapSizeOptions]::FromEmptyOptions())
            $source.Freeze()
            $icon.Dispose()
        }
    } catch { }
    $IconCache[$Path] = $source
    return $source
}

function New-AppIcon([string]$Path, [int]$Fallback = 0xE71D, [double]$Size = 32) {
    $source = Get-FileIcon $Path
    if (-not $source) { return New-IconTile $Fallback 'Accent' 'AccentSoft' $Size }
    $image = New-Object System.Windows.Controls.Image
    $image.Source = $source
    $image.Width = $Size * 0.85
    $image.Height = $Size * 0.85
    $image.VerticalAlignment = 'Center'
    [System.Windows.Media.RenderOptions]::SetBitmapScalingMode($image, 'HighQuality')
    $holder = New-Object System.Windows.Controls.Border
    $holder.Width = $Size
    $holder.Height = $Size
    $holder.Child = $image
    return $holder
}

# --- Animation -----------------------------------------------------------------

function New-Anim([double]$From, [double]$To, [int]$Ms) {
    $anim = New-Object System.Windows.Media.Animation.DoubleAnimation -ArgumentList $From, $To, (New-Object System.Windows.Duration ([TimeSpan]::FromMilliseconds($Ms)))
    $ease = New-Object System.Windows.Media.Animation.CubicEase
    $ease.EasingMode = 'EaseOut'
    $anim.EasingFunction = $ease
    return $anim
}

# Fades an element in and slides it up a little.
function Show-Animated($Element, [double]$Rise = 10) {
    if (-not ($Element.RenderTransform -is [System.Windows.Media.TranslateTransform])) {
        $Element.RenderTransform = New-Object System.Windows.Media.TranslateTransform
    }
    $Element.BeginAnimation([System.Windows.UIElement]::OpacityProperty, (New-Anim 0 1 220))
    $Element.RenderTransform.BeginAnimation([System.Windows.Media.TranslateTransform]::YProperty, (New-Anim $Rise 0 260))
}

# Ring gauges: an Ellipse whose stroke is cut with a dash pattern.
function Set-Ring($Ellipse, [double]$Percent) {
    $t = $Ellipse.StrokeThickness
    $circumference = [math]::PI * ($Ellipse.Width - $t) / $t
    $fill = $circumference * [math]::Max(0, [math]::Min(100, $Percent)) / 100
    $dashes = New-Object System.Windows.Media.DoubleCollection
    $dashes.Add([math]::Max(0.001, $fill))
    $dashes.Add(1000)
    $Ellipse.StrokeDashArray = $dashes
    $Ellipse.Opacity = $(if ($Percent -le 0) { 0 } else { 1 })
}

# Each ring gets its own timer, kept in the ellipse's Tag (no shared list).
function Start-RingFill($Ellipse, [double]$To, $Label = $null, [double]$From = 0) {
    if ($Ellipse.Tag -is [System.Windows.Threading.DispatcherTimer]) { $Ellipse.Tag.Stop() }
    $timer = New-Object System.Windows.Threading.DispatcherTimer
    $timer.Interval = [TimeSpan]::FromMilliseconds(16)
    $timer.Tag = @{ Ellipse = $Ellipse; Label = $Label; From = $From; To = $To; Start = [DateTime]::Now }
    $timer.Add_Tick({
            param($sender, $e)
            $st = $sender.Tag
            $t = [math]::Min(1.0, ([DateTime]::Now - $st.Start).TotalMilliseconds / 900.0)
            $eased = 1.0 - [math]::Pow(1.0 - $t, 3)
            $value = [double]$st.From + ([double]$st.To - [double]$st.From) * $eased
            Set-Ring $st.Ellipse $value
            if ($null -ne $st.Label) { $st.Label.Text = ([int][math]::Round($value)).ToString() }
            if ($t -ge 1.0) { $sender.Stop() }
        })
    $Ellipse.Tag = $timer
    $timer.Start()
}

function Start-Spin($Ellipse) {
    Set-Ring $Ellipse 22
    $duration = New-Object System.Windows.Duration ([TimeSpan]::FromMilliseconds(950))
    $spin = New-Object System.Windows.Media.Animation.DoubleAnimation -ArgumentList @([double]-90, [double]270, $duration)
    $spin.RepeatBehavior = [System.Windows.Media.Animation.RepeatBehavior]::Forever
    $Ellipse.RenderTransform.BeginAnimation([System.Windows.Media.RotateTransform]::AngleProperty, $spin)
}

function Stop-Spin($Ellipse) {
    $Ellipse.RenderTransform.BeginAnimation([System.Windows.Media.RotateTransform]::AngleProperty, $null)
    $Ellipse.RenderTransform.Angle = -90
}

# --- Dialog and notifications ------------------------------------------------------

$DialogLooks = @{
    info     = @{ Glyph = 0xE946; Color = 'Accent'; Soft = 'AccentSoft' }
    question = @{ Glyph = 0xE897; Color = 'Accent'; Soft = 'AccentSoft' }
    warn     = @{ Glyph = 0xE7BA; Color = 'Warn'; Soft = 'WarnSoft' }
    danger   = @{ Glyph = 0xE74D; Color = 'Bad'; Soft = 'BadSoft' }
    success  = @{ Glyph = 0xE73E; Color = 'Good'; Soft = 'GoodSoft' }
}

# Shows a dialog inside the window and waits for an answer. Returns $true when
# the main button is chosen.
function Show-Dialog {
    param([string]$Title, [string]$Text, [string]$Primary = 'OK', [string]$Secondary = '', [string]$Kind = 'info')
    $look = $DialogLooks[$Kind]
    $ui.DialogTitle.Text = $Title
    $ui.DialogText.Text = $Text
    $ui.DialogGlyph.Text = [string][char]$look.Glyph
    Set-Color $ui.DialogGlyph ([System.Windows.Controls.TextBlock]::ForegroundProperty) $look.Color
    Set-Color $ui.DialogIconTile ([System.Windows.Controls.Border]::BackgroundProperty) $look.Soft
    $ui.DialogPrimary.Content = $Primary
    $ui.DialogSecondary.Content = $Secondary
    $ui.DialogSecondary.Visibility = $(if ($Secondary) { 'Visible' } else { 'Collapsed' })
    $script:DialogResult = $false
    $script:DialogFrame = New-Object System.Windows.Threading.DispatcherFrame
    $ui.DialogLayer.Visibility = 'Visible'
    $ui.DialogLayer.BeginAnimation([System.Windows.UIElement]::OpacityProperty, (New-Anim 0 1 140))
    Show-Animated $ui.DialogCard 14
    [void]$ui.DialogPrimary.Focus()
    [System.Windows.Threading.Dispatcher]::PushFrame($script:DialogFrame)
    $script:DialogFrame = $null
    $ui.DialogLayer.Visibility = 'Collapsed'
    return $script:DialogResult
}

function Close-Dialog([bool]$Result) {
    if ($script:DialogFrame) {
        $script:DialogResult = $Result
        $script:DialogFrame.Continue = $false
    }
}

function Confirm-Action([string]$Title, [string]$Text, [string]$Yes = 'Continue', [string]$Kind = 'question') {
    return (Show-Dialog -Title $Title -Text $Text -Primary $Yes -Secondary 'Cancel' -Kind $Kind)
}

$ToastLooks = @{
    success = @{ Glyph = 0xE73E; Color = 'Good' }
    info    = @{ Glyph = 0xE946; Color = 'ToastText' }
    warn    = @{ Glyph = 0xE7BA; Color = 'Warn' }
    error   = @{ Glyph = 0xE783; Color = 'Bad' }
}
$ToastTimer = New-Object System.Windows.Threading.DispatcherTimer
$ToastTimer.Interval = [TimeSpan]::FromMilliseconds(3400)
$ToastTimer.Add_Tick({
        $ToastTimer.Stop()
        $fade = New-Anim 1 0 260
        $fade.Add_Completed({ if ($ui.Toast.Opacity -lt 0.05) { $ui.Toast.Visibility = 'Collapsed' } })
        $ui.Toast.BeginAnimation([System.Windows.UIElement]::OpacityProperty, $fade)
    })

function Show-Toast([string]$Text, [string]$Kind = 'success') {
    $look = $ToastLooks[$Kind]
    $ui.ToastText.Text = $Text
    $ui.ToastGlyph.Text = [string][char]$look.Glyph
    Set-Color $ui.ToastGlyph ([System.Windows.Controls.TextBlock]::ForegroundProperty) $look.Color
    $ui.Toast.Visibility = 'Visible'
    $ui.Toast.BeginAnimation([System.Windows.UIElement]::OpacityProperty, (New-Anim 0 1 200))
    $ui.Toast.RenderTransform.BeginAnimation([System.Windows.Media.TranslateTransform]::YProperty, (New-Anim 14 0 260))
    $ToastTimer.Stop()
    $ToastTimer.Start()
}

# Runs a click handler and turns any error into a friendly message.
function Invoke-Guarded([scriptblock]$Action, $Argument) {
    try {
        & $Action $Argument
    } catch {
        $where = ''
        if ($_.InvocationInfo) { $where = ' [{0}, line {1}]' -f (Split-Path -Leaf $_.InvocationInfo.ScriptName), $_.InvocationInfo.ScriptLineNumber }
        Write-Activity ('Problem: {0}{1}' -f $_.Exception.Message, $where)
        Show-Toast ('Something went wrong: {0}{1}' -f $_.Exception.Message, $where) 'error'
    }
}

# --- Activity log and settings ------------------------------------------------------

$DataDir = Join-Path $env:LOCALAPPDATA 'PCManager'
New-Item -ItemType Directory -Path $DataDir -Force | Out-Null
$LogFile = Join-Path $DataDir 'activity.log'
$SettingsFile = Join-Path $DataDir 'settings.json'
$Activity = New-Object System.Collections.Generic.List[object]

function Write-Activity([string]$Message) {
    $Activity.Insert(0, [pscustomobject]@{ Time = Get-Date; Text = $Message })
    if ($Activity.Count -gt 200) { $Activity.RemoveAt($Activity.Count - 1) }
    try { Add-Content -Path $LogFile -Value ('{0}  {1}' -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $Message) } catch { }
}

function Get-Settings {
    $settings = @{ Theme = 'System'; ConfirmDelete = $true }
    if (Test-Path -LiteralPath $SettingsFile) {
        try {
            $saved = Get-Content -LiteralPath $SettingsFile -Raw | ConvertFrom-Json
            foreach ($prop in $saved.PSObject.Properties) { $settings[$prop.Name] = $prop.Value }
        } catch { }
    }
    return $settings
}

function Save-Settings {
    try { $Settings | ConvertTo-Json | Set-Content -LiteralPath $SettingsFile -Encoding UTF8 } catch { }
}

# --- Background work -------------------------------------------------------------
# One worker runspace runs scans and clean-ups so the window never freezes.
# The worker loads only the engine files; it never touches the window.

function Initialize-Worker([string[]]$EngineFiles) {
    $global:Sync = [hashtable]::Synchronized(@{ Text = ''; Percent = -1; Cancel = $false })
    $state = [System.Management.Automation.Runspaces.InitialSessionState]::CreateDefault()
    try { $state.ExecutionPolicy = 'Bypass' } catch { }
    $runspace = [runspacefactory]::CreateRunspace($state)
    $runspace.ApartmentState = 'STA'
    $runspace.ThreadOptions = 'ReuseThread'
    $runspace.Open()
    $runspace.SessionStateProxy.SetVariable('Sync', $global:Sync)
    $loader = [powershell]::Create()
    $loader.Runspace = $runspace
    [void]$loader.AddScript((($EngineFiles | ForEach-Object { ". '{0}'" -f $_.Replace("'", "''") }) -join "`n"))
    [void]$loader.Invoke()
    $loader.Dispose()
    $script:Worker = $runspace
    $script:Work = $null
    $script:WorkTimer = New-Object System.Windows.Threading.DispatcherTimer
    $script:WorkTimer.Interval = [TimeSpan]::FromMilliseconds(90)
    $script:WorkTimer.Add_Tick({ Update-Work })
}

function Test-WorkRunning { return ($null -ne $script:Work) }

# Script runs in the worker; OnDone gets all of its output as an array.
# OnProgress gets ($text, $percent) about ten times a second.
function Start-Work {
    param([scriptblock]$Script, [object[]]$Arguments = @(), [scriptblock]$OnDone, [scriptblock]$OnError, [scriptblock]$OnProgress)
    if ($script:Work) {
        Show-Toast 'Another task is still running. It will only take a moment.' 'info'
        return $false
    }
    $global:Sync.Text = ''
    $global:Sync.Percent = -1
    $global:Sync.Cancel = $false
    $ps = [powershell]::Create()
    $ps.Runspace = $script:Worker
    [void]$ps.AddScript($Script.ToString())
    foreach ($argument in $Arguments) { [void]$ps.AddArgument($argument) }
    $script:Work = @{ PS = $ps; Handle = $ps.BeginInvoke(); OnDone = $OnDone; OnError = $OnError; OnProgress = $OnProgress }
    $script:WorkTimer.Start()
    return $true
}

function Stop-Work {
    if ($script:Work) { $global:Sync.Cancel = $true }
}

function Update-Work {
    $work = $script:Work
    if (-not $work) { $script:WorkTimer.Stop(); return }
    if ($work.OnProgress) {
        try { & $work.OnProgress $global:Sync.Text $global:Sync.Percent } catch { }
    }
    if (-not $work.Handle.IsCompleted) { return }
    $script:WorkTimer.Stop()
    $script:Work = $null
    $output = @()
    $failure = $null
    try {
        $output = @($work.PS.EndInvoke($work.Handle))
        if ($output.Count -eq 0 -and $work.PS.Streams.Error.Count -gt 0) { $failure = $work.PS.Streams.Error[0].Exception }
    } catch {
        $failure = $_.Exception
        if ($failure.InnerException) { $failure = $failure.InnerException }
    }
    $work.PS.Dispose()
    if ($failure) {
        Write-Activity ('Problem: {0}' -f $failure.Message)
        if ($work.OnError) { Invoke-Guarded $work.OnError $failure }
        else { Show-Toast ('Something went wrong: {0}' -f $failure.Message) 'error' }
        return
    }
    if ($work.OnDone) { Invoke-Guarded $work.OnDone $output }
}

# --- Pages and navigation --------------------------------------------------------

$Pages = [ordered]@{}
function Register-Page([string]$Key, [scriptblock]$Init, [scriptblock]$Show) {
    $Pages[$Key] = @{ Key = $Key; Init = $Init; Show = $Show; Root = $null }
}

function Initialize-Pages([string]$PageDir) {
    foreach ($page in $Pages.Values) {
        $root = Import-Xaml (Join-Path $PageDir ('{0}.xaml' -f $page.Key))
        $root.Visibility = 'Collapsed'
        $root.RenderTransform = New-Object System.Windows.Media.TranslateTransform
        [void]$ui.PageHost.Children.Add($root)
        $page.Root = $root
    }
    foreach ($page in $Pages.Values) {
        if ($page.Init) { Invoke-Guarded $page.Init }
    }
}

function Show-Page([string]$Key) {
    if ($script:CurrentPage -eq $Key) { return }
    $script:CurrentPage = $Key
    $navButton = $ui['Nav' + $Key]
    if ($navButton -and -not $navButton.IsChecked) { $navButton.IsChecked = $true }
    foreach ($page in $Pages.Values) {
        $page.Root.Visibility = $(if ($page.Key -eq $Key) { 'Visible' } else { 'Collapsed' })
    }
    $page = $Pages[$Key]
    Show-Animated $page.Root 12
    if ($page.Show) { Invoke-Guarded $page.Show }
}

# --- Window frame ------------------------------------------------------------------

function Initialize-Shell {
    $ui.BtnMin.Add_Click({ $window.WindowState = 'Minimized' })
    $ui.BtnMax.Add_Click({
            if ($window.WindowState -eq 'Maximized') { $window.WindowState = 'Normal' } else { $window.WindowState = 'Maximized' }
        })
    $ui.BtnClose.Add_Click({ $window.Close() })
    $window.Add_StateChanged({
            if ($window.WindowState -eq 'Maximized') {
                # A borderless window spills past the screen edge when maximized.
                $ui.RootGrid.Margin = New-Thick 7 7 7 7
                $ui.BtnMax.Content = [string][char]0xE923
                $ui.BtnMax.ToolTip = 'Restore'
            } else {
                $ui.RootGrid.Margin = New-Thick 0 0 0 0
                $ui.BtnMax.Content = [string][char]0xE922
                $ui.BtnMax.ToolTip = 'Maximize'
            }
        })

    foreach ($key in $Pages.Keys) {
        $nav = $ui['Nav' + $key]
        if ($nav) { $nav.Add_Checked({ param($s, $e) Show-Page ([string]$s.Tag) }) }
    }

    $ui.DialogPrimary.Add_Click({ Close-Dialog $true })
    $ui.DialogSecondary.Add_Click({ Close-Dialog $false })
    $window.Add_PreviewKeyDown({
            param($s, $e)
            if (-not $script:DialogFrame) { return }
            if ($e.Key -eq 'Escape') { Close-Dialog $false; $e.Handled = $true }
            elseif ($e.Key -eq 'Enter') { Close-Dialog (-not $ui.DialogSecondary.IsKeyboardFocused); $e.Handled = $true }
        })
    $window.Add_Closing({
            Close-Dialog $false
            if ($script:Work) {
                $global:Sync.Cancel = $true
                try { $script:Work.PS.Stop() } catch { }
            }
        })

    if ($IsAdmin) {
        $ui.AdminPill.ToolTip = 'PC Manager has administrator rights, so every feature is available.'
    } else {
        $ui.AdminPillText.Text = 'Limited mode'
        Set-Color $ui.AdminPillText ([System.Windows.Controls.TextBlock]::ForegroundProperty) 'Warn'
        Set-Color $ui.AdminPill ([System.Windows.Controls.Border]::BackgroundProperty) 'WarnSoft'
        $ui.AdminPill.Cursor = [System.Windows.Input.Cursors]::Hand
        $ui.AdminPill.ToolTip = 'Some features need administrator rights. Click to restart PC Manager as administrator.'
        $ui.AdminPill.Add_MouseLeftButtonUp({ Request-AdminRestart })
    }
}

# --- Helpers used by several pages ----------------------------------------------------

function Request-AdminRestart {
    if (-not (Confirm-Action 'Restart as administrator?' 'PC Manager will close and open again with full access. Windows will ask for permission.' 'Restart')) { return }
    try {
        Start-Process -FilePath 'powershell.exe' -Verb RunAs -ArgumentList @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-STA', '-WindowStyle', 'Hidden', '-File', "`"$AppScript`"") -ErrorAction Stop
        $window.Close()
    } catch {
        Show-Toast 'Windows did not give permission, so PC Manager stays in limited mode.' 'warn'
    }
}

# Says why a feature is unavailable and offers the restart. Returns $true when allowed.
function Assert-Admin([string]$What) {
    if ($IsAdmin) { return $true }
    if (Confirm-Action 'Administrator rights needed' ("{0} needs administrator rights. Restart PC Manager as administrator now?" -f $What) 'Restart as admin' 'warn') {
        Request-AdminRestart
    }
    return $false
}

function Open-Target([string]$Target, [string]$Arguments = '') {
    try {
        if ($Arguments) { Start-Process -FilePath $Target -ArgumentList $Arguments } else { Start-Process -FilePath $Target }
    } catch {
        Show-Toast ('Could not open {0}.' -f $Target) 'error'
    }
}

function New-ReportPath([string]$Name) {
    $dir = Join-Path ([Environment]::GetFolderPath('MyDocuments')) 'PC Manager Reports'
    New-Item -ItemType Directory -Path $dir -Force | Out-Null
    return Join-Path $dir ('{0}-{1}.html' -f $Name, (Get-Date -Format 'yyyy-MM-dd-HHmm'))
}

# Runs a long Windows tool in its own console window (it inherits admin rights).
function Start-ToolWindow([string]$Title, [string]$Command) {
    $body = @"
`$Host.UI.RawUI.WindowTitle = 'PC Manager - $Title'
Write-Host ''
Write-Host '  $Title' -ForegroundColor Cyan
Write-Host ''
$Command
Write-Host ''
Write-Host '  Finished.' -ForegroundColor Green
Read-Host '  Press Enter to close this window'
"@
    $encoded = [Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($body))
    Start-Process -FilePath 'powershell.exe' -ArgumentList @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-EncodedCommand', $encoded)
    Write-Activity ('Started: {0}' -f $Title)
    Show-Toast ('{0} is running in its own window.' -f $Title) 'info'
}
