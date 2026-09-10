param([Parameter(Mandatory=$true)][string]$Runtime,[switch]$Standard)
$ErrorActionPreference='Stop'
$cfg=Get-Content -LiteralPath "$Runtime/config.json" -Raw|ConvertFrom-Json
$kind=if($Standard){'standard'}else{'v9968'}
$work=Join-Path $PSScriptRoot ('test-output/'+$cfg.mode+'-'+$kind+'-'+[guid]::NewGuid().ToString('N'))
& "$PSScriptRoot/launch.ps1" -Mode $cfg.mode -Standard:$Standard -Runtime $Runtime -TestScript "$PSScriptRoot/test.tcl" -WorkRoot $work
$text=Get-Content -LiteralPath "$work/results.txt" -Raw
if($text -notmatch 'TEST=PASS' -or $text -match 'FAIL|ERROR'){throw "Benchmark validation failed: $work"}
Write-Output $text
Write-Output "Results: $work"
