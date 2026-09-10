param([Parameter(Mandatory=$true)][string]$Z88dk)
$ErrorActionPreference='Stop'
$shared=Join-Path (Split-Path $PSScriptRoot -Parent) 'v9968-tech-demo'
$out=Join-Path $PSScriptRoot 'build'
if(!(Test-Path -LiteralPath "$Z88dk/bin/zcc.exe")){throw 'Specify the z88dk root using -Z88dk.'}
python "$shared/generate-fonts.py"
if($LASTEXITCODE -ne 0){throw 'Font generation failed'}
python "$shared/generate-megarom.py"
if($LASTEXITCODE -ne 0){throw 'Data generation failed'}
[IO.Directory]::CreateDirectory($out)|Out-Null
Copy-Item "$shared/*.h","$shared/v9968.c","$shared/platform.c","$shared/mapper.c","$shared/music.c","$shared/runtime-math.asm","$shared/assets/bank-layout.h" $out -Force
Copy-Item "$PSScriptRoot/main.c" $out -Force
$savedPath=$env:PATH;$savedCfg=$env:ZCCCFG
Push-Location $out
try{
 $env:PATH="$Z88dk/bin;$env:PATH";$env:ZCCCFG="$Z88dk/lib/config"
 & "$Z88dk/bin/zcc.exe" +msx -subtype=rom -compiler=sdcc -SO3 --max-allocs-per-node20000 -DSCENE3_BENCHMARK -create-app main.c v9968.c music.c runtime-math.asm mapper.c platform.c -o SCENE3-BENCHMARK -m
 if($LASTEXITCODE -ne 0){throw 'Compilation failed'}
 $map=Get-Content SCENE3-BENCHMARK.map -Raw
 if($map -notmatch '__BSS_END_tail\s*=\s*\$([0-9A-Fa-f]+)' -or [Convert]::ToInt32($Matches[1],16) -gt 0xcf00){throw 'Invalid BSS bounds'}
 $fixed=[IO.File]::ReadAllBytes("$out/SCENE3-BENCHMARK.rom")
 if($fixed.Length -gt 16384){throw 'Fixed bank exceeds 16 KiB'}
 $data=[IO.File]::ReadAllBytes("$shared/assets/megarom-data.bin")
 if($data.Length -ne 1032192){throw 'Invalid data size'}
 $rom=New-Object byte[] 1048576
 [Array]::Copy($fixed,0,$rom,0,$fixed.Length);[Array]::Copy($data,0,$rom,16384,$data.Length)
 [IO.File]::WriteAllBytes("$out/SCENE3-BENCHMARK.rom",$rom)
 python "$PSScriptRoot/font-atlas.py" "$out/SCENE3-BENCHMARK.rom"
 if($LASTEXITCODE -ne 0){throw 'Font atlas generation failed'}
 Copy-Item "$out/SCENE3-BENCHMARK.rom" "$PSScriptRoot/SCENE3-BENCHMARK.rom" -Force
 $record=[ordered]@{file='SCENE3-BENCHMARK.rom';size=1048576;sha256=(Get-FileHash "$PSScriptRoot/SCENE3-BENCHMARK.rom").Hash.ToLowerInvariant()}
 [IO.File]::WriteAllText("$PSScriptRoot/rom.json",($record|ConvertTo-Json)+"`n",(New-Object Text.UTF8Encoding($false)))
 Get-FileHash "$PSScriptRoot/SCENE3-BENCHMARK.rom"
}finally{Pop-Location;$env:PATH=$savedPath;$env:ZCCCFG=$savedCfg}
