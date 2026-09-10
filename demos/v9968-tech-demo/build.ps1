param([Parameter(Mandatory=$true)][string]$Z88dk,[switch]$Diagnostic)
$ErrorActionPreference='Stop'
if(!(Test-Path -LiteralPath "$Z88dk/bin/zcc.exe")){throw 'Specify the z88dk root using -Z88dk.'}
python "$PSScriptRoot/generate-fonts.py"
if($LASTEXITCODE -ne 0){throw 'Font generation failed'}
python "$PSScriptRoot/generate-megarom.py"
if($LASTEXITCODE -ne 0){throw 'ROM data generation failed'}
$out=Join-Path $PSScriptRoot 'build'
[IO.Directory]::CreateDirectory($out)|Out-Null
Copy-Item -Path (Join-Path $PSScriptRoot '*.c'),(Join-Path $PSScriptRoot '*.h') -Destination $out -Force
Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'runtime-math.asm'),(Join-Path $PSScriptRoot 'assets/bank-layout.h') -Destination $out -Force
$oldPath=$env:PATH;$oldCfg=$env:ZCCCFG
Push-Location $out
try{
 $env:PATH="$Z88dk/bin;$env:PATH";$env:ZCCCFG="$Z88dk/lib/config"
 $name=if($Diagnostic){'V9968-TECH-DEMO-DIAGNOSTIC'}else{'V9968-TECH-DEMO'}
 $extra=@();if($Diagnostic){$extra+='-DV9968_DEMO_DIAGNOSTIC'}
 & "$Z88dk/bin/zcc.exe" +msx -subtype=rom -compiler=sdcc -SO3 --max-allocs-per-node20000 @extra -create-app main.c v9968.c music.c runtime-math.asm mapper.c platform.c -o $name -m
 if($LASTEXITCODE -ne 0){throw 'Demo compilation failed'}
 $map=Get-Content "$name.map" -Raw
 if($map -notmatch '__BSS_END_tail\s*=\s*\$([0-9A-Fa-f]+)'){throw 'BSS bound missing'}
 if([Convert]::ToInt32($Matches[1],16) -gt 0xcf00){throw 'BSS overlaps reserved memory'}
 $fixed=[IO.File]::ReadAllBytes((Join-Path $out "$name.rom"))
 if($fixed.Length -gt 16384){throw 'Fixed bank exceeds 16 KiB'}
 $payload=[IO.File]::ReadAllBytes((Join-Path $PSScriptRoot 'assets/megarom-data.bin'))
 if($payload.Length -ne 1032192){throw 'Wrong payload size'}
 $rom=New-Object byte[] 1048576
 [Array]::Copy($fixed,0,$rom,0,$fixed.Length)
 [Array]::Copy($payload,0,$rom,16384,$payload.Length)
 [IO.File]::WriteAllBytes((Join-Path $out "$name.rom"),$rom)
 if(!$Diagnostic){Copy-Item -LiteralPath (Join-Path $out "$name.rom") -Destination (Join-Path $PSScriptRoot "$name.rom") -Force}
 Get-FileHash "$name.rom"
}finally{Pop-Location;$env:PATH=$oldPath;$env:ZCCCFG=$oldCfg}
