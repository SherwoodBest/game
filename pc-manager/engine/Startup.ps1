# Startup apps. Uses the same "StartupApproved" switches as Task Manager, so
# turning an app off here shows as Disabled there too, and the app's own
# entry is left untouched (turning it back on restores it exactly).

$ApprovedBase = 'Software\Microsoft\Windows\CurrentVersion\Explorer\StartupApproved'
$StartupSources = @(
    @{ Label = 'For you'; RunKey = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run'; Approved = "HKCU:\$ApprovedBase\Run"; Admin = $false }
    @{ Label = 'For everyone'; RunKey = 'HKLM:\Software\Microsoft\Windows\CurrentVersion\Run'; Approved = "HKLM:\$ApprovedBase\Run"; Admin = $true }
    @{ Label = 'For everyone'; RunKey = 'HKLM:\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\Run'; Approved = "HKLM:\$ApprovedBase\Run32"; Admin = $true }
    @{ Label = 'Startup folder'; Folder = [Environment]::GetFolderPath('Startup'); Approved = "HKCU:\$ApprovedBase\StartupFolder"; Admin = $false }
    @{ Label = 'Startup folder, everyone'; Folder = [Environment]::GetFolderPath('CommonStartup'); Approved = "HKLM:\$ApprovedBase\StartupFolder"; Admin = $true }
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

function New-StartupItem($Name, $Command, $ExePath, $Source, $ValueName) {
    $publisher = $null
    $description = $null
    if ($ExePath) {
        try {
            $info = [System.Diagnostics.FileVersionInfo]::GetVersionInfo($ExePath)
            $publisher = $info.CompanyName
            $description = $info.FileDescription
        } catch { }
    }
    $display = $Name
    if ($description -and $description.Length -le 60) { $display = $description }
    return [pscustomobject]@{
        Name        = $display
        EntryName   = $Name
        Command     = $Command
        ExePath     = $ExePath
        Publisher   = $(if ($publisher) { $publisher.Trim() } else { 'Unknown publisher' })
        Source      = $Source.Label
        ApprovedKey = $Source.Approved
        ValueName   = $ValueName
        Admin       = $Source.Admin
        Enabled     = (Test-StartupEnabled $Source.Approved $ValueName)
    }
}

function Get-StartupItems {
    if (-not $script:ShortcutShell) { $script:ShortcutShell = New-Object -ComObject WScript.Shell }
    foreach ($source in $StartupSources) {
        if ($source.RunKey) {
            $root, $sub = Split-RegPath $source.RunKey
            $key = $root.OpenSubKey($sub)
            if ($key) {
                try {
                    foreach ($name in $key.GetValueNames()) {
                        if ([string]::IsNullOrEmpty($name)) { continue }
                        $command = [string]$key.GetValue($name)
                        New-StartupItem $name $command (Get-ExePath $command) $source $name
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
                    try { $target = $script:ShortcutShell.CreateShortcut($file.FullName).TargetPath } catch { }
                }
                $exe = $null
                if ($target -and (Test-Path -LiteralPath $target -PathType Leaf)) { $exe = $target }
                New-StartupItem $file.BaseName $target $exe $source $file.Name
            }
        }
    }
}
