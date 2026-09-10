@echo off
setlocal DisableDelayedExpansion
set "PSModulePath=%SystemRoot%\System32\WindowsPowerShell\v1.0\Modules"
"%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe" -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%~dp0..\..\demos\scene3-benchmark\launch.ps1" -Mode fsa1gt %*
set "rc=%errorlevel%"
if not "%rc%"=="0" pause
exit /b %rc%