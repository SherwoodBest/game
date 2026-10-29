@echo off
rem Double-click to put a PC Manager icon on your desktop.
powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "$s=(New-Object -ComObject WScript.Shell).CreateShortcut([Environment]::GetFolderPath('Desktop')+'\PC Manager.lnk'); $s.TargetPath=$env:SystemRoot+'\System32\WindowsPowerShell\v1.0\powershell.exe'; $s.Arguments='-NoProfile -ExecutionPolicy Bypass -STA -WindowStyle Hidden -File \"%~dp0PCManager.ps1\"'; $s.WorkingDirectory='%~dp0'; $s.IconLocation='%~dp0icon.ico'; $s.Description='Keep your PC fast, tidy and healthy'; $s.Save()"
if errorlevel 1 (echo Could not create the shortcut.) else (echo Done - look for "PC Manager" on your desktop.)
pause
