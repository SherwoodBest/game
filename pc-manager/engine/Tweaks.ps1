# Tweaks and power plans. Every tweak can be switched back.
# Get returns $true when the feature is ON. Set takes $true (on) or $false (off).
# Suggest is the recommended state ($true = on, $false = off, $null = your call).

$Tweaks = @(
    @{
        Group = 'Performance'; Name = 'Transparency effects'; Suggest = $false; Admin = $false; Restart = $false; SignOut = $false
        Desc  = 'See-through taskbar, Start menu and windows. Off saves a little battery and graphics power.'
        Get   = { (Get-RegValue 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize' 'EnableTransparency') -ne 0 }
        Set   = { param($on) Set-RegValue 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize' 'EnableTransparency' ([int]$on) 'DWord' }
    }
    @{
        Group = 'Performance'; Name = 'Window and taskbar animations'; Suggest = $null; Admin = $false; Restart = $false; SignOut = $true
        Desc  = 'Zoom and slide effects when windows open, close and minimize. Off makes older laptops feel snappier.'
        Get   = { (Get-RegValue 'HKCU:\Control Panel\Desktop\WindowMetrics' 'MinAnimate') -ne '0' }
        Set   = {
            param($on)
            Set-RegValue 'HKCU:\Control Panel\Desktop\WindowMetrics' 'MinAnimate' ([string][int]$on) 'String'
            Set-RegValue 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced' 'TaskbarAnimations' ([int]$on) 'DWord'
        }
    }
    @{
        Group = 'Performance'; Name = 'Web results in Start search'; Suggest = $false; Admin = $false; Restart = $false; SignOut = $true
        Desc  = 'Bing suggestions when you search from Start or the taskbar. Off makes searching your PC faster and more private.'
        Get   = { (Get-RegValue 'HKCU:\Software\Policies\Microsoft\Windows\Explorer' 'DisableSearchBoxSuggestions') -ne 1 }
        Set   = {
            param($on)
            if ($on) { Remove-RegValue 'HKCU:\Software\Policies\Microsoft\Windows\Explorer' 'DisableSearchBoxSuggestions' }
            else { Set-RegValue 'HKCU:\Software\Policies\Microsoft\Windows\Explorer' 'DisableSearchBoxSuggestions' 1 'DWord' }
        }
    }
    @{
        Group = 'Gaming'; Name = 'Game Mode'; Suggest = $true; Admin = $false; Restart = $false; SignOut = $false
        Desc  = 'While you play, Windows puts the game first and holds back background work such as installing updates.'
        Get   = { (Get-RegValue 'HKCU:\Software\Microsoft\GameBar' 'AutoGameModeEnabled') -ne 0 }
        Set   = {
            param($on)
            Set-RegValue 'HKCU:\Software\Microsoft\GameBar' 'AutoGameModeEnabled' ([int]$on) 'DWord'
            Set-RegValue 'HKCU:\Software\Microsoft\GameBar' 'AllowAutoGameMode' ([int]$on) 'DWord'
        }
    }
    @{
        Group = 'Gaming'; Name = 'Game capture'; Suggest = $false; Admin = $false; Restart = $false; SignOut = $false
        Desc  = 'Xbox Game Bar clip and screenshot recording. Off can raise frame rates a little. Keep it on if you record clips.'
        Get   = {
            ((Get-RegValue 'HKCU:\System\GameConfigStore' 'GameDVR_Enabled') -ne 0) -and
            ((Get-RegValue 'HKCU:\Software\Microsoft\Windows\CurrentVersion\GameDVR' 'AppCaptureEnabled') -ne 0)
        }
        Set   = {
            param($on)
            Set-RegValue 'HKCU:\System\GameConfigStore' 'GameDVR_Enabled' ([int]$on) 'DWord'
            Set-RegValue 'HKCU:\Software\Microsoft\Windows\CurrentVersion\GameDVR' 'AppCaptureEnabled' ([int]$on) 'DWord'
            if (-not $on) { Set-RegValue 'HKCU:\Software\Microsoft\Windows\CurrentVersion\GameDVR' 'HistoricalCaptureEnabled' 0 'DWord' }
        }
    }
    @{
        Group = 'Gaming'; Name = 'Hardware-accelerated GPU scheduling'; Suggest = $true; Admin = $true; Restart = $true; SignOut = $false
        Desc  = 'Lets the graphics card manage its own work, which can smooth out games. Does nothing on cards that do not support it.'
        Get   = { (Get-RegValue 'HKLM:\SYSTEM\CurrentControlSet\Control\GraphicsDrivers' 'HwSchMode') -eq 2 }
        Set   = {
            param($on)
            $mode = if ($on) { 2 } else { 1 }
            Set-RegValue 'HKLM:\SYSTEM\CurrentControlSet\Control\GraphicsDrivers' 'HwSchMode' $mode 'DWord'
        }
    }
    @{
        Group = 'Battery'; Name = 'Store apps in the background'; Suggest = $null; Admin = $true; Restart = $false; SignOut = $false
        Desc  = 'Lets Microsoft Store apps such as Mail, Weather and Phone Link keep working when closed. Off saves battery, but they only update while open.'
        Get   = { (Get-RegValue 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\AppPrivacy' 'LetAppsRunInBackground') -ne 2 }
        Set   = {
            param($on)
            if ($on) { Remove-RegValue 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\AppPrivacy' 'LetAppsRunInBackground' }
            else { Set-RegValue 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\AppPrivacy' 'LetAppsRunInBackground' 2 'DWord' }
        }
    }
    @{
        Group = 'Battery'; Name = 'Hibernation'; Suggest = $true; Admin = $true; Restart = $false; SignOut = $false
        Desc  = 'Saves your work to disk when the battery runs low, and powers Fast Startup. Off frees several GB, so only turn it off if space is tight.'
        Get   = {
            $value = Get-RegValue 'HKLM:\SYSTEM\CurrentControlSet\Control\Power' 'HibernateEnabled'
            if ($null -ne $value) { $value -eq 1 } else { Test-Path -LiteralPath "$env:SystemDrive\hiberfil.sys" }
        }
        Set   = {
            param($on)
            $state = if ($on) { 'on' } else { 'off' }
            & powercfg.exe /hibernate $state | Out-Null
            if ($LASTEXITCODE -ne 0) { throw 'Windows did not accept the hibernation change.' }
        }
    }
    @{
        Group = 'Fewer distractions'; Name = 'Windows tips and suggestions'; Suggest = $false; Admin = $false; Restart = $false; SignOut = $false
        Desc  = 'Tips, suggested apps and "finish setting up" prompts in Start, Settings and notifications.'
        Get   = { (Get-RegValue 'HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager' 'SubscribedContent-338389Enabled') -ne 0 }
        Set   = {
            param($on)
            foreach ($name in 'SubscribedContent-338389Enabled', 'SubscribedContent-338388Enabled', 'SubscribedContent-310093Enabled',
                'SubscribedContent-338393Enabled', 'SubscribedContent-353694Enabled', 'SubscribedContent-353696Enabled',
                'SubscribedContent-353698Enabled', 'SoftLandingEnabled', 'SystemPaneSuggestionsEnabled') {
                Set-RegValue 'HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager' $name ([int]$on) 'DWord'
            }
            Set-RegValue 'HKCU:\Software\Microsoft\Windows\CurrentVersion\UserProfileEngagement' 'ScoobeSystemSettingEnabled' ([int]$on) 'DWord'
        }
    }
    @{
        Group = 'Storage'; Name = 'Storage Sense'; Suggest = $true; Admin = $false; Restart = $false; SignOut = $false
        Desc  = 'Windows clears temporary files and old Recycle Bin items on its own when space runs low.'
        Get   = { (Get-RegValue 'HKCU:\Software\Microsoft\Windows\CurrentVersion\StorageSense\Parameters\StoragePolicy' '01') -eq 1 }
        Set   = { param($on) Set-RegValue 'HKCU:\Software\Microsoft\Windows\CurrentVersion\StorageSense\Parameters\StoragePolicy' '01' ([int]$on) 'DWord' }
    }
)

# --- Power plans ---------------------------------------------------------------

$PlanInfo = @{
    '381b4222-f694-41f0-9685-ff5bb260df2e' = @{ Glyph = 0xE945; Note = 'Recommended. Full speed when you need it, saves power when idle.' }
    '8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c' = @{ Glyph = 0xEC4A; Note = 'Faster response, but uses more battery and runs warmer.' }
    'a1841308-3541-4fab-bc81-f71556f20b4a' = @{ Glyph = 0xE83F; Note = 'Longest battery life, but slower.' }
    'e9a42b02-d5df-448d-aa00-03f14749eb61' = @{ Glyph = 0xEC4A; Note = 'Maximum speed. Meant for desktops; drains a laptop battery quickly.' }
}

function Get-PowerPlans {
    $output = & powercfg.exe /list 2>$null
    foreach ($line in $output) {
        if ($line -match '([0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12})\s+\((.+)\)\s*(\*)?\s*$') {
            $guid = $Matches[1].ToLower()
            $info = $PlanInfo[$guid]
            [pscustomobject]@{
                Guid   = $guid
                Name   = $Matches[2]
                Active = [bool]$Matches[3]
                Glyph  = $(if ($info) { $info.Glyph } else { 0xE945 })
                Note   = $(if ($info) { $info.Note } else { 'A custom power plan.' })
            }
        }
    }
}

function Set-PowerPlan([string]$Guid) {
    & powercfg.exe /setactive $Guid | Out-Null
    if ($LASTEXITCODE -ne 0) { throw 'Windows did not accept the power plan change.' }
}

# Returns 'exists', 'added' or 'unsupported'.
function Add-HighPerformancePlan {
    $plans = @(Get-PowerPlans)
    if ($plans | Where-Object { $_.Guid -eq '8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c' -or $_.Name -eq 'High performance' }) { return 'exists' }
    & powercfg.exe -duplicatescheme 8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c | Out-Null
    if ($LASTEXITCODE -ne 0) { return 'unsupported' }
    return 'added'
}
