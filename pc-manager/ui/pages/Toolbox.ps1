# Toolbox: tiles for repairs, drive checks, updates and Windows tools.

$ToolSectionsData = @(
    @{ Title = 'Safety and repair'; Tools = @(
            @{ Key = 'restore'; Glyph = 0xE74E; Title = 'Create restore point'; Text = 'A safety net before big changes.' }
            @{ Key = 'rstrui'; Glyph = 0xE81C; Title = 'System Restore'; Text = 'Roll Windows back to a restore point.' }
            @{ Key = 'dism'; Glyph = 0xE90F; Title = 'Repair Windows'; Text = 'Fixes the Windows image (10-30 min).' }
            @{ Key = 'sfc'; Glyph = 0xEA18; Title = 'Check system files'; Text = 'Finds and repairs damaged files.' }
        )
    }
    @{ Title = 'Drives'; Tools = @(
            @{ Key = 'optimize'; Glyph = 0xEDA2; Title = 'Optimize drives'; Text = 'Trims SSDs, defragments hard drives.' }
            @{ Key = 'health'; Glyph = 0xE9D9; Title = 'Drive health'; Text = 'Wear, temperature and status.' }
            @{ Key = 'chkdsk'; Glyph = 0xE721; Title = 'Scan for errors'; Text = 'Read-only check of your system drive.' }
            @{ Key = 'cleanmgr'; Glyph = 0xE74D; Title = 'Disk Cleanup'; Text = 'The classic Windows cleaner.' }
        )
    }
    @{ Title = 'Updates'; Tools = @(
            @{ Key = 'winupdate'; Glyph = 0xE895; Title = 'Windows Update'; Text = 'Security fixes and improvements.' }
            @{ Key = 'appcheck'; Glyph = 0xE896; Title = 'Check app updates'; Text = 'Lists apps with newer versions.' }
            @{ Key = 'appupdate'; Glyph = 0xE72C; Title = 'Update all apps'; Text = 'Installs every available app update.' }
        )
    }
    @{ Title = 'Network and Windows tools'; Tools = @(
            @{ Key = 'dns'; Glyph = 0xE701; Title = 'Clear DNS cache'; Text = 'Fixes sites that will not load.' }
            @{ Key = 'reliability'; Glyph = 0xE7BA; Title = 'Reliability history'; Text = 'See recent crashes and problems.' }
            @{ Key = 'devmgmt'; Glyph = 0xE772; Title = 'Device Manager'; Text = 'Drivers and hardware.' }
            @{ Key = 'taskmgr'; Glyph = 0xE8A7; Title = 'Task Manager'; Text = 'The full Windows task manager.' }
        )
    }
)

$DriveHealthJob = { Get-DriveHealth }

function Invoke-ToolAction([string]$Key) {
    switch ($Key) {
        'restore' { Start-RestorePoint }
        'rstrui' { Open-Target 'rstrui.exe' }
        'dism' {
            if (Assert-Admin 'Repairing Windows') { Start-ToolWindow 'Repair Windows' 'DISM.exe /Online /Cleanup-Image /RestoreHealth' }
        }
        'sfc' {
            if (Assert-Admin 'Checking system files') { Start-ToolWindow 'Check system files' 'sfc.exe /scannow' }
        }
        'optimize' {
            if (Assert-Admin 'Optimizing drives') {
                $command = @'
foreach ($volume in @(Get-Volume | Where-Object { $_.DriveType -eq 'Fixed' -and $_.DriveLetter })) {
    Write-Host ('  Optimizing drive {0}: ...' -f $volume.DriveLetter) -ForegroundColor Cyan
    Optimize-Volume -DriveLetter $volume.DriveLetter -Verbose
}
'@
                Start-ToolWindow 'Optimize drives' $command
            }
        }
        'health' { Start-DriveHealth }
        'chkdsk' {
            if (Assert-Admin 'Scanning for drive errors') { Start-ToolWindow 'Scan for errors (read-only)' "chkdsk.exe $env:SystemDrive" }
        }
        'cleanmgr' { Open-Target 'cleanmgr.exe' }
        'winupdate' { Open-Target 'ms-settings:windowsupdate' }
        'appcheck' {
            if (Test-Winget) { Start-ToolWindow 'App updates available' 'winget.exe upgrade --accept-source-agreements' }
        }
        'appupdate' {
            if (Test-Winget) {
                if (Confirm-Action 'Update all apps?' "Every app that winget knows about will be updated. Some installers open their own windows.`n`nSave your work and close the apps you are using first." 'Update all') {
                    Start-ToolWindow 'Update all apps' 'winget.exe upgrade --all --accept-source-agreements --accept-package-agreements'
                }
            }
        }
        'dns' {
            try {
                Clear-DnsClientCache -ErrorAction Stop
                Write-Activity 'DNS cache cleared.'
                Show-Toast 'DNS cache cleared.' 'success'
            } catch {
                if (-not $IsAdmin) { [void](Assert-Admin 'Clearing the DNS cache') }
                else { Show-Toast ('Could not clear the DNS cache: {0}' -f $_.Exception.Message) 'error' }
            }
        }
        'reliability' { Open-Target 'perfmon.exe' '/rel' }
        'devmgmt' { Open-Target 'devmgmt.msc' }
        'taskmgr' { Open-Target 'taskmgr.exe' }
    }
}

