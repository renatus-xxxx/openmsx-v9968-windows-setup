param([Parameter(Mandatory=$true)][string]$Runtime,[switch]$CStream)
$ErrorActionPreference='Stop'
$result=& "$PSScriptRoot/test.ps1" -Runtime $Runtime -CStream:$CStream -CaptureScript "$PSScriptRoot/capture-shallow.tcl" -PassThru
python "$PSScriptRoot/verify-shallow-render.py" --captures $result.WorkDirectory
if($LASTEXITCODE -ne 0){throw 'Shallow water pixel verification failed'}
Write-Host $result.WorkDirectory
