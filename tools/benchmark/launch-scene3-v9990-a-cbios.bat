@echo off
setlocal DisableDelayedExpansion
set "PSModulePath=%SystemRoot%\System32\WindowsPowerShell\v1.0\Modules"
"%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe" -NoProfile -ExecutionPolicy Bypass -File "%~dp0..\..\demos\scene3-v9990\launch.ps1" -Mode cbios -Variant a %*
set "result=%errorlevel%"
if not "%result%"=="0" pause
exit /b %result%