function Start-RestorePoint {
    if (-not (Assert-Admin 'Creating a restore point')) { return }
    $command = @'
Write-Host '  Creating a restore point. This can take a minute...'
try {
    Checkpoint-Computer -Description 'PC Manager' -RestorePointType 'MODIFY_SETTINGS' -ErrorAction Stop -WarningVariable skipped
    if ($skipped) {
        Write-Host '  Windows skipped it: it allows one restore point every 24 hours, and one was made recently.' -ForegroundColor Yellow
    } else {
        Write-Host '  Restore point created.' -ForegroundColor Green
    }
} catch {
    Write-Host ('  Could not create a restore point: ' + $_.Exception.Message) -ForegroundColor Red
    Write-Host '  System Protection may be off. Opening its settings: select your C: drive, click Configure, and turn it on.'
    Start-Process SystemPropertiesProtection.exe
}
'@
    Start-ToolWindow 'Create restore point' $command
}

function Test-Winget {
    if (Get-Command -Name 'winget.exe' -ErrorAction SilentlyContinue) { return $true }
    [void](Show-Dialog 'winget is not installed' 'App updates use winget, which comes with "App Installer" from the Microsoft Store. Install it there, then try again.' 'OK' '' 'info')
    return $false
}

function Start-DriveHealth {
    Show-Toast 'Checking your drives...' 'info'
    [void](Start-Work -Script $DriveHealthJob `
            -OnDone {
            param($out)
            $disks = @($out)
            if ($disks.Count -eq 0) {
                [void](Show-Dialog 'Drive health' 'No drives were found.' 'OK' '' 'info')
                return
            }
            $lines = foreach ($disk in $disks) {
                $line = '{0}  -  {1}, {2} {3}' -f $disk.Name, $disk.Health, (Format-Size $disk.Size), $(if ($disk.Media -and $disk.Media -ne 'Unspecified') { $disk.Media } else { '' })
                $extra = @()
                if ($null -ne $disk.Wear) { $extra += ('{0}% worn' -f $disk.Wear) }
                if ($disk.Temp) { $extra += ('{0} C' -f $disk.Temp) }
                if ($extra.Count -gt 0) { $line += ('  ({0})' -f ($extra -join ', ')) }
                $line
                Write-Activity ('Drive health: {0}' -f $line)
            }
            $allGood = -not ($disks | Where-Object { $_.Health -ne 'Healthy' })
            $title = $(if ($allGood) { 'Your drives are healthy' } else { 'A drive needs attention' })
            $kind = $(if ($allGood) { 'success' } else { 'warn' })
            $text = ($lines -join "`n`n")
            if (-not $allGood) { $text += "`n`nBack up your files soon. A drive that is not Healthy may fail." }
            [void](Show-Dialog $title $text 'OK' '' $kind)
        } `
            -OnError { param($err) Show-Toast ('Could not read drive health: {0}' -f $err.Message) 'error' })
}

Register-Page 'Toolbox' -Init {
    $click = {
        param($s, $e)
        Invoke-Guarded { param($b) Invoke-ToolAction ([string]$b.Tag) } $s
    }
    foreach ($section in $ToolSectionsData) {
        $title = New-Text $section.Title 15 'Text' -Bold
        $title.Margin = New-Thick 2 2 0 12
        [void]$ui.ToolSections.Children.Add($title)
        $wrap = New-Object System.Windows.Controls.WrapPanel
        $wrap.Margin = New-Thick 0 0 -14 8
        foreach ($tool in $section.Tools) {
            $tile = New-QuickTile $tool.Glyph $tool.Title $tool.Text $click $tool.Key
            $tile.Width = 232
            [void]$wrap.Children.Add($tile)
        }
        [void]$ui.ToolSections.Children.Add($wrap)
    }
}
