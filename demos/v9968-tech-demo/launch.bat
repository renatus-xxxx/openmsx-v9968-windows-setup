@echo off
setlocal
set "MODE=%~1"
if not defined MODE set "MODE=fsa1gt"
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0launch.ps1" -Mode "%MODE%"
if errorlevel 1 pause
