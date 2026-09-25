param([Parameter(Mandatory=$true)][string]$Z88dk,[switch]$Diagnostic,[switch]$CStream,[string]$MeshObj="",[double]$MeshRadius,[string]$ProfileFilter="")
$ErrorActionPreference='Stop'
$profiles=@('external-0x88','internal-0x98') | Where-Object {!$ProfileFilter -or $_ -match $ProfileFilter}
if(!$profiles){throw 'No profiles match -ProfileFilter. Use internal-0x98 or external-0x88.'}
if(!(Test-Path -LiteralPath "$Z88dk/bin/zcc.exe")){throw 'Specify the z88dk root using -Z88dk.'}
python "$PSScriptRoot/generate-fonts.py"
if($LASTEXITCODE -ne 0){throw 'Font generation failed'}
$meshArgs=@("$PSScriptRoot/generate-megarom.py")
if($PSBoundParameters.ContainsKey('MeshRadius')){$meshArgs+=@("--mesh-radius",$MeshRadius.ToString([Globalization.CultureInfo]::InvariantCulture))}
if($MeshObj){$meshArgs+=@("--mesh-obj",$MeshObj)}
python @meshArgs
if($LASTEXITCODE -ne 0){throw 'ROM data generation failed'}
python "$PSScriptRoot/verify-water-model.py"
if($LASTEXITCODE -ne 0){throw 'Water model verification failed'}
python "$PSScriptRoot/verify-shallow.py"
if($LASTEXITCODE -ne 0){throw 'Shallow model verification failed'}
$layout=Get-Content -LiteralPath "$PSScriptRoot/assets/bank-layout.json" -Raw | ConvertFrom-Json
$romBytes=[int]$layout.summary.rom_bytes
$signatureBank=[int]$layout.summary.rom_banks-1
$out=Join-Path $PSScriptRoot $(if($CStream){'build-c'}else{'build'})
[IO.Directory]::CreateDirectory($out)|Out-Null
Copy-Item -Path (Join-Path $PSScriptRoot '*.c'),(Join-Path $PSScriptRoot '*.h') -Destination $out -Force
Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'runtime-math.asm'),(Join-Path $PSScriptRoot 'assets/bank-layout.h') -Destination $out -Force
$oldPath=$env:PATH;$oldCfg=$env:ZCCCFG
Push-Location $out
try{
 $env:PATH="$Z88dk/bin;$env:PATH";$env:ZCCCFG="$Z88dk/lib/config"
 foreach($profile in $profiles){
  $name=if($Diagnostic){"V9968-TECH-DEMO-$profile-DIAGNOSTIC"}else{"V9968-TECH-DEMO-$profile"}
  $extra=@($(if($profile -eq 'external-0x88'){'-DVDP_BASE=136'}else{'-DVDP_BASE=152'}));if($CStream){$extra+='-DV9968_SCENE3_C_STREAM'};if($Diagnostic){$extra+='-DV9968_DEMO_DIAGNOSTIC'}
  & "$Z88dk/bin/zcc.exe" +msx -subtype=rom -compiler=sdcc -SO3 --max-allocs-per-node20000 @extra "-DDEMO_SIGNATURE_BANK=$signatureBank" -create-app main.c v9968.c music.c runtime-math.asm mapper.c platform.c -o $name -m
  if($LASTEXITCODE -ne 0){throw 'Demo compilation failed'}
  $map=Get-Content "$name.map" -Raw
  if($map -notmatch '__BSS_END_tail\s*=\s*\$([0-9A-Fa-f]+)'){throw 'BSS bound missing'}
  if([Convert]::ToInt32($Matches[1],16) -gt 0xcf00){throw 'BSS overlaps reserved memory'}
  $fixed=[IO.File]::ReadAllBytes((Join-Path $out "$name.rom"))
  if($fixed.Length -gt 16384){throw 'Fixed bank exceeds 16 KiB'}
  $payload=[IO.File]::ReadAllBytes((Join-Path $PSScriptRoot 'assets/megarom-data.bin'))
  if($payload.Length -ne ($romBytes-16384)){throw 'Wrong payload size'}
  $rom=New-Object byte[] $romBytes
  [Array]::Copy($fixed,0,$rom,0,$fixed.Length)
  [Array]::Copy($payload,0,$rom,16384,$payload.Length)
  [IO.File]::WriteAllBytes((Join-Path $out "$name.rom"),$rom)
  if(!$Diagnostic -and !$CStream){Copy-Item -LiteralPath (Join-Path $out "$name.rom") -Destination (Join-Path $PSScriptRoot "$name.rom") -Force}
  if($profile -eq 'internal-0x98'){
   $compat=if($Diagnostic){'V9968-TECH-DEMO-DIAGNOSTIC'}else{'V9968-TECH-DEMO'}
   Copy-Item -LiteralPath (Join-Path $out "$name.rom") -Destination (Join-Path $out "$compat.rom") -Force
   Copy-Item -LiteralPath (Join-Path $out "$name.map") -Destination (Join-Path $out "$compat.map") -Force
   if(!$Diagnostic -and !$CStream){Copy-Item -LiteralPath (Join-Path $out "$name.rom") -Destination (Join-Path $PSScriptRoot 'V9968-TECH-DEMO.rom') -Force}
  }
  Get-FileHash "$name.rom"
 }
}finally{Pop-Location;$env:PATH=$oldPath;$env:ZCCCFG=$oldCfg}
