<#
    PC Manager 2.0 - a local tune-up app for Windows 10 and 11 laptops.

    Start it by double-clicking "Start PC Manager.bat".
    Nothing is installed and nothing is sent anywhere. Every change can be
    switched back, and everything it does is listed in Settings > Recent
    activity (full log: %LOCALAPPDATA%\PCManager\activity.log).

    Folders:
      engine\   what the app does (no window code; also used by the
                background worker that runs scans and clean-ups)
      ui\       the window: theme, shared plumbing and one file pair per page

    Run with -NoElevate to skip the administrator prompt (fewer features).
#>

param([switch]$NoElevate)

$AppRoot = $PSScriptRoot
$AppScript = $PSCommandPath
. (Join-Path $AppRoot 'engine\Common.ps1')

# Ask for administrator rights once. If the answer is no, run in limited mode.
if (-not (Test-IsAdmin) -and -not $NoElevate) {
    try {
        $relaunch = @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-STA', '-WindowStyle', 'Hidden', '-File', "`"$AppScript`"")
        Start-Process -FilePath 'powershell.exe' -Verb RunAs -ArgumentList $relaunch -ErrorAction Stop
        exit 0
    } catch {
        # Permission prompt declined: carry on with fewer features.
    }
}
$IsAdmin = Test-IsAdmin

Add-Type -AssemblyName PresentationFramework, PresentationCore, WindowsBase, System.Drawing, Microsoft.VisualBasic

# Engine (logic) files. The worker loads the ones it needs on its own.
foreach ($name in 'Cleaner', 'System', 'Startup', 'Tweaks') {
    . (Join-Path $AppRoot "engine\$name.ps1")
}
$WorkerFiles = @('Common', 'Cleaner', 'System') | ForEach-Object { Join-Path $AppRoot "engine\$_.ps1" }

# Window plumbing, then the pages in sidebar order.
. (Join-Path $AppRoot 'ui\Core.ps1')
. (Join-Path $AppRoot 'ui\Widgets.ps1')
$PageNames = 'Home', 'Cleaner', 'Storage', 'Startup', 'Processes', 'Apps', 'Power', 'Tweaks', 'Toolbox', 'Settings'
foreach ($name in $PageNames) {
    . (Join-Path $AppRoot "ui\pages\$name.ps1")
}

# Draws the app logo into a bitmap for the taskbar icon.
function New-LogoBitmap {
    $gradient = New-Object System.Windows.Media.LinearGradientBrush
    $gradient.StartPoint = New-Object System.Windows.Point 0, 0
    $gradient.EndPoint = New-Object System.Windows.Point 1, 1
    $gradient.GradientStops.Add((New-Object System.Windows.Media.GradientStop ([System.Windows.Media.Color]::FromRgb(0x6A, 0x9B, 0xFF)), 0))
    $gradient.GradientStops.Add((New-Object System.Windows.Media.GradientStop ([System.Windows.Media.Color]::FromRgb(0x2F, 0x5F, 0xE3)), 1))
    $logo = New-Object System.Windows.Controls.Border
    $logo.Width = 64
    $logo.Height = 64
    $logo.CornerRadius = New-Object System.Windows.CornerRadius -ArgumentList 16
    $logo.Background = $gradient
    $glyph = New-Object System.Windows.Controls.TextBlock
    $glyph.Text = [string][char]0xE770
    $glyph.FontFamily = $IconFont
    $glyph.FontSize = 32
    $glyph.Foreground = [System.Windows.Media.Brushes]::White
    $glyph.HorizontalAlignment = 'Center'
    $glyph.VerticalAlignment = 'Center'
    $logo.Child = $glyph
    $logo.Measure((New-Object System.Windows.Size 64, 64))
    $logo.Arrange((New-Object System.Windows.Rect 0, 0, 64, 64))
    $bitmap = New-Object System.Windows.Media.Imaging.RenderTargetBitmap -ArgumentList 64, 64, 96, 96, ([System.Windows.Media.PixelFormats]::Pbgra32)
    $bitmap.Render($logo)
    $bitmap.Freeze()
    return $bitmap
}

try {
    $Settings = Get-Settings

    $app = [System.Windows.Application]::Current
    if (-not $app) {
        $app = New-Object System.Windows.Application
        $app.ShutdownMode = 'OnExplicitShutdown'
    }
    $themeText = Get-Content -LiteralPath (Join-Path $AppRoot 'ui\Theme.xaml') -Raw -Encoding UTF8
    try {
        $app.Resources.MergedDictionaries.Add([Windows.Markup.XamlReader]::Parse($themeText))
    } catch {
        throw ('Theme.xaml: {0}' -f (Get-InnerMessage $_.Exception))
    }
    Set-Theme $Settings.Theme

    $window = Import-Xaml (Join-Path $AppRoot 'ui\Shell.xaml')
    try {
        $window.Icon = [System.Windows.Media.Imaging.BitmapFrame]::Create((New-Object System.Uri (Join-Path $AppRoot 'icon.ico')))
    } catch {
        try { $window.Icon = New-LogoBitmap } catch { }
    }

    # Fit the window to this screen (usable area, in the same units WPF uses),
    # so the title bar is never pushed off the top on small or scaled displays.
    $area = [System.Windows.SystemParameters]::WorkArea
    $window.MinWidth = [math]::Min(900, [math]::Max(600, $area.Width - 24))
    $window.MinHeight = [math]::Min(560, [math]::Max(400, $area.Height - 24))
    $window.Width = [math]::Min(1180, $area.Width - 24)
    $window.Height = [math]::Min(780, $area.Height - 24)
    $window.WindowStartupLocation = 'Manual'
    $window.Left = $area.Left + ($area.Width - $window.Width) / 2
    $window.Top = $area.Top + ($area.Height - $window.Height) / 2

    Initialize-Pages (Join-Path $AppRoot 'ui\pages')
    Initialize-Shell
    Initialize-Worker $WorkerFiles

    # Follow Windows if its light/dark setting changes while we are open.
    $window.Add_Activated({
            if ($Settings.Theme -eq 'System' -and (Test-WindowsDarkMode) -ne $script:IsDark) { Set-Theme 'System' }
        })
    $window.Add_ContentRendered({ Show-Page 'Home' })

    Write-Activity $(if ($IsAdmin) { 'PC Manager started.' } else { 'PC Manager started in limited mode.' })
    [void]$window.ShowDialog()
} catch {
    $details = Get-InnerMessage $_.Exception
    $where = $_.InvocationInfo.PositionMessage
    try { Add-Content -Path $LogFile -Value ('{0}  Start-up error: {1}`n{2}' -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $details, $where) } catch { }
    [void][System.Windows.MessageBox]::Show("PC Manager could not start:`n`n$details`n`n$where", 'PC Manager',
        [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Error)
    exit 1
} finally {
    if ($script:Work) { try { $script:Work.PS.Stop() } catch { } }
    if ($script:Worker) { try { $script:Worker.Close(); $script:Worker.Dispose() } catch { } }
}
