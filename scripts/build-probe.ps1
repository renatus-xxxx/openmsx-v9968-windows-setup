param([string]$Z88dk,[switch]$SelectZ88dk)
$ErrorActionPreference='Stop'
. (Join-Path $PSScriptRoot 'find-z88dk.ps1')
if($Z88dk -and $SelectZ88dk){throw 'Use either -Z88dk or -SelectZ88dk / 指定方法は一つにしてください。'}
$candidates=if($SelectZ88dk){@()}else{@(Get-Z88dkCandidates)}
$tool=Resolve-Z88dk -Explicit $Z88dk -Candidates $candidates
Write-Host "z88dk: $tool"
$repo=Split-Path -Parent $PSScriptRoot
$work=Join-Path $repo ('build/probe/'+[guid]::NewGuid().ToString('N'))
[IO.Directory]::CreateDirectory($work) | Out-Null
Copy-Item -LiteralPath (Join-Path $repo 'probe/probe.c') -Destination (Join-Path $work 'probe.c')
$savedPath=$env:PATH; $savedCfg=$env:ZCCCFG
Push-Location $work
try {
 $env:PATH="$tool\bin;$env:PATH"; $env:ZCCCFG="$tool\lib\config"
 & "$tool\bin\zcc.exe" +msx -subtype=rom -compiler=sccz80 -O2 -create-app probe.c -o PROBE
 if($LASTEXITCODE -ne 0){throw 'z88dk build failed; original ROM preserved. Try an ASCII path without spaces / ビルド失敗。元の ROM は保持しました。空白のない英数字パスも確認してください。'}
 $rom=Join-Path $work 'PROBE.rom'
 if(!(Test-Path -LiteralPath $rom) -or (Get-Item -LiteralPath $rom).Length -ne 16384){throw 'Invalid build output / ビルド成果物が不正です。'}
 Copy-Item -LiteralPath $rom -Destination (Join-Path $repo 'probe/PROBE.rom') -Force
 Get-FileHash -LiteralPath (Join-Path $repo 'probe/PROBE.rom')
} finally {Pop-Location;$env:PATH=$savedPath;$env:ZCCCFG=$savedCfg}
