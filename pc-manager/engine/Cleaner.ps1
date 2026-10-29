# What the cleaner can remove, and how. No window code (runs in the worker).
#
# Kind: files   = delete matching files
#       wu      = Windows Update downloads (pauses the update service meanwhile)
#       do      = Delivery Optimization cache (uses Windows' own cmdlet)
#       recycle = Recycle Bin
# Glyph is the icon code shown next to the item (Segoe icon font).

$CleanTargets = @(
    [pscustomobject]@{
        Key = 'UserTemp'; Kind = 'files'; Glyph = 0xE8B7; Name = 'Temporary files'
        Desc = 'Leftovers from installers and apps. Anything from the last 24 hours is kept.'
        Paths = @('%TEMP%'); Filter = '*'; MinAgeDays = 1; RemoveFolders = $true
        Admin = $false; Default = $true; Quick = $true
    }
    [pscustomobject]@{
        Key = 'WinTemp'; Kind = 'files'; Glyph = 0xE770; Name = 'Windows temporary files'
        Desc = 'Temporary files made by Windows itself. Anything from the last 24 hours is kept.'
        Paths = @('%SystemRoot%\Temp'); Filter = '*'; MinAgeDays = 1; RemoveFolders = $true
        Admin = $true; Default = $true; Quick = $true
    }
    [pscustomobject]@{
        Key = 'Reports'; Kind = 'files'; Glyph = 0xE7BA; Name = 'Error reports and crash dumps'
        Desc = 'Crash information saved after an app or Windows had a problem.'
        Paths = @('%LOCALAPPDATA%\CrashDumps', '%LOCALAPPDATA%\Microsoft\Windows\WER', '%ProgramData%\Microsoft\Windows\WER\ReportArchive', '%ProgramData%\Microsoft\Windows\WER\ReportQueue')
        Filter = '*'; MinAgeDays = 0; RemoveFolders = $false
        Admin = $false; Default = $true; Quick = $true
    }
    [pscustomobject]@{
        Key = 'Thumbs'; Kind = 'files'; Glyph = 0xE8B9; Name = 'Thumbnail cache'
        Desc = 'Preview pictures saved by File Explorer. They are rebuilt when needed.'
        Paths = @('%LOCALAPPDATA%\Microsoft\Windows\Explorer'); Filter = 'thumbcache_*.db'; MinAgeDays = 0; RemoveFolders = $false
        Admin = $false; Default = $true; Quick = $true
    }
    [pscustomobject]@{
        Key = 'Browser'; Kind = 'files'; Glyph = 0xE774; Name = 'Web browser cache'
        Desc = 'Saved copies of web pages in Chrome, Edge, Brave and Firefox. Passwords, history and sign-ins stay. Close your browsers first.'
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
        Key = 'UpdateCache'; Kind = 'wu'; Glyph = 0xE895; Name = 'Windows Update downloads'
        Desc = 'Installer files for updates that are already installed. Windows fetches them again if it ever needs to.'
        Paths = @('%SystemRoot%\SoftwareDistribution\Download'); Filter = '*'; MinAgeDays = 0; RemoveFolders = $false
        Admin = $true; Default = $true; Quick = $false
    }
    [pscustomobject]@{
        Key = 'DeliveryOpt'; Kind = 'do'; Glyph = 0xE896; Name = 'Delivery Optimization files'
        Desc = 'Pieces of updates Windows keeps to share with other PCs.'
        Paths = @('%SystemRoot%\ServiceProfiles\NetworkService\AppData\Local\Microsoft\Windows\DeliveryOptimization\Cache'); Filter = '*'; MinAgeDays = 0; RemoveFolders = $false
        Admin = $true; Default = $true; Quick = $false
    }
    [pscustomobject]@{
        Key = 'RecycleBin'; Kind = 'recycle'; Glyph = 0xE74D; Name = 'Recycle Bin'
        Desc = 'Files you deleted earlier. Once emptied they cannot be brought back, so take a look first.'
        Paths = @(); Filter = '*'; MinAgeDays = 0; RemoveFolders = $false
        Admin = $false; Default = $false; Quick = $false
    }
)

function Get-CleanTarget([string]$Key) {
    return $CleanTargets | Where-Object { $_.Key -eq $Key } | Select-Object -First 1
}

function Get-TargetRoots($Target) {
    if ($Target.Kind -eq 'recycle') {
        $sid = [Security.Principal.WindowsIdentity]::GetCurrent().User.Value
        foreach ($drive in [System.IO.DriveInfo]::GetDrives()) {
            if ($drive.DriveType -ne 'Fixed') { continue }
            $path = '{0}$Recycle.Bin\{1}' -f $drive.RootDirectory.FullName, $sid
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
        if (($i % 200) -eq 0 -and (Test-JobCancel)) { break }
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

# Measures the given targets. Returns @{ <Key> = bytes }.
function Invoke-CleanerScan([string[]]$Keys) {
    $sizes = @{}
    $n = [math]::Max(1, $Keys.Count)
    for ($i = 0; $i -lt $Keys.Count; $i++) {
        if (Test-JobCancel) { break }
        $target = Get-CleanTarget $Keys[$i]
        Set-JobProgress ('Scanning {0}...' -f $target.Name.ToLower()) ($i * 100 / $n)
        $sizes[$target.Key] = (Measure-Target $target).Bytes
    }
    Set-JobProgress 'Scan complete' 100
    return $sizes
}

# Cleans the given targets. Returns @{ Total; Items = @( @{Key; Name; Freed; Skipped} ) }.
function Invoke-CleanerClean([string[]]$Keys) {
    $items = New-Object System.Collections.Generic.List[object]
    $total = 0.0
    $n = [math]::Max(1, $Keys.Count)
    for ($i = 0; $i -lt $Keys.Count; $i++) {
        if (Test-JobCancel) { break }
        $target = Get-CleanTarget $Keys[$i]
        Set-JobProgress ('Cleaning {0}...' -f $target.Name.ToLower()) ($i * 100 / $n)
        $result = Clear-Target $target
        $total += $result.Freed
        $items.Add([pscustomobject]@{ Key = $target.Key; Name = $target.Name; Freed = $result.Freed; Skipped = $result.Skipped })
    }
    Set-JobProgress 'Done' 100
    return [pscustomobject]@{ Total = $total; Items = $items.ToArray() }
}
