# System information, health score, app usage, large files, installed apps.
# No window code (most of this runs in the background worker).

function Get-DriveUsage {
    foreach ($drive in [System.IO.DriveInfo]::GetDrives()) {
        if ($drive.DriveType -ne 'Fixed' -or -not $drive.IsReady) { continue }
        $label = $drive.VolumeLabel
        if (-not $label) { $label = 'Local Disk' }
        [pscustomobject]@{
            Name   = $drive.Name.TrimEnd('\')
            Label  = $label
            Total  = [double]$drive.TotalSize
            Free   = [double]$drive.AvailableFreeSpace
            System = ($drive.Name.TrimEnd('\') -eq $env:SystemDrive)
        }
    }
}

function Get-SystemSnapshot {
    $os = Get-CimInstance -ClassName Win32_OperatingSystem
    $cs = Get-CimInstance -ClassName Win32_ComputerSystem
    $cpus = @(Get-CimInstance -ClassName Win32_Processor)
    $gpu = Get-CimInstance -ClassName Win32_VideoController -ErrorAction SilentlyContinue | Select-Object -First 1
    $load = ($cpus | Measure-Object -Property LoadPercentage -Average).Average
    $version = Get-RegValue 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion' 'DisplayVersion'
    if (-not $version) { $version = Get-RegValue 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion' 'ReleaseId' }
    $osName = $os.Caption -replace '^Microsoft\s+', ''
    if ($version) { $osName = '{0}, version {1}' -f $osName, $version }
    return [pscustomobject]@{
        ComputerName = $env:COMPUTERNAME
        OS           = $osName
        Build        = $os.BuildNumber
        Model        = ('{0} {1}' -f $cs.Manufacturer, $cs.Model).Trim()
        Cpu          = ($cpus[0].Name -replace '\s+', ' ').Trim()
        Cores        = [Environment]::ProcessorCount
        Gpu          = $(if ($gpu) { $gpu.Name } else { $null })
        CpuLoad      = $load
        RamTotal     = [double]$os.TotalVisibleMemorySize * 1KB
        RamFree      = [double]$os.FreePhysicalMemory * 1KB
        Uptime       = (Get-Date) - $os.LastBootUpTime
        Drives       = @(Get-DriveUsage)
    }
}

function Get-BatteryInfo {
    $battery = Get-CimInstance -ClassName Win32_Battery -ErrorAction SilentlyContinue | Select-Object -First 1
    if (-not $battery) { return $null }
    $info = [pscustomobject]@{
        Charge  = [int]$battery.EstimatedChargeRemaining
        Plugged = (@(2, 3, 6, 7, 8, 9) -contains [int]$battery.BatteryStatus)
        Design  = $null
        Full    = $null
        Health  = $null
        Cycles  = $null
    }
    try {
        $design = (Get-CimInstance -Namespace 'root\wmi' -ClassName BatteryStaticData -ErrorAction Stop | Select-Object -First 1).DesignedCapacity
        $full = (Get-CimInstance -Namespace 'root\wmi' -ClassName BatteryFullChargedCapacity -ErrorAction Stop | Select-Object -First 1).FullChargedCapacity
        if ($design -gt 0 -and $full -gt 0) {
            $info.Design = [double]$design
            $info.Full = [double]$full
            $info.Health = [int][math]::Min(100, [math]::Round($full * 100 / $design))
        }
    } catch { }
    try {
        $cycles = (Get-CimInstance -Namespace 'root\wmi' -ClassName BatteryCycleCount -ErrorAction Stop | Select-Object -First 1).CycleCount
        if ($cycles -gt 0) { $info.Cycles = [int]$cycles }
    } catch { }
    return $info
}

# Turns the numbers into a 0-100 score plus a list of things worth fixing.
# Action tells the window what the Fix button should do.
function Get-HealthReport($Snapshot, $Battery, [double]$JunkBytes, [int]$StartupOn) {
    $score = 100
    $issues = New-Object System.Collections.Generic.List[object]

    foreach ($drive in $Snapshot.Drives) {
        if ($drive.Total -le 0) { continue }
        $freePct = $drive.Free * 100 / $drive.Total
        if ($drive.System -and $freePct -lt 10) {
            $score -= 25
            $issues.Add([pscustomobject]@{ Level = 'bad'; Action = 'storage'; Title = ('Drive {0} is almost full' -f $drive.Name); Detail = ('Only {0} left. Windows slows down when space runs out.' -f (Format-Size $drive.Free)) })
        } elseif ($drive.System -and $freePct -lt 20) {
            $score -= 12
            $issues.Add([pscustomobject]@{ Level = 'warn'; Action = 'storage'; Title = ('Drive {0} is getting full' -f $drive.Name); Detail = ('{0} free. Clearing large files you no longer need helps.' -f (Format-Size $drive.Free)) })
        } elseif (-not $drive.System -and $freePct -lt 10) {
            $score -= 4
            $issues.Add([pscustomobject]@{ Level = 'warn'; Action = 'storage'; Title = ('Drive {0} is almost full' -f $drive.Name); Detail = ('{0} free.' -f (Format-Size $drive.Free)) })
        }
    }

    if ($JunkBytes -ge 300MB) {
        $penalty = 4
        if ($JunkBytes -ge 1GB) { $penalty = 8 }
        if ($JunkBytes -ge 5GB) { $penalty = 15 }
        $score -= $penalty
        $issues.Add([pscustomobject]@{ Level = 'warn'; Action = 'clean'; Title = ('{0} of junk files' -f (Format-Size $JunkBytes)); Detail = 'Temporary files and caches that are safe to remove.' })
    }

    if ($Snapshot.RamTotal -gt 0) {
        $ramPct = ($Snapshot.RamTotal - $Snapshot.RamFree) * 100 / $Snapshot.RamTotal
        if ($ramPct -ge 90) {
            $score -= 10
            $issues.Add([pscustomobject]@{ Level = 'bad'; Action = 'processes'; Title = ('Memory is {0:N0}% full' -f $ramPct); Detail = 'Close apps you are not using to speed things up.' })
        } elseif ($ramPct -ge 80) {
            $score -= 5
            $issues.Add([pscustomobject]@{ Level = 'warn'; Action = 'processes'; Title = ('Memory is {0:N0}% full' -f $ramPct); Detail = 'See which apps use the most memory.' })
        }
    }

    if ($StartupOn -ge 5) {
        $penalty = 4
        if ($StartupOn -ge 8) { $penalty = 8 }
        if ($StartupOn -ge 12) { $penalty = 12 }
        $score -= $penalty
        $issues.Add([pscustomobject]@{ Level = 'warn'; Action = 'startup'; Title = ('{0} apps launch at sign-in' -f $StartupOn); Detail = 'Turning off the ones you do not need makes start-up faster.' })
    }

    if ($Snapshot.Uptime.TotalDays -ge 7) {
        $score -= $(if ($Snapshot.Uptime.TotalDays -ge 14) { 8 } else { 5 })
        $issues.Add([pscustomobject]@{ Level = 'warn'; Action = 'restart'; Title = ('No restart for {0}' -f (Format-Duration $Snapshot.Uptime)); Detail = 'A restart clears memory and finishes installing updates. Use Restart, not Shut down.' })
    }

    if ($Battery -and $Battery.Health) {
        if ($Battery.Health -lt 60) {
            $score -= 8
            $issues.Add([pscustomobject]@{ Level = 'bad'; Action = 'battery'; Title = ('Battery holds {0}% of its original charge' -f $Battery.Health); Detail = 'A replacement battery would bring back much longer battery life.' })
        } elseif ($Battery.Health -lt 80) {
            $score -= 3
            $issues.Add([pscustomobject]@{ Level = 'info'; Action = 'battery'; Title = ('Battery holds {0}% of its original charge' -f $Battery.Health); Detail = 'Normal wear over time - it just runs out a bit sooner than when new.' })
        }
    }

    $score = [int][math]::Max(0, [math]::Min(100, $score))
    $label = 'Needs attention'
    if ($score -ge 55) { $label = 'Fair' }
    if ($score -ge 75) { $label = 'Good' }
    if ($score -ge 90) { $label = 'Excellent' }
    return [pscustomobject]@{ Score = $score; Label = $label; Issues = $issues.ToArray() }
}

# Samples every running app for about a second. Returns one row per app name.
function Get-ProcessUsage {
    Set-JobProgress 'Measuring apps...' 10
    $cores = [Environment]::ProcessorCount
    $before = @{}
    foreach ($p in Get-Process) {
        try { $before[$p.Id] = $p.TotalProcessorTime.TotalMilliseconds } catch { }
    }
    $timer = [System.Diagnostics.Stopwatch]::StartNew()
    Start-Sleep -Milliseconds 900
    $elapsed = $timer.Elapsed.TotalMilliseconds
    Set-JobProgress 'Reading app details...' 60

    $rows = foreach ($group in (Get-Process | Group-Object -Property ProcessName)) {
        $memory = 0.0
        $cpu = 0.0
        $desc = $null
        $path = $null
        foreach ($p in $group.Group) {
            $memory += $p.WorkingSet64
            try {
                if ($before.ContainsKey($p.Id)) { $cpu += $p.TotalProcessorTime.TotalMilliseconds - $before[$p.Id] }
            } catch { }
            if (-not $path) { try { $path = $p.Path } catch { } }
            if (-not $desc) { try { $desc = $p.Description } catch { } }
        }
        if (-not $desc) { $desc = $group.Name }
        [pscustomobject]@{
            Name        = $group.Name
            Description = $desc
            Path        = $path
            Memory      = $memory
            Cpu         = [math]::Round([math]::Max(0, $cpu) * 100 / ($elapsed * $cores), 1)
            Count       = $group.Count
        }
    }
    Set-JobProgress 'Done' 100
    return @($rows | Sort-Object -Property Memory -Descending)
}

# Finds big files in the user's own folders (AppData is left out on purpose:
# it holds app data, not your files). Cloud-only OneDrive files are skipped
# because they take no space on this PC.
function Find-LargeFiles([double]$MinBytes, [int]$Limit = 300) {
    $profileDir = $env:USERPROFILE
    $roots = @(Get-ChildItem -LiteralPath $profileDir -Directory -Force -ErrorAction SilentlyContinue |
            Where-Object { $_.Name -ne 'AppData' -and -not $_.Name.StartsWith('.') -and (($_.Attributes -band [System.IO.FileAttributes]::ReparsePoint) -eq 0) })
    $cloudMask = 0x1000 -bor 0x40000 -bor 0x400000   # Offline, RecallOnOpen, RecallOnDataAccess
    $found = New-Object System.Collections.Generic.List[object]
    $n = [math]::Max(1, $roots.Count)
    for ($i = 0; $i -lt $roots.Count; $i++) {
        if (Test-JobCancel) { break }
        Set-JobProgress ('Looking in {0}...' -f $roots[$i].Name) ($i * 100 / $n)
        foreach ($file in (Get-FilesSafe -Root $roots[$i].FullName)) {
            if ($file.Length -lt $MinBytes) { continue }
            if (([int]$file.Attributes -band $cloudMask) -ne 0) { continue }
            $found.Add([pscustomobject]@{
                    Name     = $file.Name
                    Folder   = $file.DirectoryName
                    FullName = $file.FullName
                    Size     = [double]$file.Length
                    Modified = $file.LastWriteTime
                })
        }
    }
    Set-JobProgress 'Done' 100
    return @($found | Sort-Object -Property Size -Descending | Select-Object -First $Limit)
}

function Get-InstalledApps {
    $keys = @(
        'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall',
        'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall',
        'HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall'
    )
    $seen = @{}
    foreach ($keyPath in $keys) {
        $root, $sub = Split-RegPath $keyPath
        $key = $root.OpenSubKey($sub)
        if ($null -eq $key) { continue }
        try {
            foreach ($childName in $key.GetSubKeyNames()) {
                $child = $key.OpenSubKey($childName)
                if ($null -eq $child) { continue }
                try {
                    $name = [string]$child.GetValue('DisplayName')
                    $uninstall = [string]$child.GetValue('UninstallString')
                    if (-not $name -or -not $uninstall) { continue }
                    if ($child.GetValue('SystemComponent') -eq 1) { continue }
                    if ($child.GetValue('ParentKeyName')) { continue }   # updates and patches
                    $id = $name.ToLower()
                    if ($seen.ContainsKey($id)) { continue }
                    $seen[$id] = $true
                    $installed = $null
                    $rawDate = [string]$child.GetValue('InstallDate')
                    if ($rawDate -match '^\d{8}$') {
                        try { $installed = [datetime]::ParseExact($rawDate, 'yyyyMMdd', $null) } catch { }
                    }
                    $size = $child.GetValue('EstimatedSize')
                    [pscustomobject]@{
                        Name      = $name.Trim()
                        Publisher = [string]$child.GetValue('Publisher')
                        Version   = [string]$child.GetValue('DisplayVersion')
                        Size      = $(if ($size) { [double]$size * 1KB } else { 0 })
                        Installed = $installed
                        Uninstall = $uninstall
                        Icon      = (Get-ExePath ([string]$child.GetValue('DisplayIcon')))
                    }
                } finally {
                    $child.Close()
                }
            }
        } finally {
            $key.Close()
        }
    }
}

# Starts the app's own uninstaller (it shows its own window).
function Start-AppUninstall($App) {
    $command = $App.Uninstall
    if ($command -match '(?i)msiexec(\.exe)?\s+/[IX]\s*(\{[0-9A-F\-]+\})') {
        Start-Process -FilePath 'msiexec.exe' -ArgumentList @('/X', $Matches[2])
        return
    }
    $exe = Get-ExePath $command
    if ($exe) {
        $text = [Environment]::ExpandEnvironmentVariables($command.Trim())
        if ($text.StartsWith('"')) {
            $rest = $text.Substring($text.IndexOf('"', 1) + 1).Trim()
        } else {
            $rest = $text.Substring([math]::Min($text.Length, $exe.Length)).Trim()
        }
        if ($rest) { Start-Process -FilePath $exe -ArgumentList $rest } else { Start-Process -FilePath $exe }
        return
    }
    Start-Process -FilePath 'cmd.exe' -ArgumentList @('/c', $command) -WindowStyle Hidden
}

function Get-DriveHealth {
    Set-JobProgress 'Reading drive health...' 30
    $result = foreach ($disk in @(Get-PhysicalDisk -ErrorAction Stop)) {
        $wear = $null
        $temp = $null
        try {
            $counters = $disk | Get-StorageReliabilityCounter -ErrorAction Stop
            $wear = $counters.Wear
            $temp = $counters.Temperature
        } catch { }
        [pscustomobject]@{
            Name   = $disk.FriendlyName
            Health = [string]$disk.HealthStatus
            Media  = [string]$disk.MediaType
            Size   = [double]$disk.Size
            Wear   = $wear
            Temp   = $temp
        }
    }
    Set-JobProgress 'Done' 100
    return @($result)
}
