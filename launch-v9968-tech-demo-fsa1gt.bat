@echo off
setlocal DisableDelayedExpansion
chcp 65001 >nul
set "PSModulePath=%SystemRoot%\System32\WindowsPowerShell\v1.0\Modules"
title V9968 TECH DEMO - fsa1gt
"%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe" -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%~dp0demos\v9968-tech-demo\launch.ps1" -Mode fsa1gt %*
set "rc=%errorlevel%"
if not "%rc%"=="0" pause
exit /b %rc%
