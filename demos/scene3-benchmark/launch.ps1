param(
 [ValidateSet('cbios','fsa1gt')][string]$Mode='cbios',
 [switch]$Standard,
 [string]$Runtime,
 [string]$TestScript,
 [string]$WorkRoot
)
$ErrorActionPreference='Stop'
if(!$Runtime){$Runtime=Join-Path (Split-Path (Split-Path $PSScriptRoot -Parent) -Parent) "runtime/$Mode"}
$Runtime=[IO.Path]::GetFullPath($Runtime)
if(!(Test-Path -LiteralPath "$Runtime/config.json")){throw "Run setup-$Mode-v9968.bat first."}
$cfg=Get-Content -LiteralPath "$Runtime/config.json" -Raw|ConvertFrom-Json
if($cfg.mode -ne $Mode){throw 'Runtime mode mismatch'}
$exe=Join-Path $Runtime $(if($Standard){'emulator/openmsx-standard.exe'}else{'emulator/openmsx.exe'})
$expected=if($Standard){$cfg.standardSha256}else{$cfg.forkSha256}
if((Get-FileHash -LiteralPath $exe).Hash -ne $expected){throw 'Emulator hash mismatch'}
$rom=Join-Path $PSScriptRoot 'SCENE3-BENCHMARK.rom'
if(!(Test-Path -LiteralPath $rom)){throw 'Benchmark ROM missing. Extract the whole package or rebuild.'}
if((Get-Item -LiteralPath $rom).Length -ne 1048576){throw 'Invalid benchmark ROM size'}
$hash=(Get-FileHash -LiteralPath $rom).Hash
$romInfo=Get-Content -LiteralPath "$PSScriptRoot/rom.json" -Raw|ConvertFrom-Json
if($hash -ne $romInfo.sha256){throw 'Benchmark ROM hash mismatch. Re-extract the package or rebuild.'}
$kind=if($Standard){'standard'}else{'v9968'}
$relative="user-scene3-benchmark/$kind/$($hash.Substring(0,12))"
if($WorkRoot){
 $work=[IO.Path]::GetFullPath($WorkRoot)
 if(Test-Path -LiteralPath $work){throw 'WorkRoot must be a new directory'}
 $cwd=$work;$userPath='home';$romPath='SCENE3-BENCHMARK.rom';$systemPath="$Runtime/emulator/share"
}else{
 $work=Join-Path $Runtime $relative
 $cwd=$Runtime;$userPath="$relative/home";$romPath="$relative/SCENE3-BENCHMARK.rom";$systemPath='emulator/share'
}
[IO.Directory]::CreateDirectory($work)|Out-Null
$dst=Join-Path $work 'SCENE3-BENCHMARK.rom'
if(Test-Path -LiteralPath $dst){if((Get-FileHash -LiteralPath $dst).Hash -ne $hash){throw 'Existing ROM copy differs'}}
else{Copy-Item -LiteralPath $rom -Destination $dst}
if($Mode -eq 'fsa1gt'){
 $biosDir=Join-Path $work 'home/share/systemroms'
 [IO.Directory]::CreateDirectory($biosDir)|Out-Null
 foreach($name in @('fs-a1gt_firmware.rom','fs-a1gt_kanjifont.rom')){
  $src=Join-Path $Runtime "bios/$name";$dst=Join-Path $biosDir $name
  if(Test-Path -LiteralPath $dst){if((Get-FileHash -LiteralPath $src).Hash -ne (Get-FileHash -LiteralPath $dst).Hash){throw 'Existing BIOS copy differs'}}
  else{Copy-Item -LiteralPath $src -Destination $dst}
 }
}
$saved=@{}
foreach($v in @('OPENMSX_HOME','OPENMSX_USER_DATA','OPENMSX_SYSTEM_DATA')){$saved[$v]=[Environment]::GetEnvironmentVariable($v,'Process')}
try{
 $env:OPENMSX_HOME=$userPath;$env:OPENMSX_USER_DATA="$userPath/share";$env:OPENMSX_SYSTEM_DATA=$systemPath
 $machine=if($Standard){$cfg.standardMachine}else{$cfg.machine}
 # All banks are below 256; identical ROM works with standard ASCII16.
 $argv=@('-machine',$machine,'-cart',$romPath,'-romtype','ASCII16')
 if($TestScript){
  if(!$WorkRoot){throw 'TestScript requires an isolated WorkRoot'}
  Copy-Item -LiteralPath $TestScript -Destination "$work/test.tcl"
  $argv+=@('-script','test.tcl')
 }
 # Avoid Start-Process rebuilding inherited environment keys (Path/PATH).
 # All arguments here are fixed names or internally generated relative paths.
 $info=New-Object Diagnostics.ProcessStartInfo
 $info.FileName=$exe;$info.WorkingDirectory=$cwd
 $info.Arguments=($argv | ForEach-Object {'"'+$_+'"'}) -join ' '
 $info.UseShellExecute=$false
 $info.CreateNoWindow=[bool]$TestScript
 if($TestScript){
  $info.WindowStyle=[Diagnostics.ProcessWindowStyle]::Hidden
  $info.RedirectStandardOutput=$true;$info.RedirectStandardError=$true
 }
 $p=New-Object Diagnostics.Process
 $p.StartInfo=$info
 if(!$p.Start()){throw 'Could not start openMSX'}
 if($TestScript){
  $stdout=$p.StandardOutput.ReadToEndAsync();$stderr=$p.StandardError.ReadToEndAsync()
  if(!$p.WaitForExit(60000)){$p.Kill();throw "Benchmark test timed out: $work"}
  [IO.File]::WriteAllText("$work/stdout.log",$stdout.Result)
  [IO.File]::WriteAllText("$work/stderr.log",$stderr.Result)
 }else{$p.WaitForExit()}
 if($p.ExitCode -ne 0){throw "openMSX failed: $work"}
}finally{foreach($v in $saved.Keys){[Environment]::SetEnvironmentVariable($v,$saved[$v],'Process')}}
