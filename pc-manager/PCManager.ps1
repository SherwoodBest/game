<#
    PC Manager - a small, local tool for tuning up a Windows 10/11 laptop.

    Start it by double-clicking "Start PC Manager.bat".
    Nothing is installed and nothing is sent anywhere. Every setting it changes
    can be switched back, and every action is written to:
        %LOCALAPPDATA%\PCManager\activity.log

    Run with -NoElevate to skip the administrator prompt (fewer features).
#>

param([switch]$NoElevate)

# ---------------------------------------------------------------------------
# Administrator rights: ask once at start. If the answer is no, run with fewer
# features instead of failing.
# ---------------------------------------------------------------------------
function Test-IsAdmin {
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($identity)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

if (-not (Test-IsAdmin) -and -not $NoElevate) {
    try {
        $relaunchArgs = @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-STA', '-WindowStyle', 'Hidden', '-File', "`"$PSCommandPath`"")
        Start-Process -FilePath 'powershell.exe' -Verb RunAs -ArgumentList $relaunchArgs -ErrorAction Stop
        exit 0
    } catch {
        # The Windows permission prompt was declined: carry on in limited mode.
    }
}
$script:IsAdmin = Test-IsAdmin

Add-Type -AssemblyName PresentationFramework, PresentationCore, WindowsBase

$AppDataDir = Join-Path $env:LOCALAPPDATA 'PCManager'
New-Item -ItemType Directory -Path $AppDataDir -Force | Out-Null
$LogFile = Join-Path $AppDataDir 'activity.log'

$script:Busy = $false
$script:WShell = New-Object -ComObject WScript.Shell

# ---------------------------------------------------------------------------
# Window layout
# ---------------------------------------------------------------------------
[xml]$Xaml = @'
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="PC Manager" Width="1060" Height="740" MinWidth="880" MinHeight="600"
        WindowStartupLocation="CenterScreen" Background="#F3F4F6"
        FontFamily="Segoe UI" FontSize="13" Foreground="#1F2937">
  <Window.Resources>
    <Style TargetType="Button">
      <Setter Property="Background" Value="#FFFFFF"/>
      <Setter Property="Foreground" Value="#1F2937"/>
      <Setter Property="BorderBrush" Value="#CBD5E1"/>
      <Setter Property="BorderThickness" Value="1"/>
      <Setter Property="Padding" Value="14,7"/>
      <Setter Property="Margin" Value="0,0,8,8"/>
      <Setter Property="Cursor" Value="Hand"/>
      <Setter Property="Template">
        <Setter.Value>
          <ControlTemplate TargetType="Button">
            <Border x:Name="Bd" Background="{TemplateBinding Background}" BorderBrush="{TemplateBinding BorderBrush}"
                    BorderThickness="{TemplateBinding BorderThickness}" CornerRadius="6" Padding="{TemplateBinding Padding}">
              <ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center"/>
            </Border>
            <ControlTemplate.Triggers>
              <Trigger Property="IsPressed" Value="True">
                <Setter TargetName="Bd" Property="Opacity" Value="0.8"/>
              </Trigger>
              <Trigger Property="IsEnabled" Value="False">
                <Setter TargetName="Bd" Property="Opacity" Value="0.45"/>
              </Trigger>
            </ControlTemplate.Triggers>
          </ControlTemplate>
        </Setter.Value>
      </Setter>
      <Style.Triggers>
        <Trigger Property="IsMouseOver" Value="True">
          <Setter Property="Background" Value="#EEF2F7"/>
        </Trigger>
      </Style.Triggers>
    </Style>
    <Style x:Key="Primary" TargetType="Button" BasedOn="{StaticResource {x:Type Button}}">
      <Setter Property="Background" Value="#2563EB"/>
      <Setter Property="Foreground" Value="#FFFFFF"/>
      <Setter Property="BorderBrush" Value="#2563EB"/>
      <Setter Property="FontWeight" Value="SemiBold"/>
      <Style.Triggers>
        <Trigger Property="IsMouseOver" Value="True">
          <Setter Property="Background" Value="#1D4ED8"/>
        </Trigger>
      </Style.Triggers>
    </Style>
    <Style TargetType="TabItem">
      <Setter Property="Width" Value="180"/>
      <Setter Property="Cursor" Value="Hand"/>
      <Setter Property="Foreground" Value="#374151"/>
      <Setter Property="Template">
        <Setter.Value>
          <ControlTemplate TargetType="TabItem">
            <Border x:Name="Bd" Padding="16,10" Margin="0,0,0,4" CornerRadius="6" Background="Transparent">
              <ContentPresenter ContentSource="Header"/>
            </Border>
            <ControlTemplate.Triggers>
              <Trigger Property="IsMouseOver" Value="True">
                <Setter TargetName="Bd" Property="Background" Value="#E5E9F0"/>
              </Trigger>
              <Trigger Property="IsSelected" Value="True">
                <Setter TargetName="Bd" Property="Background" Value="#DBEAFE"/>
                <Setter Property="Foreground" Value="#1E40AF"/>
                <Setter Property="FontWeight" Value="SemiBold"/>
              </Trigger>
            </ControlTemplate.Triggers>
          </ControlTemplate>
        </Setter.Value>
      </Setter>
    </Style>
    <Style x:Key="H1" TargetType="TextBlock">
      <Setter Property="FontSize" Value="22"/>
      <Setter Property="FontWeight" Value="SemiBold"/>
      <Setter Property="Margin" Value="0,0,0,4"/>
    </Style>
    <Style x:Key="H2" TargetType="TextBlock">
      <Setter Property="FontSize" Value="15"/>
      <Setter Property="FontWeight" Value="SemiBold"/>
      <Setter Property="Margin" Value="0,0,0,8"/>
    </Style>
    <Style x:Key="Sub" TargetType="TextBlock">
      <Setter Property="Foreground" Value="#6B7280"/>
      <Setter Property="TextWrapping" Value="Wrap"/>
      <Setter Property="Margin" Value="0,0,0,14"/>
    </Style>
    <Style x:Key="Note" TargetType="TextBlock">
      <Setter Property="Foreground" Value="#6B7280"/>
      <Setter Property="TextWrapping" Value="Wrap"/>
      <Setter Property="Margin" Value="0,0,0,10"/>
    </Style>
    <Style x:Key="Card" TargetType="Border">
      <Setter Property="Background" Value="#FFFFFF"/>
      <Setter Property="BorderBrush" Value="#E5E7EB"/>
      <Setter Property="BorderThickness" Value="1"/>
      <Setter Property="CornerRadius" Value="8"/>
      <Setter Property="Padding" Value="16"/>
      <Setter Property="Margin" Value="0,0,0,12"/>
    </Style>
  </Window.Resources>

  <Grid Margin="16">
    <Grid.RowDefinitions>
      <RowDefinition Height="Auto"/>
      <RowDefinition Height="*"/>
      <RowDefinition Height="130"/>
      <RowDefinition Height="Auto"/>
    </Grid.RowDefinitions>

    <DockPanel Grid.Row="0" Margin="4,0,4,14">
      <Border x:Name="AdminBadge" DockPanel.Dock="Right" CornerRadius="12" Padding="12,4" VerticalAlignment="Center" Background="#DCFCE7">
        <TextBlock x:Name="AdminText" Text="Administrator" Foreground="#166534" FontSize="12"/>
      </Border>
      <StackPanel>
        <TextBlock Text="PC Manager" FontSize="24" FontWeight="Bold"/>
        <TextBlock Text="Keep your Windows laptop fast, tidy and healthy." Foreground="#6B7280"/>
      </StackPanel>
    </DockPanel>

    <TabControl x:Name="Tabs" Grid.Row="1" TabStripPlacement="Left" Background="Transparent" BorderThickness="0" Padding="18,0,0,0">

      <!-- Overview -->
      <TabItem x:Name="TabOverview" Header="Overview">
        <ScrollViewer VerticalScrollBarVisibility="Auto">
          <StackPanel Margin="0,0,12,0">
            <TextBlock Style="{StaticResource H1}" Text="Overview"/>
            <TextBlock Style="{StaticResource Sub}" Text="How your laptop is doing right now, with suggestions to make it faster. Quick tune-up removes temporary files and clears caches that are safe to delete."/>
            <WrapPanel>
              <Button x:Name="BtnQuickTune" Style="{StaticResource Primary}" Content="Quick tune-up"/>
              <Button x:Name="BtnRefreshOverview" Content="Refresh"/>
            </WrapPanel>
            <Border Style="{StaticResource Card}">
              <StackPanel>
                <TextBlock Style="{StaticResource H2}" Text="Suggestions"/>
                <StackPanel x:Name="TipsPanel"/>
              </StackPanel>
            </Border>
            <Border Style="{StaticResource Card}">
              <StackPanel>
                <TextBlock Style="{StaticResource H2}" Text="Usage"/>
                <StackPanel x:Name="UsagePanel"/>
              </StackPanel>
            </Border>
            <Border Style="{StaticResource Card}">
              <StackPanel>
                <TextBlock Style="{StaticResource H2}" Text="This PC"/>
                <StackPanel x:Name="InfoPanel"/>
              </StackPanel>
            </Border>
          </StackPanel>
        </ScrollViewer>
      </TabItem>

      <!-- Clean up -->
      <TabItem x:Name="TabClean" Header="Clean up">
        <ScrollViewer VerticalScrollBarVisibility="Auto">
          <StackPanel Margin="0,0,12,0">
            <TextBlock Style="{StaticResource H1}" Text="Clean up"/>
            <TextBlock Style="{StaticResource Sub}" Text="Free up space by removing files that Windows and your apps do not need. Your documents, photos, passwords and browsing history are never touched. Close your web browsers first for the best result - files that are in use are skipped."/>
            <WrapPanel>
              <Button x:Name="BtnCleanScan" Style="{StaticResource Primary}" Content="Scan"/>
              <Button x:Name="BtnCleanRun" Content="Clean selected"/>
              <Button x:Name="BtnDiskCleanup" Content="Windows Disk Cleanup"/>
              <Button x:Name="BtnStorageSettings" Content="Storage settings"/>
            </WrapPanel>
            <Border Style="{StaticResource Card}">
              <StackPanel x:Name="CleanPanel"/>
            </Border>
            <TextBlock x:Name="CleanSummary" FontSize="14" FontWeight="SemiBold" Margin="2,0,0,12" Text="Press Scan to see how much space you can free."/>
            <TextBlock Style="{StaticResource Note}" Text="Tip: after a big Windows update, Windows Disk Cleanup can also remove the previous Windows installation (often 10 GB or more). Open it, choose 'Clean up system files', then tick 'Previous Windows installation(s)'."/>
          </StackPanel>
        </ScrollViewer>
      </TabItem>

      <!-- Startup apps -->
      <TabItem x:Name="TabStartup" Header="Startup apps">
        <ScrollViewer VerticalScrollBarVisibility="Auto">
          <StackPanel Margin="0,0,12,0">
            <TextBlock Style="{StaticResource H1}" Text="Startup apps"/>
            <TextBlock Style="{StaticResource Sub}" Text="These apps start by themselves when you sign in, which slows down start-up. Untick the ones you do not need straight away. Nothing is uninstalled - you can still open them normally, and tick them again any time. This is the same switch Task Manager uses."/>
            <WrapPanel>
              <Button x:Name="BtnStartupRefresh" Content="Refresh"/>
              <Button x:Name="BtnStartupStore" Content="Store app startup settings"/>
              <Button x:Name="BtnTaskManager" Content="Open Task Manager"/>
            </WrapPanel>
            <TextBlock x:Name="StartupSummary" FontSize="14" FontWeight="SemiBold" Margin="2,0,0,10"/>
            <Border Style="{StaticResource Card}">
              <StackPanel x:Name="StartupPanel"/>
            </Border>
          </StackPanel>
        </ScrollViewer>
      </TabItem>

      <!-- Apps and processes -->
      <TabItem x:Name="TabProcesses" Header="Apps &amp; processes">
        <Grid Margin="0,0,12,0">
          <Grid.RowDefinitions>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="*"/>
          </Grid.RowDefinitions>
          <TextBlock Grid.Row="0" Style="{StaticResource H1}" Text="Apps &amp; processes"/>
          <TextBlock Grid.Row="1" Style="{StaticResource Sub}" Text="What is using your memory and processor right now, biggest first. Ending an app closes it immediately, so save your work in it first."/>
          <WrapPanel Grid.Row="2">
            <Button x:Name="BtnProcRefresh" Style="{StaticResource Primary}" Content="Refresh"/>
            <Button x:Name="BtnProcEnd" Content="End selected app"/>
          </WrapPanel>
          <TextBlock Grid.Row="3" x:Name="ProcSummary" FontWeight="SemiBold" Margin="2,0,0,10"/>
          <Border Grid.Row="4" Style="{StaticResource Card}" Padding="4">
            <ListView x:Name="ProcList" SelectionMode="Single" BorderThickness="0">
              <ListView.View>
                <GridView>
                  <GridViewColumn Header="App" Width="190" DisplayMemberBinding="{Binding Name}"/>
                  <GridViewColumn Header="Description" Width="260" DisplayMemberBinding="{Binding Description}"/>
                  <GridViewColumn Header="Memory (MB)" Width="100" DisplayMemberBinding="{Binding MemoryMB}"/>
                  <GridViewColumn Header="CPU %" Width="70" DisplayMemberBinding="{Binding Cpu}"/>
                  <GridViewColumn Header="Processes" Width="80" DisplayMemberBinding="{Binding Count}"/>
                </GridView>
              </ListView.View>
            </ListView>
          </Border>
        </Grid>
      </TabItem>

      <!-- Power and battery -->
      <TabItem x:Name="TabPower" Header="Power &amp; battery">
        <ScrollViewer VerticalScrollBarVisibility="Auto">
          <StackPanel Margin="0,0,12,0">
            <TextBlock Style="{StaticResource H1}" Text="Power &amp; battery"/>
            <TextBlock Style="{StaticResource Sub}" Text="Choose how your laptop balances speed and battery life, and check how healthy your battery is."/>
            <Border Style="{StaticResource Card}">
              <StackPanel>
                <TextBlock Style="{StaticResource H2}" Text="Power plan"/>
                <StackPanel x:Name="PlanPanel" Margin="0,0,0,8"/>
                <TextBlock Style="{StaticResource Note}" Text="Many newer laptops only offer the Balanced plan. On those, use Power mode instead: Best performance when plugged in, Best power efficiency on battery."/>
                <WrapPanel>
                  <Button x:Name="BtnPowerMode" Content="Power mode settings"/>
                  <Button x:Name="BtnAddHighPerf" Content="Add High performance plan"/>
                </WrapPanel>
              </StackPanel>
            </Border>
            <Border Style="{StaticResource Card}">
              <StackPanel>
                <TextBlock Style="{StaticResource H2}" Text="Battery"/>
                <StackPanel x:Name="BatteryPanel" Margin="0,0,0,8"/>
                <TextBlock Style="{StaticResource Note}" Text="The battery report shows capacity over time and how long your battery lasts. The energy check watches your laptop for one minute and lists settings and devices that waste power."/>
                <WrapPanel>
                  <Button x:Name="BtnBatteryReport" Content="Battery report"/>
                  <Button x:Name="BtnEnergyReport" Content="Energy check (1 minute)"/>
                </WrapPanel>
              </StackPanel>
            </Border>
          </StackPanel>
        </ScrollViewer>
      </TabItem>

      <!-- Tweaks -->
      <TabItem x:Name="TabTweaks" Header="Tweaks">
        <ScrollViewer VerticalScrollBarVisibility="Auto">
          <StackPanel Margin="0,0,12,0">
            <TextBlock Style="{StaticResource H1}" Text="Tweaks"/>
            <TextBlock Style="{StaticResource Sub}" Text="Each switch shows the current setting - ticked means on. Changes apply straight away and you can switch them back any time. A few only take full effect after you sign out or restart."/>
            <WrapPanel>
              <Button x:Name="BtnTweaksRefresh" Content="Refresh"/>
              <Button x:Name="BtnVisualEffects" Content="Visual effects options"/>
            </WrapPanel>
            <Border Style="{StaticResource Card}">
              <StackPanel x:Name="TweakPanel"/>
            </Border>
            <TextBlock Style="{StaticResource Note}" Text="Visual effects options: choose 'Adjust for best performance' to turn off animations and shadows, then tick 'Smooth edges of screen fonts' so text stays easy to read. This helps most on older or slower laptops."/>
          </StackPanel>
        </ScrollViewer>
      </TabItem>

      <!-- Maintenance -->
      <TabItem x:Name="TabMaintenance" Header="Maintenance">
        <ScrollViewer VerticalScrollBarVisibility="Auto">
          <StackPanel Margin="0,0,12,0">
            <TextBlock Style="{StaticResource H1}" Text="Maintenance"/>
            <TextBlock Style="{StaticResource Sub}" Text="Health checks and repairs. Longer jobs open in their own window, so you can keep using PC Manager while they run."/>
            <Border Style="{StaticResource Card}">
              <StackPanel>
                <TextBlock Style="{StaticResource H2}" Text="Safety net"/>
                <TextBlock Style="{StaticResource Note}" Text="Make a restore point before big changes. If something goes wrong, System Restore can roll Windows settings back to it. Your files are not affected."/>
                <WrapPanel>
                  <Button x:Name="BtnRestorePoint" Style="{StaticResource Primary}" Content="Create restore point"/>
                  <Button x:Name="BtnRestoreOpen" Content="Open System Restore"/>
                </WrapPanel>
              </StackPanel>
            </Border>
            <Border Style="{StaticResource Card}">
              <StackPanel>
                <TextBlock Style="{StaticResource H2}" Text="Check and repair Windows"/>
                <TextBlock Style="{StaticResource Note}" Text="Use these if Windows crashes, behaves oddly, or updates keep failing. Run 'Repair Windows image' first (10 to 30 minutes, needs internet), then 'Check system files'."/>
                <WrapPanel>
                  <Button x:Name="BtnDism" Content="Repair Windows image"/>
                  <Button x:Name="BtnSfc" Content="Check system files"/>
                </WrapPanel>
              </StackPanel>
            </Border>
            <Border Style="{StaticResource Card}">
              <StackPanel>
                <TextBlock Style="{StaticResource H2}" Text="Drives"/>
                <TextBlock Style="{StaticResource Note}" Text="Optimizing trims SSDs and defragments hard drives. Windows does this weekly on its own, but you can run it now. The health check and error scan only read your drives - they change nothing."/>
                <WrapPanel>
                  <Button x:Name="BtnOptimize" Content="Optimize drives"/>
                  <Button x:Name="BtnDriveHealth" Content="Check drive health"/>
                  <Button x:Name="BtnChkdsk" Content="Scan system drive for errors"/>
                </WrapPanel>
              </StackPanel>
            </Border>
            <Border Style="{StaticResource Card}">
              <StackPanel>
                <TextBlock Style="{StaticResource H2}" Text="Updates"/>
                <TextBlock Style="{StaticResource Note}" Text="Updates fix bugs and security holes and often make things faster. App updates use winget, which comes with Windows 10 and 11 (App Installer)."/>
                <WrapPanel>
                  <Button x:Name="BtnWinUpdate" Content="Windows Update"/>
                  <Button x:Name="BtnAppUpdatesList" Content="Check app updates"/>
                  <Button x:Name="BtnAppUpdatesAll" Content="Update all apps"/>
                </WrapPanel>
              </StackPanel>
            </Border>
            <Border Style="{StaticResource Card}">
              <StackPanel>
                <TextBlock Style="{StaticResource H2}" Text="Network"/>
                <TextBlock Style="{StaticResource Note}" Text="Clearing the DNS cache can fix websites that will not load after changing networks."/>
                <WrapPanel>
                  <Button x:Name="BtnFlushDns" Content="Clear DNS cache"/>
                </WrapPanel>
              </StackPanel>
            </Border>
          </StackPanel>
        </ScrollViewer>
      </TabItem>
    </TabControl>

    <Border Grid.Row="2" Style="{StaticResource Card}" Margin="0,12,0,0" Padding="12,8">
      <DockPanel>
        <TextBlock DockPanel.Dock="Top" Text="Activity" FontWeight="SemiBold" Margin="2,0,0,4"/>
        <TextBox x:Name="LogBox" IsReadOnly="True" BorderThickness="0" Background="Transparent"
                 FontFamily="Consolas" FontSize="12" TextWrapping="Wrap" VerticalScrollBarVisibility="Auto"/>
      </DockPanel>
    </Border>

    <TextBlock x:Name="StatusText" Grid.Row="3" Margin="4,8,0,0" Foreground="#6B7280" Text="Starting..."/>
  </Grid>
</Window>
'@

# ---------------------------------------------------------------------------
# Small helpers
# ---------------------------------------------------------------------------
$BrushCache = @{}
function Get-Brush([string]$Hex) {
    if (-not $BrushCache.ContainsKey($Hex)) {
        $BrushCache[$Hex] = (New-Object System.Windows.Media.BrushConverter).ConvertFromString($Hex)
    }
    return $BrushCache[$Hex]
}

function New-Thick([double]$Left, [double]$Top, [double]$Right, [double]$Bottom) {
    return New-Object System.Windows.Thickness -ArgumentList $Left, $Top, $Right, $Bottom
}

function New-Text {
    param([string]$Text, [double]$Size = 13, [switch]$Bold, [string]$Color = '#1F2937')
    $tb = New-Object System.Windows.Controls.TextBlock
    $tb.Text = $Text
    $tb.FontSize = $Size
    $tb.TextWrapping = [System.Windows.TextWrapping]::Wrap
    $tb.Foreground = Get-Brush $Color
    if ($Bold) { $tb.FontWeight = [System.Windows.FontWeights]::SemiBold }
    return $tb
}

function Format-Size([double]$Bytes) {
    if ($Bytes -ge 1GB) { return '{0:N1} GB' -f ($Bytes / 1GB) }
    if ($Bytes -ge 1MB) { return '{0:N0} MB' -f ($Bytes / 1MB) }
    if ($Bytes -ge 1KB) { return '{0:N0} KB' -f ($Bytes / 1KB) }
    return '{0:N0} bytes' -f $Bytes
}

function Format-Duration([TimeSpan]$Span) {
    if ($Span.TotalDays -ge 1) { return '{0} days, {1} hours' -f [int][math]::Floor($Span.TotalDays), $Span.Hours }
    return '{0} hours, {1} minutes' -f $Span.Hours, $Span.Minutes
}

# Lets the window redraw while a longer job runs on the same thread.
function Update-UI {
    $window.Dispatcher.Invoke([Action] {}, [System.Windows.Threading.DispatcherPriority]::Background)
}

function Set-Status([string]$Text) {
    $ui.StatusText.Text = $Text
    Update-UI
}

function Write-Log([string]$Message) {
    $ui.LogBox.AppendText(('{0}  {1}' -f (Get-Date -Format 'HH:mm:ss'), $Message) + [Environment]::NewLine)
    $ui.LogBox.ScrollToEnd()
    try { Add-Content -Path $LogFile -Value ('{0}  {1}' -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $Message) } catch { }
}

function Show-Info([string]$Text) {
    [void][System.Windows.MessageBox]::Show($window, $Text, 'PC Manager',
        [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Information)
}

function Confirm-Action([string]$Text) {
    $answer = [System.Windows.MessageBox]::Show($window, $Text, 'PC Manager',
        [System.Windows.MessageBoxButton]::YesNo, [System.Windows.MessageBoxImage]::Question)
    return ($answer -eq [System.Windows.MessageBoxResult]::Yes)
}

function Assert-Admin([string]$What) {
    if ($script:IsAdmin) { return $true }
    Show-Info ("{0} needs administrator rights.`n`nClose PC Manager, start it again, and choose Yes when Windows asks for permission." -f $What)
    return $false
}

function Open-Target([string]$Target) {
    try {
        Start-Process $Target
    } catch {
        Write-Log ('Could not open {0}: {1}' -f $Target, $_.Exception.Message)
    }
}

# Runs a job in its own PowerShell window so the main window stays usable.
# The new window inherits administrator rights from PC Manager.
function Start-ToolWindow([string]$Title, [string]$Command) {
    $body = @"
`$Host.UI.RawUI.WindowTitle = 'PC Manager - $Title'
Write-Host '$Title' -ForegroundColor Cyan
Write-Host ''
$Command
Write-Host ''
Write-Host 'Finished.' -ForegroundColor Green
Read-Host 'Press Enter to close this window'
"@
    $encoded = [Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($body))
    Start-Process -FilePath 'powershell.exe' -ArgumentList @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-EncodedCommand', $encoded)
    Write-Log ('Started in a separate window: {0}' -f $Title)
}

function New-ReportPath([string]$Name) {
    $dir = Join-Path ([Environment]::GetFolderPath('MyDocuments')) 'PC Manager Reports'
    New-Item -ItemType Directory -Path $dir -Force | Out-Null
    return Join-Path $dir ('{0}-{1}.html' -f $Name, (Get-Date -Format 'yyyy-MM-dd-HHmm'))
}

# Runs a button's job: one at a time, with a wait cursor, and errors go to the
# Activity box instead of crashing the window.
function Invoke-Action {
    param([string]$What, [scriptblock]$Action, $Argument)
    if ($script:Busy) {
        # A tick box was clicked mid-job: put it back the way it was.
        if ($Argument -is [System.Windows.Controls.Primitives.ToggleButton]) {
            $Argument.IsChecked = -not ($Argument.IsChecked -eq $true)
        }
        Set-Status 'Still working on the last task - please wait a moment.'
        return
    }
    $script:Busy = $true
    $window.Cursor = [System.Windows.Input.Cursors]::Wait
    try {
        & $Action $Argument
    } catch {
        Write-Log ('Problem while {0}: {1}' -f $What, $_.Exception.Message)
        Set-Status 'Something went wrong - see Activity below.'
    } finally {
        $window.Cursor = $null
        $script:Busy = $false
    }
}

# ---------------------------------------------------------------------------
# Registry helpers (plain .NET, so value names are never treated as wildcards)
# ---------------------------------------------------------------------------
function Split-RegPath([string]$Path) {
    $parts = $Path -split ':\\', 2
    switch ($parts[0]) {
        'HKLM' { $root = [Microsoft.Win32.Registry]::LocalMachine }
        'HKCU' { $root = [Microsoft.Win32.Registry]::CurrentUser }
        default { throw "Unsupported registry path: $Path" }
    }
    return @($root, $parts[1])
}

function Get-RegValue([string]$Path, [string]$Name) {
    $root, $sub = Split-RegPath $Path
    $key = $root.OpenSubKey($sub)
    if ($null -eq $key) { return $null }
    try { $value = $key.GetValue($Name) } finally { $key.Close() }
    # The comma keeps byte arrays in one piece.
    return , $value
}

function Set-RegValue([string]$Path, [string]$Name, $Value, [Microsoft.Win32.RegistryValueKind]$Kind) {
    $root, $sub = Split-RegPath $Path
    $key = $root.CreateSubKey($sub)
    try { $key.SetValue($Name, $Value, $Kind) } finally { $key.Close() }
}

function Remove-RegValue([string]$Path, [string]$Name) {
    $root, $sub = Split-RegPath $Path
    $key = $root.OpenSubKey($sub, $true)
    if ($null -eq $key) { return }
    try { $key.DeleteValue($Name, $false) } finally { $key.Close() }
}

# ---------------------------------------------------------------------------
# Overview
# ---------------------------------------------------------------------------
function Get-SystemSnapshot {
    $os = Get-CimInstance -ClassName Win32_OperatingSystem
    $cs = Get-CimInstance -ClassName Win32_ComputerSystem
    $cpus = @(Get-CimInstance -ClassName Win32_Processor)
    $load = ($cpus | Measure-Object -Property LoadPercentage -Average).Average
    $displayVersion = Get-RegValue 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion' 'DisplayVersion'
    if (-not $displayVersion) { $displayVersion = Get-RegValue 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion' 'ReleaseId' }
    return [pscustomobject]@{
        OS             = ($os.Caption -replace '^Microsoft\s+', '')
        DisplayVersion = $displayVersion
        Build          = $os.BuildNumber
        Model          = ('{0} {1}' -f $cs.Manufacturer, $cs.Model).Trim()
        Cpu            = ($cpus[0].Name -replace '\s+', ' ').Trim()
        CpuLoad        = $load
        RamTotal       = [double]$os.TotalVisibleMemorySize * 1KB
        RamFree        = [double]$os.FreePhysicalMemory * 1KB
        Uptime         = (Get-Date) - $os.LastBootUpTime
        Disks          = @(Get-CimInstance -ClassName Win32_LogicalDisk -Filter 'DriveType=3')
    }
}

function Get-BatteryInfo {
    $battery = Get-CimInstance -ClassName Win32_Battery -ErrorAction SilentlyContinue | Select-Object -First 1
    if (-not $battery) { return $null }
    $info = [pscustomobject]@{
        Charge  = $battery.EstimatedChargeRemaining
        Plugged = (@(2, 3, 6, 7, 8, 9) -contains [int]$battery.BatteryStatus)
        Design  = $null
        Full    = $null
        Health  = $null
    }
    try {
        $design = (Get-CimInstance -Namespace 'root\wmi' -ClassName BatteryStaticData -ErrorAction Stop | Select-Object -First 1).DesignedCapacity
        $full = (Get-CimInstance -Namespace 'root\wmi' -ClassName BatteryFullChargedCapacity -ErrorAction Stop | Select-Object -First 1).FullChargedCapacity
        if ($design -gt 0 -and $full -gt 0) {
            $info.Design = $design
            $info.Full = $full
            $info.Health = [int][math]::Min(100, [math]::Round($full * 100 / $design))
        }
    } catch { }
    return $info
}

function Get-LevelColor([double]$Percent) {
    if ($Percent -ge 90) { return '#DC2626' }
    if ($Percent -ge 75) { return '#D97706' }
    return '#2563EB'
}

function Add-InfoRow($Panel, [string]$Label, [string]$Value) {
    $grid = New-Object System.Windows.Controls.Grid
    $grid.Margin = New-Thick 0 0 0 6
    $c1 = New-Object System.Windows.Controls.ColumnDefinition
    $c1.Width = New-Object System.Windows.GridLength -ArgumentList 130
    $c2 = New-Object System.Windows.Controls.ColumnDefinition
    $grid.ColumnDefinitions.Add($c1)
    $grid.ColumnDefinitions.Add($c2)
    $labelText = New-Text $Label -Color '#6B7280'
    $valueText = New-Text $Value
    [System.Windows.Controls.Grid]::SetColumn($valueText, 1)
    [void]$grid.Children.Add($labelText)
    [void]$grid.Children.Add($valueText)
    [void]$Panel.Children.Add($grid)
}

function Add-Meter($Panel, [string]$Label, [double]$Percent, [string]$Detail) {
    $grid = New-Object System.Windows.Controls.Grid
    $grid.Margin = New-Thick 0 0 0 10
    foreach ($width in 130, 0, 240) {
        $col = New-Object System.Windows.Controls.ColumnDefinition
        if ($width -gt 0) {
            $col.Width = New-Object System.Windows.GridLength -ArgumentList $width
        } else {
            $col.Width = New-Object System.Windows.GridLength -ArgumentList 1, ([System.Windows.GridUnitType]::Star)
        }
        $grid.ColumnDefinitions.Add($col)
    }
    $bar = New-Object System.Windows.Controls.ProgressBar
    $bar.Minimum = 0
    $bar.Maximum = 100
    $bar.Value = [math]::Max(0, [math]::Min(100, $Percent))
    $bar.Height = 14
    $bar.VerticalAlignment = [System.Windows.VerticalAlignment]::Center
    $bar.Margin = New-Thick 0 0 14 0
    $bar.Foreground = Get-Brush (Get-LevelColor $Percent)
    $bar.Background = Get-Brush '#E5E7EB'
    $bar.BorderThickness = New-Thick 0 0 0 0
    $detailText = New-Text $Detail -Color '#4B5563'
    [System.Windows.Controls.Grid]::SetColumn($bar, 1)
    [System.Windows.Controls.Grid]::SetColumn($detailText, 2)
    [void]$grid.Children.Add((New-Text $Label))
    [void]$grid.Children.Add($bar)
    [void]$grid.Children.Add($detailText)
    [void]$Panel.Children.Add($grid)
}

function Add-Tip($Panel, [string]$Level, [string]$Text) {
    $colors = @{ good = '#16A34A'; info = '#2563EB'; warn = '#D97706'; bad = '#DC2626' }
    $border = New-Object System.Windows.Controls.Border
    $border.BorderBrush = Get-Brush $colors[$Level]
    $border.BorderThickness = New-Thick 4 0 0 0
    $border.Background = Get-Brush '#F9FAFB'
    $border.Padding = New-Thick 12 8 12 8
    $border.Margin = New-Thick 0 0 0 8
    $border.Child = New-Text $Text
    [void]$Panel.Children.Add($border)
}

function Update-Overview {
    Set-Status 'Checking your PC...'
    $snap = Get-SystemSnapshot
    $battery = Get-BatteryInfo
    $startupOn = @(Get-StartupItems | Where-Object { $_.Enabled }).Count

    # This PC
    $ui.InfoPanel.Children.Clear()
    $windowsText = $snap.OS
    if ($snap.DisplayVersion) { $windowsText += ' ' + $snap.DisplayVersion }
    Add-InfoRow $ui.InfoPanel 'Windows' ('{0} (build {1})' -f $windowsText, $snap.Build)
    Add-InfoRow $ui.InfoPanel 'Device' $snap.Model
    Add-InfoRow $ui.InfoPanel 'Processor' $snap.Cpu
    Add-InfoRow $ui.InfoPanel 'Memory' (Format-Size $snap.RamTotal)
    Add-InfoRow $ui.InfoPanel 'Last restart' ('{0} ago' -f (Format-Duration $snap.Uptime))
    if ($battery) {
        $batteryText = '{0}% charged' -f $battery.Charge
        if ($battery.Plugged) { $batteryText += ', plugged in' } else { $batteryText += ', on battery' }
        if ($battery.Health) { $batteryText += ('. Health {0}%' -f $battery.Health) }
        Add-InfoRow $ui.InfoPanel 'Battery' $batteryText
    }

    # Usage
    $ui.UsagePanel.Children.Clear()
    $ramUsed = $snap.RamTotal - $snap.RamFree
    $ramPct = if ($snap.RamTotal -gt 0) { $ramUsed * 100 / $snap.RamTotal } else { 0 }
    Add-Meter $ui.UsagePanel 'Memory' $ramPct ('{0} of {1} in use' -f (Format-Size $ramUsed), (Format-Size $snap.RamTotal))
    if ($null -ne $snap.CpuLoad) {
        Add-Meter $ui.UsagePanel 'Processor' $snap.CpuLoad ('{0:N0}% busy' -f $snap.CpuLoad)
    }
    foreach ($disk in $snap.Disks) {
        if (-not $disk.Size) { continue }
        $usedPct = ($disk.Size - $disk.FreeSpace) * 100 / $disk.Size
        Add-Meter $ui.UsagePanel ('Drive {0}' -f $disk.DeviceID) $usedPct ('{0} free of {1}' -f (Format-Size $disk.FreeSpace), (Format-Size $disk.Size))
    }

    # Suggestions
    $ui.TipsPanel.Children.Clear()
    $tips = 0
    foreach ($disk in $snap.Disks) {
        if (-not $disk.Size) { continue }
        $freePct = $disk.FreeSpace * 100 / $disk.Size
        if ($freePct -lt 10) {
            Add-Tip $ui.TipsPanel 'bad' ('Drive {0} is almost full ({1} free). Windows slows down when space runs out - go to Clean up.' -f $disk.DeviceID, (Format-Size $disk.FreeSpace))
            $tips++
        } elseif ($freePct -lt 20) {
            Add-Tip $ui.TipsPanel 'warn' ('Drive {0} is getting full ({1} free). Clean up can free some space.' -f $disk.DeviceID, (Format-Size $disk.FreeSpace))
            $tips++
        }
    }
    if ($ramPct -ge 85) {
        Add-Tip $ui.TipsPanel 'warn' ('Memory is {0:N0}% used. Close apps you are not using - see Apps & processes for the biggest ones.' -f $ramPct)
        $tips++
    }
    if ($snap.Uptime.TotalDays -ge 7) {
        Add-Tip $ui.TipsPanel 'warn' ('Your laptop has not restarted for {0} days. Use Restart (not Shut down) now and then - it clears memory and finishes installing updates.' -f [int][math]::Floor($snap.Uptime.TotalDays))
        $tips++
    }
    if ($startupOn -ge 8) {
        Add-Tip $ui.TipsPanel 'warn' ('{0} apps start by themselves when you sign in. Turning off the ones you do not need makes start-up faster - see Startup apps.' -f $startupOn)
        $tips++
    }
    if ($battery -and $battery.Health) {
        if ($battery.Health -lt 60) {
            Add-Tip $ui.TipsPanel 'bad' ('Your battery only holds {0}% of its original charge. A replacement battery would bring back much longer battery life.' -f $battery.Health)
            $tips++
        } elseif ($battery.Health -lt 80) {
            Add-Tip $ui.TipsPanel 'warn' ('Your battery holds {0}% of its original charge, so it runs out sooner than when new. That is normal wear over time.' -f $battery.Health)
            $tips++
        }
    }
    if ($tips -eq 0) {
        Add-Tip $ui.TipsPanel 'good' 'Everything looks healthy. Run Quick tune-up now and then to keep it that way.'
    }
    if (-not $script:IsAdmin) {
        Add-Tip $ui.TipsPanel 'info' 'PC Manager is running without administrator rights, so some features are switched off. Restart it and choose Yes when Windows asks for permission to use everything.'
    }
    Set-Status ('Last checked at {0}.' -f (Get-Date -Format 'HH:mm'))
}

function Invoke-QuickTuneUp {
    $targets = @($CleanTargets | Where-Object { $_.Quick -and ($script:IsAdmin -or -not $_.Admin) })
    $list = ($targets | ForEach-Object { ' - ' + $_.Name }) -join "`n"
    $message = "Quick tune-up will:`n`n$list`n - Clear the DNS cache`n`nYour documents, photos, passwords and browser history are not touched. Continue?"
    if (-not (Confirm-Action $message)) { return }

    $total = 0.0
    foreach ($target in $targets) {
        Set-Status ('Cleaning: {0}...' -f $target.Name)
        $result = Clear-Target $target
        $total += $result.Freed
        Write-Log ('{0}: freed {1}' -f $target.Name, (Format-Size $result.Freed))
    }
    try {
        Clear-DnsClientCache -ErrorAction Stop
        Write-Log 'DNS cache cleared.'
    } catch {
        Write-Log 'DNS cache could not be cleared (needs administrator).'
    }
    Write-Log ('Quick tune-up finished. Freed {0} in total.' -f (Format-Size $total))
    Update-Overview
    Show-Info ('Quick tune-up finished. Freed {0}.' -f (Format-Size $total))
}

# ---------------------------------------------------------------------------
# Clean up
# ---------------------------------------------------------------------------
# Kind: files = delete matching files; wu = Windows Update cache (stops the
# update service while cleaning); do = Delivery Optimization; recycle = Recycle Bin.
$CleanTargets = @(
    [pscustomobject]@{
        Key = 'UserTemp'; Kind = 'files'; Name = 'Temporary files'
        Desc = 'Leftovers from installers and apps in your account. Files from the last 24 hours are kept in case an app still needs them.'
        Paths = @('%TEMP%'); Filter = '*'; MinAgeDays = 1; RemoveFolders = $true
        Admin = $false; Default = $true; Quick = $true
    }
    [pscustomobject]@{
        Key = 'WinTemp'; Kind = 'files'; Name = 'Windows temporary files'
        Desc = 'Temporary files made by Windows itself. Files from the last 24 hours are kept.'
        Paths = @('%SystemRoot%\Temp'); Filter = '*'; MinAgeDays = 1; RemoveFolders = $true
        Admin = $true; Default = $true; Quick = $true
    }
    [pscustomobject]@{
        Key = 'Reports'; Kind = 'files'; Name = 'Error reports and crash dumps'
        Desc = 'Crash information saved after an app or Windows had a problem.'
        Paths = @('%LOCALAPPDATA%\CrashDumps', '%LOCALAPPDATA%\Microsoft\Windows\WER', '%ProgramData%\Microsoft\Windows\WER\ReportArchive', '%ProgramData%\Microsoft\Windows\WER\ReportQueue')
        Filter = '*'; MinAgeDays = 0; RemoveFolders = $false
        Admin = $false; Default = $true; Quick = $true
    }
    [pscustomobject]@{
        Key = 'Thumbs'; Kind = 'files'; Name = 'Thumbnail cache'
        Desc = 'Small preview pictures saved by File Explorer. They are rebuilt when needed.'
        Paths = @('%LOCALAPPDATA%\Microsoft\Windows\Explorer'); Filter = 'thumbcache_*.db'; MinAgeDays = 0; RemoveFolders = $false
        Admin = $false; Default = $true; Quick = $true
    }
    [pscustomobject]@{
        Key = 'Browser'; Kind = 'files'; Name = 'Web browser cache'
        Desc = 'Saved copies of web pages in Chrome, Edge, Brave and Firefox. Passwords, history and sign-ins are kept. Sites load a little slower the first time afterwards.'
        Paths = @(
            '%LOCALAPPDATA%\Google\Chrome\User Data\*\Cache',
            '%LOCALAPPDATA%\Google\Chrome\User Data\*\Code Cache',
            '%LOCALAPPDATA%\Google\Chrome\User Data\*\GPUCache',
            '%LOCALAPPDATA%\Microsoft\Edge\User Data\*\Cache',
            '%LOCALAPPDATA%\Microsoft\Edge\User Data\*\Code Cache',
            '%LOCALAPPDATA%\Microsoft\Edge\User Data\*\GPUCache',
            '%LOCALAPPDATA%\BraveSoftware\Brave-Browser\User Data\*\Cache',
            '%LOCALAPPDATA%\BraveSoftware\Brave-Browser\User Data\*\Code Cache',
            '%LOCALAPPDATA%\BraveSoftware\Brave-Browser\User Data\*\GPUCache',
            '%LOCALAPPDATA%\Mozilla\Firefox\Profiles\*\cache2'
        )
        Filter = '*'; MinAgeDays = 0; RemoveFolders = $false
        Admin = $false; Default = $false; Quick = $false
    }
    [pscustomobject]@{
        Key = 'UpdateCache'; Kind = 'wu'; Name = 'Windows Update downloads'
        Desc = 'Installer files for updates that are already installed. Windows downloads them again if it ever needs to.'
        Paths = @('%SystemRoot%\SoftwareDistribution\Download'); Filter = '*'; MinAgeDays = 0; RemoveFolders = $false
        Admin = $true; Default = $true; Quick = $false
    }
    [pscustomobject]@{
        Key = 'DeliveryOpt'; Kind = 'do'; Name = 'Delivery Optimization files'
        Desc = 'Pieces of updates Windows keeps to share with other PCs.'
        Paths = @('%SystemRoot%\ServiceProfiles\NetworkService\AppData\Local\Microsoft\Windows\DeliveryOptimization\Cache'); Filter = '*'; MinAgeDays = 0; RemoveFolders = $false
        Admin = $true; Default = $true; Quick = $false
    }
    [pscustomobject]@{
        Key = 'RecycleBin'; Kind = 'recycle'; Name = 'Recycle Bin'
        Desc = 'Files you deleted earlier. Once emptied, you cannot get them back - check it first.'
        Paths = @(); Filter = '*'; MinAgeDays = 0; RemoveFolders = $false
        Admin = $false; Default = $false; Quick = $false
    }
)

function Get-TargetRoots($Target) {
    if ($Target.Kind -eq 'recycle') {
        $sid = [Security.Principal.WindowsIdentity]::GetCurrent().User.Value
        foreach ($drive in @(Get-CimInstance -ClassName Win32_LogicalDisk -Filter 'DriveType=3' -ErrorAction SilentlyContinue)) {
            $path = '{0}\$Recycle.Bin\{1}' -f $drive.DeviceID, $sid
            if (Test-Path -LiteralPath $path -PathType Container) { $path }
        }
        return
    }
    foreach ($pattern in $Target.Paths) {
        $expanded = [Environment]::ExpandEnvironmentVariables($pattern)
        if ($expanded -match '[\*\?]') {
            foreach ($item in @(Get-Item -Path $expanded -Force -ErrorAction SilentlyContinue)) {
                if ($item.PSIsContainer) { $item.FullName }
            }
        } elseif (Test-Path -LiteralPath $expanded -PathType Container) {
            $expanded
        }
    }
}

# Walks a folder tree without following links or junctions, so nothing outside
# the folder can ever be reached.
function Get-FilesSafe([string]$Root, [string]$Filter, [datetime]$Cutoff) {
    $pending = New-Object 'System.Collections.Generic.Stack[string]'
    $pending.Push($Root)
    $visited = 0
    while ($pending.Count -gt 0) {
        $dir = New-Object System.IO.DirectoryInfo -ArgumentList $pending.Pop()
        try {
            foreach ($file in $dir.EnumerateFiles($Filter)) {
                if ($file.LastWriteTime -lt $Cutoff) { $file }
            }
        } catch { }
        try {
            foreach ($sub in $dir.EnumerateDirectories()) {
                if (($sub.Attributes -band [System.IO.FileAttributes]::ReparsePoint) -eq 0) { $pending.Push($sub.FullName) }
            }
        } catch { }
        $visited++
        if (($visited % 50) -eq 0) { Update-UI }
    }
}

function Get-TargetFiles($Target) {
    $cutoff = (Get-Date).AddDays(-[double]$Target.MinAgeDays)
    foreach ($root in @(Get-TargetRoots $Target)) {
        Get-FilesSafe -Root $root -Filter $Target.Filter -Cutoff $cutoff
    }
}

function Measure-Target($Target) {
    $bytes = 0.0
    $count = 0
    foreach ($file in @(Get-TargetFiles $Target)) {
        $bytes += $file.Length
        $count++
    }
    return [pscustomobject]@{ Bytes = $bytes; Count = $count }
}

# Removes empty sub-folders (never the root itself, never links).
function Remove-EmptyFolders([string]$Root, [datetime]$Cutoff) {
    $all = New-Object 'System.Collections.Generic.List[System.IO.DirectoryInfo]'
    $pending = New-Object 'System.Collections.Generic.Stack[string]'
    $pending.Push($Root)
    while ($pending.Count -gt 0) {
        $dir = New-Object System.IO.DirectoryInfo -ArgumentList $pending.Pop()
        try {
            foreach ($sub in $dir.EnumerateDirectories()) {
                if (($sub.Attributes -band [System.IO.FileAttributes]::ReparsePoint) -eq 0) {
                    $all.Add($sub)
                    $pending.Push($sub.FullName)
                }
            }
        } catch { }
    }
    # Deepest first, so parent folders can become empty too.
    foreach ($dir in ($all | Sort-Object -Property { $_.FullName.Length } -Descending)) {
        try {
            if ($dir.LastWriteTime -lt $Cutoff) { $dir.Delete() }   # only succeeds when empty
        } catch { }
    }
}

function Remove-TargetFiles($Target) {
    $freed = 0.0
    $deleted = 0
    $skipped = 0
    $i = 0
    foreach ($file in @(Get-TargetFiles $Target)) {
        $size = $file.Length
        try {
            if ($file.IsReadOnly) { $file.IsReadOnly = $false }
            $file.Delete()
            $freed += $size
            $deleted++
        } catch {
            $skipped++
        }
        $i++
        if (($i % 200) -eq 0) { Update-UI }
    }
    if ($Target.RemoveFolders) {
        $cutoff = (Get-Date).AddDays(-[double]$Target.MinAgeDays)
        foreach ($root in @(Get-TargetRoots $Target)) { Remove-EmptyFolders -Root $root -Cutoff $cutoff }
    }
    return [pscustomobject]@{ Freed = $freed; Deleted = $deleted; Skipped = $skipped }
}

function Clear-Target($Target) {
    switch ($Target.Kind) {
        'recycle' {
            $before = (Measure-Target $Target).Bytes
            Clear-RecycleBin -Force -ErrorAction SilentlyContinue
            $after = (Measure-Target $Target).Bytes
            return [pscustomobject]@{ Freed = [math]::Max(0, $before - $after); Deleted = 0; Skipped = 0 }
        }
        'do' {
            if (Get-Command -Name 'Delete-DeliveryOptimizationCache' -ErrorAction SilentlyContinue) {
                $before = (Measure-Target $Target).Bytes
                Delete-DeliveryOptimizationCache -Force -ErrorAction SilentlyContinue | Out-Null
                $after = (Measure-Target $Target).Bytes
                return [pscustomobject]@{ Freed = [math]::Max(0, $before - $after); Deleted = 0; Skipped = 0 }
            }
            return Remove-TargetFiles $Target
        }
        'wu' {
            # The update service holds these files open, so pause it while cleaning.
            Stop-Service -Name 'wuauserv', 'bits' -Force -ErrorAction SilentlyContinue
            try {
                return Remove-TargetFiles $Target
            } finally {
                Start-Service -Name 'wuauserv', 'bits' -ErrorAction SilentlyContinue
            }
        }
        default {
            return Remove-TargetFiles $Target
        }
    }
}

function Initialize-CleanList {
    $script:CleanChecks = @{}
    $script:CleanSizeText = @{}
    $script:CleanBytes = @{}
    $ui.CleanPanel.Children.Clear()
    foreach ($target in $CleanTargets) {
        $row = New-Object System.Windows.Controls.DockPanel
        $row.Margin = New-Thick 0 0 0 12

        $size = New-Text '-' -Bold -Color '#374151'
        $size.Width = 90
        $size.TextAlignment = [System.Windows.TextAlignment]::Right
        [System.Windows.Controls.DockPanel]::SetDock($size, [System.Windows.Controls.Dock]::Right)
        [void]$row.Children.Add($size)

        $check = New-Object System.Windows.Controls.CheckBox
        $check.IsChecked = $target.Default
        $text = New-Object System.Windows.Controls.StackPanel
        $text.Margin = New-Thick 4 0 0 0
        [void]$text.Children.Add((New-Text $target.Name -Bold))
        $desc = $target.Desc
        if ($target.Admin -and -not $script:IsAdmin) {
            $check.IsChecked = $false
            $check.IsEnabled = $false
            $desc += ' (Needs administrator.)'
        }
        [void]$text.Children.Add((New-Text $desc -Size 12 -Color '#6B7280'))
        $check.Content = $text
        $check.Add_Click({ Update-CleanSummary })
        [void]$row.Children.Add($check)

        $script:CleanChecks[$target.Key] = $check
        $script:CleanSizeText[$target.Key] = $size
        [void]$ui.CleanPanel.Children.Add($row)
    }
}

function Update-CleanSummary {
    if ($script:CleanBytes.Count -eq 0) { return }
    $total = 0.0
    foreach ($target in $CleanTargets) {
        if ($script:CleanChecks[$target.Key].IsChecked -eq $true -and $script:CleanBytes.ContainsKey($target.Key)) {
            $total += $script:CleanBytes[$target.Key]
        }
    }
    $ui.CleanSummary.Text = 'About {0} can be freed from the ticked items.' -f (Format-Size $total)
}

function Invoke-CleanScan {
    $script:CleanBytes = @{}
    foreach ($target in $CleanTargets) {
        $label = $script:CleanSizeText[$target.Key]
        if ($target.Admin -and -not $script:IsAdmin) { $label.Text = 'n/a'; continue }
        $label.Text = '...'
        Set-Status ('Scanning: {0}...' -f $target.Name)
        $measure = Measure-Target $target
        $script:CleanBytes[$target.Key] = $measure.Bytes
        $label.Text = Format-Size $measure.Bytes
    }
    Update-CleanSummary
    Set-Status 'Scan finished.'
}

function Invoke-CleanSelected {
    $selected = @($CleanTargets | Where-Object {
            $check = $script:CleanChecks[$_.Key]
            $check.IsEnabled -and $check.IsChecked -eq $true
        })
    if ($selected.Count -eq 0) { Show-Info 'Tick at least one item first.'; return }
    $list = ($selected | ForEach-Object { ' - ' + $_.Name }) -join "`n"
    if (-not (Confirm-Action "Delete the files in:`n`n$list`n`nThis cannot be undone. Continue?")) { return }

    $total = 0.0
    foreach ($target in $selected) {
        Set-Status ('Cleaning: {0}...' -f $target.Name)
        $result = Clear-Target $target
        $total += $result.Freed
        $line = '{0}: freed {1}' -f $target.Name, (Format-Size $result.Freed)
        if ($result.Skipped -gt 0) { $line += (' ({0} files in use were skipped)' -f $result.Skipped) }
        Write-Log $line
    }
    Write-Log ('Clean up finished. Freed {0} in total.' -f (Format-Size $total))
    Invoke-CleanScan
    Set-Status ('Clean up finished. Freed {0}.' -f (Format-Size $total))
}

# ---------------------------------------------------------------------------
# Startup apps
# Uses the same "StartupApproved" switches as Task Manager, so turning an app
# off here shows as Disabled there too, and the app's own entry is untouched.
# ---------------------------------------------------------------------------
$ApprovedBase = 'Software\Microsoft\Windows\CurrentVersion\Explorer\StartupApproved'
$StartupSources = @(
    @{ Label = 'Starts for you'; RunKey = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run'; Approved = "HKCU:\$ApprovedBase\Run"; Admin = $false }
    @{ Label = 'Starts for everyone on this PC'; RunKey = 'HKLM:\Software\Microsoft\Windows\CurrentVersion\Run'; Approved = "HKLM:\$ApprovedBase\Run"; Admin = $true }
    @{ Label = 'Starts for everyone on this PC (32-bit)'; RunKey = 'HKLM:\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\Run'; Approved = "HKLM:\$ApprovedBase\Run32"; Admin = $true }
    @{ Label = 'Your Startup folder'; Folder = [Environment]::GetFolderPath('Startup'); Approved = "HKCU:\$ApprovedBase\StartupFolder"; Admin = $false }
    @{ Label = 'Startup folder for everyone'; Folder = [Environment]::GetFolderPath('CommonStartup'); Approved = "HKLM:\$ApprovedBase\StartupFolder"; Admin = $true }
)

function Test-StartupEnabled([string]$ApprovedKey, [string]$ValueName) {
    $value = Get-RegValue $ApprovedKey $ValueName
    if ($value -is [byte[]] -and $value.Length -gt 0) {
        # Odd first byte (03, 07) = turned off; even (02, 06) = on.
        return (($value[0] -band 1) -eq 0)
    }
    return $true
}

function Set-StartupEnabled($Item, [bool]$Enable) {
    if ($Enable) {
        $bytes = [byte[]](2, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
    } else {
        $stamp = [BitConverter]::GetBytes((Get-Date).ToFileTimeUtc())
        $bytes = [byte[]](@(3, 0, 0, 0) + $stamp)
    }
    Set-RegValue $Item.ApprovedKey $Item.ValueName $bytes 'Binary'
}

function Get-StartupItems {
    foreach ($source in $StartupSources) {
        if ($source.RunKey) {
            $root, $sub = Split-RegPath $source.RunKey
            $key = $root.OpenSubKey($sub)
            if ($key) {
                try {
                    foreach ($name in $key.GetValueNames()) {
                        if ([string]::IsNullOrEmpty($name)) { continue }
                        [pscustomobject]@{
                            Name        = $name
                            Command     = [string]$key.GetValue($name)
                            Source      = $source.Label
                            ApprovedKey = $source.Approved
                            ValueName   = $name
                            Admin       = $source.Admin
                            Enabled     = (Test-StartupEnabled $source.Approved $name)
                        }
                    }
                } finally {
                    $key.Close()
                }
            }
        }
        if ($source.Folder -and (Test-Path -LiteralPath $source.Folder)) {
            foreach ($file in @(Get-ChildItem -LiteralPath $source.Folder -File -Force -ErrorAction SilentlyContinue)) {
                if ($file.Name -eq 'desktop.ini') { continue }
                $target = $file.FullName
                if ($file.Extension -eq '.lnk') {
                    try { $target = $script:WShell.CreateShortcut($file.FullName).TargetPath } catch { }
                }
                [pscustomobject]@{
                    Name        = $file.BaseName
                    Command     = $target
                    Source      = $source.Label
                    ApprovedKey = $source.Approved
                    ValueName   = $file.Name
                    Admin       = $source.Admin
                    Enabled     = (Test-StartupEnabled $source.Approved $file.Name)
                }
            }
        }
    }
}

function Update-StartupList {
    $panel = $ui.StartupPanel
    $panel.Children.Clear()
    $items = @(Get-StartupItems | Sort-Object -Property Name)
    if ($items.Count -eq 0) {
        [void]$panel.Children.Add((New-Text 'No startup apps found. Nice and lean!'))
        $ui.StartupSummary.Text = ''
        return
    }
    foreach ($item in $items) {
        $check = New-Object System.Windows.Controls.CheckBox
        $check.IsChecked = $item.Enabled
        $check.Tag = $item
        $check.Margin = New-Thick 0 0 0 12
        $text = New-Object System.Windows.Controls.StackPanel
        $text.Margin = New-Thick 4 0 0 0
        [void]$text.Children.Add((New-Text $item.Name -Bold))
        $where = $item.Source
        if ($item.Admin -and -not $script:IsAdmin) {
            $check.IsEnabled = $false
            $where += ' - needs administrator to change'
        }
        [void]$text.Children.Add((New-Text $where -Size 12 -Color '#6B7280'))
        if ($item.Command) { [void]$text.Children.Add((New-Text $item.Command -Size 11 -Color '#9CA3AF')) }
        $check.Content = $text
        $check.Add_Click({
                param($s, $e)
                Invoke-Action 'changing a startup app' { param($box) Set-StartupFromCheckbox $box } $s
            })
        [void]$panel.Children.Add($check)
    }
    Update-StartupSummary
}

function Update-StartupSummary {
    $boxes = @($ui.StartupPanel.Children | Where-Object { $_ -is [System.Windows.Controls.CheckBox] })
    $on = @($boxes | Where-Object { $_.IsChecked -eq $true }).Count
    $ui.StartupSummary.Text = '{0} of {1} apps start automatically when you sign in.' -f $on, $boxes.Count
}

function Set-StartupFromCheckbox($Box) {
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
        Write-Log ('Startup: "{0}" will start with Windows again.' -f $item.Name)
    } else {
        Write-Log ('Startup: "{0}" will no longer start with Windows.' -f $item.Name)
    }
    Update-StartupSummary
}

# ---------------------------------------------------------------------------
# Apps and processes
# ---------------------------------------------------------------------------
# Parts of Windows (and PC Manager itself) that should never be ended from here.
$ProtectedProcesses = @(
    'System', 'Idle', 'Registry', 'Secure System', 'Memory Compression', 'smss', 'csrss', 'wininit', 'winlogon',
    'services', 'lsass', 'LsaIso', 'svchost', 'dwm', 'explorer', 'fontdrvhost', 'sihost', 'ctfmon', 'conhost',
    'MsMpEng', 'NisSrv', 'SecurityHealthService', 'SgrmBroker', 'spoolsv', 'audiodg', 'WUDFHost', 'dllhost',
    'taskhostw', 'RuntimeBroker', 'smartscreen', 'StartMenuExperienceHost', 'ShellExperienceHost', 'SearchHost',
    'TextInputHost', 'powershell', 'pwsh'
)

function Update-ProcessList {
    Set-Status 'Measuring what your apps are using (takes a second)...'
    $cores = [Environment]::ProcessorCount
    $before = @{}
    foreach ($p in Get-Process) {
        try { $before[$p.Id] = $p.TotalProcessorTime.TotalMilliseconds } catch { }
    }
    $timer = [System.Diagnostics.Stopwatch]::StartNew()
    while ($timer.ElapsedMilliseconds -lt 1000) {
        Update-UI
        Start-Sleep -Milliseconds 50
    }
    $elapsed = $timer.Elapsed.TotalMilliseconds

    $rows = foreach ($group in (Get-Process | Group-Object -Property ProcessName)) {
        $memory = 0.0
        $cpu = 0.0
        $desc = $null
        foreach ($p in $group.Group) {
            $memory += $p.WorkingSet64
            try {
                if ($before.ContainsKey($p.Id)) { $cpu += $p.TotalProcessorTime.TotalMilliseconds - $before[$p.Id] }
            } catch { }
            if (-not $desc) { try { $desc = $p.Description } catch { } }
        }
        [pscustomobject]@{
            Name        = $group.Name
            Description = $desc
            MemoryMB    = [int][math]::Round($memory / 1MB)
            Cpu         = [math]::Round([math]::Max(0, $cpu) * 100 / ($elapsed * $cores), 1)
            Count       = $group.Count
        }
    }
    $rows = @($rows | Sort-Object -Property MemoryMB -Descending)
    $ui.ProcList.ItemsSource = $rows
    $totalMb = ($rows | Measure-Object -Property MemoryMB -Sum).Sum
    $ui.ProcSummary.Text = '{0} apps and background tasks, using {1} of memory.' -f $rows.Count, (Format-Size ($totalMb * 1MB))
    $script:ProcLoaded = $true
    Set-Status ('Apps measured at {0}.' -f (Get-Date -Format 'HH:mm:ss'))
}

function Stop-SelectedApp {
    $row = $ui.ProcList.SelectedItem
    if (-not $row) { Show-Info 'Click an app in the list first.'; return }
    if ($ProtectedProcesses -contains $row.Name) {
        Show-Info ('{0} is part of Windows (or PC Manager itself), so it cannot be ended here.' -f $row.Name)
        return
    }
    $message = "End {0}?`n`nThis closes {1} process(es) straight away. Anything unsaved in that app will be lost." -f $row.Name, $row.Count
    if (-not (Confirm-Action $message)) { return }
    $ended = 0
    $failed = 0
    foreach ($p in @(Get-Process -Name $row.Name -ErrorAction SilentlyContinue)) {
        if ($p.Id -eq $PID) { continue }
        try { $p.Kill(); $ended++ } catch { $failed++ }
    }
    $line = 'Ended {0} ({1} process(es))' -f $row.Name, $ended
    if ($failed -gt 0) { $line += ('; {0} could not be ended (may need administrator)' -f $failed) }
    Write-Log $line
    Update-ProcessList
}

# ---------------------------------------------------------------------------
# Power and battery
# ---------------------------------------------------------------------------
$PlanNotes = @{
    '381b4222-f694-41f0-9685-ff5bb260df2e' = 'Recommended. Full speed when you need it, saves power when idle.'
    '8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c' = 'Faster response, but uses more battery and runs warmer.'
    'a1841308-3541-4fab-bc81-f71556f20b4a' = 'Longest battery life, but slower.'
    'e9a42b02-d5df-448d-aa00-03f14749eb61' = 'Maximum speed. Meant for desktops - drains a laptop battery quickly.'
}

function Get-PowerPlans {
    $output = & powercfg.exe /list 2>$null
    foreach ($line in $output) {
        if ($line -match '([0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12})\s+\((.+)\)\s*(\*)?\s*$') {
            [pscustomobject]@{ Guid = $Matches[1].ToLower(); Name = $Matches[2]; Active = [bool]$Matches[3] }
        }
    }
}

function Update-Power {
    # Power plans
    $ui.PlanPanel.Children.Clear()
    $plans = @(Get-PowerPlans)
    if ($plans.Count -eq 0) {
        [void]$ui.PlanPanel.Children.Add((New-Text 'Could not read the power plans on this PC.' -Color '#6B7280'))
    }
    foreach ($plan in $plans) {
        $radio = New-Object System.Windows.Controls.RadioButton
        $radio.GroupName = 'PowerPlans'
        $radio.IsChecked = $plan.Active
        $radio.Tag = $plan
        $radio.Margin = New-Thick 0 0 0 10
        $text = New-Object System.Windows.Controls.StackPanel
        $text.Margin = New-Thick 4 0 0 0
        [void]$text.Children.Add((New-Text $plan.Name -Bold))
        if ($PlanNotes.ContainsKey($plan.Guid)) {
            [void]$text.Children.Add((New-Text $PlanNotes[$plan.Guid] -Size 12 -Color '#6B7280'))
        }
        $radio.Content = $text
        $radio.Add_Click({
                param($s, $e)
                Invoke-Action 'switching power plan' { param($r) Set-PowerPlanFromRadio $r } $s
            })
        [void]$ui.PlanPanel.Children.Add($radio)
    }

    # Battery
    $ui.BatteryPanel.Children.Clear()
    $battery = Get-BatteryInfo
    if (-not $battery) {
        [void]$ui.BatteryPanel.Children.Add((New-Text 'No battery found on this PC.' -Color '#6B7280'))
        return
    }
    $charge = '{0}%' -f $battery.Charge
    if ($battery.Plugged) { $charge += ' (plugged in)' } else { $charge += ' (on battery)' }
    Add-InfoRow $ui.BatteryPanel 'Charge' $charge
    if ($battery.Health) {
        Add-InfoRow $ui.BatteryPanel 'Health' ('{0}% of its original capacity ({1:N0} of {2:N0} mWh)' -f $battery.Health, $battery.Full, $battery.Design)
    } else {
        Add-InfoRow $ui.BatteryPanel 'Health' 'Not available here - open the battery report for details.'
    }
}

function Set-PowerPlanFromRadio($Radio) {
    $plan = $Radio.Tag
    & powercfg.exe /setactive $plan.Guid | Out-Null
    if ($LASTEXITCODE -ne 0) {
        Update-Power
        throw 'Windows did not accept the power plan change.'
    }
    Write-Log ('Power plan set to "{0}".' -f $plan.Name)
    Set-Status ('Power plan: {0}' -f $plan.Name)
}

function Add-HighPerformancePlan {
    $plans = @(Get-PowerPlans)
    if ($plans | Where-Object { $_.Guid -eq '8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c' -or $_.Name -eq 'High performance' }) {
        Show-Info 'A High performance plan is already in the list.'
        return
    }
    & powercfg.exe -duplicatescheme 8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c | Out-Null
    if ($LASTEXITCODE -ne 0) {
        Show-Info 'This laptop does not offer a High performance plan. Use Power mode settings and pick Best performance instead.'
        return
    }
    Write-Log 'Added the High performance power plan. Pick it in the list to use it.'
    Update-Power
}

function New-BatteryReport {
    $out = New-ReportPath 'battery-report'
    Set-Status 'Creating battery report...'
    & powercfg.exe /batteryreport /output "$out" | Out-Null
    if (Test-Path -LiteralPath $out) {
        Write-Log ('Battery report saved to {0}' -f $out)
        Open-Target $out
    } else {
        Write-Log 'Windows could not create a battery report on this PC.'
    }
    Set-Status 'Ready.'
}

# ---------------------------------------------------------------------------
# Tweaks
# Get returns $true when the feature is ON. Set takes $true (on) or $false (off).
# ---------------------------------------------------------------------------
$Tweaks = @(
    @{
        Name = 'Transparency effects'; Suggest = 'Suggested: off'; Admin = $false; Restart = $false
        Desc = 'See-through taskbar, Start menu and windows. Turning it off saves a little battery and graphics power.'
        Get  = { (Get-RegValue 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize' 'EnableTransparency') -ne 0 }
        Set  = { param($on) Set-RegValue 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize' 'EnableTransparency' ([int]$on) 'DWord' }
    }
    @{
        Name = 'Game Mode'; Suggest = 'Suggested: on'; Admin = $false; Restart = $false
        Desc = 'While you play, Windows puts the game first and holds back background work such as installing updates.'
        Get  = { (Get-RegValue 'HKCU:\Software\Microsoft\GameBar' 'AutoGameModeEnabled') -ne 0 }
        Set  = {
            param($on)
            Set-RegValue 'HKCU:\Software\Microsoft\GameBar' 'AutoGameModeEnabled' ([int]$on) 'DWord'
            Set-RegValue 'HKCU:\Software\Microsoft\GameBar' 'AllowAutoGameMode' ([int]$on) 'DWord'
        }
    }
    @{
        Name = 'Game capture (Xbox Game Bar recording)'; Suggest = 'Suggested: off, unless you record clips'; Admin = $false; Restart = $false
        Desc = 'Lets Game Bar record clips and screenshots of games. Turning it off can raise frame rates a little.'
        Get  = {
            ((Get-RegValue 'HKCU:\System\GameConfigStore' 'GameDVR_Enabled') -ne 0) -and
            ((Get-RegValue 'HKCU:\Software\Microsoft\Windows\CurrentVersion\GameDVR' 'AppCaptureEnabled') -ne 0)
        }
        Set  = {
            param($on)
            Set-RegValue 'HKCU:\System\GameConfigStore' 'GameDVR_Enabled' ([int]$on) 'DWord'
            Set-RegValue 'HKCU:\Software\Microsoft\Windows\CurrentVersion\GameDVR' 'AppCaptureEnabled' ([int]$on) 'DWord'
            if (-not $on) { Set-RegValue 'HKCU:\Software\Microsoft\Windows\CurrentVersion\GameDVR' 'HistoricalCaptureEnabled' 0 'DWord' }
        }
    }
    @{
        Name = 'Windows tips and suggestions'; Suggest = 'Suggested: off'; Admin = $false; Restart = $false
        Desc = 'Tips, app suggestions and "get even more out of Windows" pop-ups. Off means fewer interruptions and less background activity.'
        Get  = { (Get-RegValue 'HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager' 'SubscribedContent-338389Enabled') -ne 0 }
        Set  = {
            param($on)
            foreach ($name in 'SubscribedContent-338389Enabled', 'SubscribedContent-338388Enabled', 'SubscribedContent-310093Enabled', 'SubscribedContent-353698Enabled', 'SoftLandingEnabled', 'SystemPaneSuggestionsEnabled') {
                Set-RegValue 'HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager' $name ([int]$on) 'DWord'
            }
        }
    }
    @{
        Name = 'Storage Sense'; Suggest = 'Suggested: on'; Admin = $false; Restart = $false
        Desc = 'Windows automatically clears temporary files and old Recycle Bin items when space runs low.'
        Get  = { (Get-RegValue 'HKCU:\Software\Microsoft\Windows\CurrentVersion\StorageSense\Parameters\StoragePolicy' '01') -eq 1 }
        Set  = { param($on) Set-RegValue 'HKCU:\Software\Microsoft\Windows\CurrentVersion\StorageSense\Parameters\StoragePolicy' '01' ([int]$on) 'DWord' }
    }
    @{
        Name = 'Store apps in the background'; Suggest = 'Your choice: off saves battery'; Admin = $true; Restart = $false
        Desc = 'Lets Microsoft Store apps (Mail, Weather, Phone Link and others) keep working when closed. Off saves battery, but those apps may only update and notify you while open.'
        Get  = { (Get-RegValue 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\AppPrivacy' 'LetAppsRunInBackground') -ne 2 }
        Set  = {
            param($on)
            if ($on) { Remove-RegValue 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\AppPrivacy' 'LetAppsRunInBackground' }
            else { Set-RegValue 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\AppPrivacy' 'LetAppsRunInBackground' 2 'DWord' }
        }
    }
    @{
        Name = 'Hardware-accelerated GPU scheduling'; Suggest = 'Suggested: on for gaming'; Admin = $true; Restart = $true
        Desc = 'Lets the graphics card manage its own work, which can smooth out games. Does nothing on graphics cards that do not support it.'
        Get  = { (Get-RegValue 'HKLM:\SYSTEM\CurrentControlSet\Control\GraphicsDrivers' 'HwSchMode') -eq 2 }
        Set  = {
            param($on)
            $mode = if ($on) { 2 } else { 1 }
            Set-RegValue 'HKLM:\SYSTEM\CurrentControlSet\Control\GraphicsDrivers' 'HwSchMode' $mode 'DWord'
        }
    }
    @{
        Name = 'Hibernation'; Suggest = 'Suggested: on, unless you are short on space'; Admin = $true; Restart = $false
        Desc = 'Lets your laptop save its state to disk when the battery runs low (and powers Fast Startup). Turning it off frees several GB (the hiberfil.sys file).'
        Get  = {
            $value = Get-RegValue 'HKLM:\SYSTEM\CurrentControlSet\Control\Power' 'HibernateEnabled'
            if ($null -ne $value) { $value -eq 1 } else { Test-Path -LiteralPath "$env:SystemDrive\hiberfil.sys" }
        }
        Set  = {
            param($on)
            $state = if ($on) { 'on' } else { 'off' }
            & powercfg.exe /hibernate $state | Out-Null
            if ($LASTEXITCODE -ne 0) { throw 'Windows did not accept the hibernation change.' }
        }
    }
)

function Update-Tweaks {
    $ui.TweakPanel.Children.Clear()
    foreach ($tweak in $Tweaks) {
        $check = New-Object System.Windows.Controls.CheckBox
        $check.Tag = $tweak
        $check.Margin = New-Thick 0 0 0 14
        try {
            $check.IsChecked = [bool](& $tweak.Get)
        } catch {
            $check.IsChecked = $false
            $check.IsEnabled = $false
        }
        $text = New-Object System.Windows.Controls.StackPanel
        $text.Margin = New-Thick 4 0 0 0
        $title = New-Object System.Windows.Controls.WrapPanel
        [void]$title.Children.Add((New-Text $tweak.Name -Bold))
        $hint = New-Text ('   ' + $tweak.Suggest) -Size 12 -Color '#2563EB'
        [void]$title.Children.Add($hint)
        [void]$text.Children.Add($title)
        $desc = $tweak.Desc
        if ($tweak.Restart) { $desc += ' Needs a restart.' }
        if ($tweak.Admin -and -not $script:IsAdmin) {
            $check.IsEnabled = $false
            $desc += ' (Needs administrator.)'
        }
        [void]$text.Children.Add((New-Text $desc -Size 12 -Color '#6B7280'))
        $check.Content = $text
        $check.Add_Click({
                param($s, $e)
                Invoke-Action 'changing a tweak' { param($box) Set-TweakFromCheckbox $box } $s
            })
        [void]$ui.TweakPanel.Children.Add($check)
    }
}

function Set-TweakFromCheckbox($Box) {
    $tweak = $Box.Tag
    $on = ($Box.IsChecked -eq $true)
    try {
        & $tweak.Set $on
    } catch {
        $Box.IsChecked = -not $on
        throw
    }
    $state = if ($on) { 'on' } else { 'off' }
    $line = '{0} turned {1}.' -f $tweak.Name, $state
    if ($tweak.Restart) { $line += ' Restart your laptop to apply it.' }
    Write-Log $line
    Set-Status $line
}

# ---------------------------------------------------------------------------
# Maintenance
# ---------------------------------------------------------------------------
function Start-RestorePoint {
    if (-not (Assert-Admin 'Creating a restore point')) { return }
    $command = @'
Write-Host 'Creating a restore point. This can take a minute...'
try {
    Checkpoint-Computer -Description 'PC Manager' -RestorePointType 'MODIFY_SETTINGS' -ErrorAction Stop -WarningVariable skipped
    if ($skipped) {
        Write-Host 'Windows skipped it: it only allows one restore point every 24 hours, and one was made recently.' -ForegroundColor Yellow
    } else {
        Write-Host 'Restore point created.' -ForegroundColor Green
    }
} catch {
    Write-Host ('Could not create a restore point: ' + $_.Exception.Message) -ForegroundColor Red
    Write-Host 'System Protection may be turned off. Opening its settings: select your C: drive, click Configure, and choose "Turn on system protection".'
    Start-Process SystemPropertiesProtection.exe
}
'@
    Start-ToolWindow 'Create restore point' $command
}

function Show-DriveHealth {
    $disks = @(Get-PhysicalDisk -ErrorAction Stop)
    if ($disks.Count -eq 0) { Write-Log 'No drives found.'; return }
    foreach ($disk in $disks) {
        $line = 'Drive "{0}": {1} ({2}, {3})' -f $disk.FriendlyName, $disk.HealthStatus, $disk.MediaType, (Format-Size $disk.Size)
        try {
            $counters = $disk | Get-StorageReliabilityCounter -ErrorAction Stop
            if ($null -ne $counters.Wear) { $line += (', {0}% worn' -f $counters.Wear) }
            if ($counters.Temperature) { $line += (', {0} C' -f $counters.Temperature) }
        } catch { }
        Write-Log $line
    }
    Set-Status 'Drive health written to Activity below. "Healthy" means no problems found.'
}

function Test-Winget {
    if (Get-Command -Name 'winget.exe' -ErrorAction SilentlyContinue) { return $true }
    Show-Info 'winget is not installed. Get "App Installer" from the Microsoft Store, then try again.'
    return $false
}

# ---------------------------------------------------------------------------
# Build the window and connect the buttons
# ---------------------------------------------------------------------------
try {
    $window = [Windows.Markup.XamlReader]::Load((New-Object System.Xml.XmlNodeReader $Xaml))
    $ui = @{}
    $xamlNs = 'http://schemas.microsoft.com/winfx/2006/xaml'
    $nsManager = New-Object System.Xml.XmlNamespaceManager $Xaml.NameTable
    $nsManager.AddNamespace('x', $xamlNs)
    foreach ($node in $Xaml.SelectNodes('//*[@x:Name]', $nsManager)) {
        $name = $node.GetAttribute('Name', $xamlNs)
        $ui[$name] = $window.FindName($name)
    }

    if (-not $script:IsAdmin) {
        $ui.AdminBadge.Background = Get-Brush '#FEF3C7'
        $ui.AdminText.Foreground = Get-Brush '#92400E'
        $ui.AdminText.Text = 'Limited mode - restart and allow admin for all features'
    }

    # Overview
    $ui.BtnQuickTune.Add_Click({ Invoke-Action 'running the quick tune-up' { Invoke-QuickTuneUp } })
    $ui.BtnRefreshOverview.Add_Click({ Invoke-Action 'checking your PC' { Update-Overview } })

    # Clean up
    $ui.BtnCleanScan.Add_Click({ Invoke-Action 'scanning' { Invoke-CleanScan } })
    $ui.BtnCleanRun.Add_Click({ Invoke-Action 'cleaning' { Invoke-CleanSelected } })
    $ui.BtnDiskCleanup.Add_Click({ Open-Target 'cleanmgr.exe'; Write-Log 'Opened Windows Disk Cleanup.' })
    $ui.BtnStorageSettings.Add_Click({ Open-Target 'ms-settings:storagesense' })

    # Startup apps
    $ui.BtnStartupRefresh.Add_Click({ Invoke-Action 'reading startup apps' { Update-StartupList } })
    $ui.BtnStartupStore.Add_Click({ Open-Target 'ms-settings:startupapps' })
    $ui.BtnTaskManager.Add_Click({ Open-Target 'taskmgr.exe' })

    # Apps and processes
    $script:ProcLoaded = $false
    $ui.BtnProcRefresh.Add_Click({ Invoke-Action 'measuring apps' { Update-ProcessList } })
    $ui.BtnProcEnd.Add_Click({ Invoke-Action 'ending an app' { Stop-SelectedApp } })
    $ui.Tabs.Add_SelectionChanged({
            param($s, $e)
            if ($e.OriginalSource -ne $ui.Tabs) { return }
            if ($ui.Tabs.SelectedItem -eq $ui.TabProcesses -and -not $script:ProcLoaded) {
                Invoke-Action 'measuring apps' { Update-ProcessList }
            }
        })

    # Power and battery
    $ui.BtnPowerMode.Add_Click({ Open-Target 'ms-settings:powersleep' })
    $ui.BtnAddHighPerf.Add_Click({ Invoke-Action 'adding a power plan' { Add-HighPerformancePlan } })
    $ui.BtnBatteryReport.Add_Click({ Invoke-Action 'creating the battery report' { New-BatteryReport } })
    $ui.BtnEnergyReport.Add_Click({
            if (-not (Assert-Admin 'The energy check')) { return }
            $out = New-ReportPath 'energy-report'
            $command = @'
Write-Host 'Watching your laptop for 60 seconds. Leave it idle for the most useful result...'
powercfg.exe /energy /output "{OUT}" | Out-Host
if (Test-Path -LiteralPath "{OUT}") { Start-Process "{OUT}" }
'@
            Start-ToolWindow 'Energy check' ($command.Replace('{OUT}', $out))
        })

    # Tweaks
    $ui.BtnTweaksRefresh.Add_Click({ Invoke-Action 'reading tweaks' { Update-Tweaks } })
    $ui.BtnVisualEffects.Add_Click({ Open-Target 'SystemPropertiesPerformance.exe' })

    # Maintenance
    $ui.BtnRestorePoint.Add_Click({ Start-RestorePoint })
    $ui.BtnRestoreOpen.Add_Click({ Open-Target 'rstrui.exe' })
    $ui.BtnDism.Add_Click({
            if (-not (Assert-Admin 'Repairing the Windows image')) { return }
            Start-ToolWindow 'Repair Windows image' 'DISM.exe /Online /Cleanup-Image /RestoreHealth'
        })
    $ui.BtnSfc.Add_Click({
            if (-not (Assert-Admin 'Checking system files')) { return }
            Start-ToolWindow 'Check system files' 'sfc.exe /scannow'
        })
    $ui.BtnOptimize.Add_Click({
            if (-not (Assert-Admin 'Optimizing drives')) { return }
            $command = @'
foreach ($volume in @(Get-Volume | Where-Object { $_.DriveType -eq 'Fixed' -and $_.DriveLetter })) {
    Write-Host ('Optimizing drive {0}: ...' -f $volume.DriveLetter) -ForegroundColor Cyan
    Optimize-Volume -DriveLetter $volume.DriveLetter -Verbose
}
'@
            Start-ToolWindow 'Optimize drives' $command
        })
    $ui.BtnDriveHealth.Add_Click({ Invoke-Action 'checking drive health' { Show-DriveHealth } })
    $ui.BtnChkdsk.Add_Click({
            if (-not (Assert-Admin 'Scanning for drive errors')) { return }
            Start-ToolWindow 'Scan system drive for errors (read-only)' "chkdsk.exe $env:SystemDrive"
        })
    $ui.BtnWinUpdate.Add_Click({ Open-Target 'ms-settings:windowsupdate' })
    $ui.BtnAppUpdatesList.Add_Click({
            if (-not (Test-Winget)) { return }
            Start-ToolWindow 'App updates available' 'winget.exe upgrade --accept-source-agreements'
        })
    $ui.BtnAppUpdatesAll.Add_Click({
            if (-not (Test-Winget)) { return }
            if (-not (Confirm-Action "Update every app that winget knows about?`n`nSome installers may open their own windows. Save your work and close the apps first.")) { return }
            Start-ToolWindow 'Update all apps' 'winget.exe upgrade --all --accept-source-agreements --accept-package-agreements'
        })
    $ui.BtnFlushDns.Add_Click({
            Invoke-Action 'clearing the DNS cache' {
                Clear-DnsClientCache -ErrorAction Stop
                Write-Log 'DNS cache cleared.'
                Set-Status 'DNS cache cleared.'
            }
        })

    # Fill everything in once the window is on screen.
    $window.Add_ContentRendered({
            Invoke-Action 'loading' {
                if ($script:IsAdmin) {
                    Write-Log 'PC Manager started with administrator rights.'
                } else {
                    Write-Log 'PC Manager started in limited mode (no administrator rights).'
                }
                Initialize-CleanList
                Update-StartupList
                Update-Tweaks
                Update-Power
                Update-Overview
            }
        })

    [void]$window.ShowDialog()
} catch {
    [void][System.Windows.MessageBox]::Show("PC Manager could not start:`n`n$($_.Exception.Message)", 'PC Manager',
        [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Error)
    exit 1
}
