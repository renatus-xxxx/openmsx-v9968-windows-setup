param([Parameter(Mandatory=$true)][string]$Z88dk,[switch]$CStream,[string]$MeshObj="",[double]$MeshRadius)
$ErrorActionPreference='Stop'
$shared=Join-Path (Split-Path $PSScriptRoot -Parent) 'v9968-tech-demo'
$out=Join-Path $PSScriptRoot $(if($CStream){'build-c'}else{'build'})
if(!(Test-Path -LiteralPath "$Z88dk/bin/zcc.exe")){throw 'Specify the z88dk root using -Z88dk.'}
python "$shared/generate-fonts.py"
if($LASTEXITCODE -ne 0){throw 'Font generation failed'}
$meshArgs=@("$shared/generate-megarom.py")
if($PSBoundParameters.ContainsKey('MeshRadius')){$meshArgs+=@("--mesh-radius",$MeshRadius.ToString([Globalization.CultureInfo]::InvariantCulture))}
if($MeshObj){$meshArgs+=@("--mesh-obj",$MeshObj)}
python @meshArgs
if($LASTEXITCODE -ne 0){throw 'Data generation failed'}
python "$shared/verify-water-model.py"
if($LASTEXITCODE -ne 0){throw 'Water model verification failed'}
[IO.Directory]::CreateDirectory($out)|Out-Null
Copy-Item "$shared/*.h","$shared/v9968.c","$shared/platform.c","$shared/mapper.c","$shared/music.c","$shared/runtime-math.asm","$shared/assets/bank-layout.h" $out -Force
Copy-Item "$PSScriptRoot/main.c" $out -Force
$savedPath=$env:PATH;$savedCfg=$env:ZCCCFG
Push-Location $out
try{
 $env:PATH="$Z88dk/bin;$env:PATH";$env:ZCCCFG="$Z88dk/lib/config"
 $extra=@();if($CStream){$extra+="-DV9968_SCENE3_C_STREAM"}
 & "$Z88dk/bin/zcc.exe" +msx -subtype=rom -compiler=sdcc -SO3 --max-allocs-per-node20000 -DSCENE3_BENCHMARK @extra -create-app main.c v9968.c music.c runtime-math.asm mapper.c platform.c -o SCENE3-BENCHMARK-OPTIMIZED -m
 if($LASTEXITCODE -ne 0){throw 'Compilation failed'}
 $map=Get-Content SCENE3-BENCHMARK-OPTIMIZED.map -Raw
 if($map -notmatch '__BSS_END_tail\s*=\s*\$([0-9A-Fa-f]+)' -or [Convert]::ToInt32($Matches[1],16) -gt 0xcf00){throw 'Invalid BSS bounds'}
 $fixed=[IO.File]::ReadAllBytes("$out/SCENE3-BENCHMARK-OPTIMIZED.rom")
 if($fixed.Length -gt 16384){throw 'Fixed bank exceeds 16 KiB'}
 $data=[IO.File]::ReadAllBytes("$shared/assets/megarom-data.bin")
 $layout=Get-Content "$shared/assets/bank-layout.json" -Raw | ConvertFrom-Json
 if($data.Length -lt 1032192 -or $layout.SEABED.bank+2 -gt 63){throw 'Benchmark assets exceed its 1 MiB layout'}
 $rom=New-Object byte[] 1048576
 [Array]::Copy($fixed,0,$rom,0,$fixed.Length);[Array]::Copy($data,0,$rom,16384,1032192)
 # Scene 7 assets above this boundary are unused; keep the benchmark signature.
 [Array]::Clear($rom,1048560,16)
 [Array]::Copy([Text.Encoding]::ASCII.GetBytes('MCX2'),0,$rom,1048560,4)
 [IO.File]::WriteAllBytes("$out/SCENE3-BENCHMARK-OPTIMIZED.rom",$rom)
 python "$PSScriptRoot/font-atlas.py" "$out/SCENE3-BENCHMARK-OPTIMIZED.rom"
 if($LASTEXITCODE -ne 0){throw 'Font atlas generation failed'}
 if(!$CStream){
 Copy-Item "$out/SCENE3-BENCHMARK-OPTIMIZED.rom" "$PSScriptRoot/SCENE3-BENCHMARK-OPTIMIZED.rom" -Force
 $record=[ordered]@{file='SCENE3-BENCHMARK-OPTIMIZED.rom';size=1048576;sha256=(Get-FileHash "$PSScriptRoot/SCENE3-BENCHMARK-OPTIMIZED.rom").Hash.ToLowerInvariant()}
 [IO.File]::WriteAllText("$PSScriptRoot/rom-optimized.json",($record|ConvertTo-Json)+"`n",(New-Object Text.UTF8Encoding($false)))
 }
 Get-FileHash "$out/SCENE3-BENCHMARK-OPTIMIZED.rom"
}finally{Pop-Location;$env:PATH=$savedPath;$env:ZCCCFG=$savedCfg}
