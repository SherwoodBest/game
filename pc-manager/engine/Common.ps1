# Shared helpers. No window code here: this file is also loaded by the
# background worker that runs scans and clean-ups.

function Test-IsAdmin {
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($identity)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

# --- Progress and cancel, shared with the window through $global:Sync -------

function Set-JobProgress([string]$Text, [double]$Percent = -1) {
    if ($global:Sync) {
        $global:Sync.Text = $Text
        $global:Sync.Percent = $Percent
    }
}

function Test-JobCancel {
    return [bool]($global:Sync -and $global:Sync.Cancel)
}

# --- Formatting --------------------------------------------------------------

function Format-Size([double]$Bytes) {
    if ($Bytes -ge 1TB) { return '{0:N1} TB' -f ($Bytes / 1TB) }
    if ($Bytes -ge 1GB) { return '{0:N1} GB' -f ($Bytes / 1GB) }
    if ($Bytes -ge 1MB) { return '{0:N0} MB' -f ($Bytes / 1MB) }
    if ($Bytes -ge 1KB) { return '{0:N0} KB' -f ($Bytes / 1KB) }
    if ($Bytes -le 0) { return '0 MB' }
    return '{0:N0} bytes' -f $Bytes
}

function Format-Duration([TimeSpan]$Span) {
    if ($Span.TotalDays -ge 2) { return '{0} days' -f [int][math]::Floor($Span.TotalDays) }
    if ($Span.TotalDays -ge 1) { return '1 day, {0} hours' -f $Span.Hours }
    if ($Span.TotalHours -ge 1) { return '{0} hours, {1} min' -f $Span.Hours, $Span.Minutes }
    return '{0} minutes' -f [int][math]::Max(1, $Span.Minutes)
}

# --- Registry (plain .NET, so value names are never treated as wildcards) ----

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

# --- Files -------------------------------------------------------------------

# Walks a folder tree without following links or junctions, so nothing outside
# the folder can ever be reached. Returns FileInfo objects older than Cutoff.
function Get-FilesSafe([string]$Root, [string]$Filter = '*', [datetime]$Cutoff = [datetime]::MaxValue) {
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
        if (($visited % 64) -eq 0 -and (Test-JobCancel)) { return }
    }
}

# Pulls the program path out of a command line such as
#   "C:\Program Files\App\app.exe" --minimized   or   C:\Tools\app.exe /quiet
function Get-ExePath([string]$CommandLine) {
    if ([string]::IsNullOrWhiteSpace($CommandLine)) { return $null }
    $text = [Environment]::ExpandEnvironmentVariables($CommandLine.Trim())
    if ($text.StartsWith('"')) {
        $end = $text.IndexOf('"', 1)
        if ($end -gt 1) { $text = $text.Substring(1, $end - 1) }
    } else {
        $match = [regex]::Match($text, '^(.+?\.(exe|com|bat|cmd|lnk))(\s|,|$)', 'IgnoreCase')
        if ($match.Success) { $text = $match.Groups[1].Value }
        elseif ($text -match '^([^,]+),\s*-?\d+$') { $text = $Matches[1] }   # "file.ico,0" style
    }
    if (Test-Path -LiteralPath $text -PathType Leaf -ErrorAction SilentlyContinue) { return $text }
    return $null
}
