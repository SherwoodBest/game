@echo off
rem Double-click this file to open PC Manager.
rem Windows will ask for administrator permission so every feature works.
powershell.exe -NoProfile -ExecutionPolicy Bypass -STA -File "%~dp0PCManager.ps1"
if errorlevel 1 pause
