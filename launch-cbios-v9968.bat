@echo off
setlocal DisableDelayedExpansion
chcp 65001 >nul
set "PSModulePath=%SystemRoot%\System32\WindowsPowerShell\v1.0\Modules"
"%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe" -NoLogo -NoProfile -STA -ExecutionPolicy Bypass -File "%~dp0scripts\entry.ps1" -Action Launch -Mode cbios
set "rc=%errorlevel%"
pause
exit /b %rc%
