param(
 [ValidateSet('cbios','fsa1gt')][string]$Mode='cbios',
 [ValidateSet('a','b','c','reference','reference-packets')][string]$Variant='a',
 [string]$Runtime,
 [string]$UserRoot,
 [switch]$VerifyLaunch
)
$ErrorActionPreference='Stop'
# PS7 parents can pass a module search path unsuitable for Windows PowerShell.
Import-Module (Join-Path $PSHOME 'Modules/Microsoft.PowerShell.Utility/Microsoft.PowerShell.Utility.psd1') -ErrorAction Stop
if(!$Runtime){$Runtime=Join-Path (Split-Path (Split-Path $PSScriptRoot -Parent) -Parent) "runtime/$Mode"}
$Runtime=[IO.Path]::GetFullPath($Runtime)
if(!(Test-Path -LiteralPath "$Runtime/config.json")){throw 'Run the corresponding setup BAT first. / 対応するセットアップ BAT を先に実行してください。'}
$cfg=Get-Content -LiteralPath "$Runtime/config.json" -Raw | ConvertFrom-Json
if($cfg.mode -ne $Mode){throw 'Runtime mode mismatch. / 機種が一致しません。'}
$exe=Join-Path $Runtime 'emulator/openmsx.exe'
if((Get-FileHash -LiteralPath $exe).Hash -ne $cfg.forkSha256){throw 'Emulator hash mismatch.'}
$meta=(Get-Content -LiteralPath "$PSScriptRoot/roms.json" -Raw|ConvertFrom-Json).$Variant
$rom=Join-Path $PSScriptRoot $meta.file
if((Get-Item -LiteralPath $rom).Length -ne $meta.size -or (Get-FileHash -LiteralPath $rom).Hash -ne $meta.sha256){throw 'ROM size/hash mismatch. / ROM を再ビルドしてください。'}
if(!$UserRoot){$UserRoot=Join-Path $env:LOCALAPPDATA 'openmsx-v9968-windows-setup/scene3-v9990'}
$work=Join-Path ([IO.Path]::GetFullPath($UserRoot)) ($Mode+'/'+$Variant+'/'+$meta.sha256.Substring(0,12))
[IO.Directory]::CreateDirectory($work)|Out-Null
function CopyVerified([string]$src,[string]$dst){
 if(Test-Path -LiteralPath $dst){if((Get-FileHash -LiteralPath $src).Hash -ne (Get-FileHash -LiteralPath $dst).Hash){throw "Existing copy differs: $dst"}}
 else{Copy-Item -LiteralPath $src -Destination $dst}
}
CopyVerified $rom (Join-Path $work 'demo.rom')
if($Mode -eq 'fsa1gt'){
 $bios=Join-Path $work 'home/share/systemroms';[IO.Directory]::CreateDirectory($bios)|Out-Null
 foreach($name in @('fs-a1gt_firmware.rom','fs-a1gt_kanjifont.rom')){CopyVerified (Join-Path $Runtime "bios/$name") (Join-Path $bios $name)}
}
$script="set save_settings_on_exit false`nset cmdtiming real`n"
if($Variant -notlike 'reference*'){$script+="after time 1 {set videosource GFX9000}`n"}
if($VerifyLaunch){$script+="set throttle false`nset sound_driver null`nafter time 12 {set f [open launch-check.txt w]; puts `$f [list [peek16 0xcf00] [debug read memory 0xcf06]];close `$f;exit}`nafter realtime 45 {exit 1}`n"}
[IO.File]::WriteAllText((Join-Path $work 'launch.tcl'),$script,(New-Object Text.UTF8Encoding($false)))
$saved=@{};foreach($v in @('OPENMSX_HOME','OPENMSX_USER_DATA','OPENMSX_SYSTEM_DATA')){$saved[$v]=[Environment]::GetEnvironmentVariable($v,'Process')}
try{
 $env:OPENMSX_HOME=Join-Path $work 'home';$env:OPENMSX_USER_DATA=Join-Path $work 'home/share';$env:OPENMSX_SYSTEM_DATA=Join-Path $Runtime 'emulator/share'
 $machine=if($Variant -like 'reference*'){$cfg.machine}else{$cfg.standardMachine}
 $argv=@('-machine',$machine,'-cart','demo.rom','-romtype','ASCII16')
 if($Variant -notlike 'reference*'){$argv+=@('-ext','gfx9000')}
 $argv+=@('-script','launch.tcl')
 Write-Host "$Mode / $Variant : $rom"
 $checkPath=Join-Path $work 'launch-check.txt'
 if($VerifyLaunch -and (Test-Path -LiteralPath $checkPath)){Remove-Item -LiteralPath $checkPath}
 # All arguments are fixed flags, relative filenames or validated machine names.
 if($argv | Where-Object {$_ -match '["\r\n]'}){throw 'Invalid emulator argument.'}
 $info=New-Object Diagnostics.ProcessStartInfo
 $info.FileName=$exe;$info.WorkingDirectory=$work
 $info.Arguments=($argv | ForEach-Object {'"'+$_+'"'}) -join ' '
 $info.UseShellExecute=$false;$info.CreateNoWindow=[bool]$VerifyLaunch
 if($VerifyLaunch){$info.WindowStyle=[Diagnostics.ProcessWindowStyle]::Hidden}
 $info.RedirectStandardOutput=$true;$info.RedirectStandardError=$true
 $process=New-Object Diagnostics.Process;$process.StartInfo=$info
 if(!$process.Start()){throw 'Could not start openMSX.'}
 $stdout=$process.StandardOutput.ReadToEndAsync();$stderr=$process.StandardError.ReadToEndAsync()
 if($VerifyLaunch){
  if(!$process.WaitForExit(60000)){$process.Kill();throw 'Launch verification timed out.'}
 }else{$process.WaitForExit()}
 [IO.File]::WriteAllText("$work/stdout.log",$stdout.Result)
 [IO.File]::WriteAllText("$work/stderr.log",$stderr.Result)
 if($process.ExitCode -ne 0){throw "openMSX failed. Log: $work/stderr.log"}
 if($VerifyLaunch){$result=(Get-Content "$work/launch-check.txt" -Raw).Trim() -split ' ';if([int]$result[0] -le 0 -or [int]$result[1] -ne 0){throw 'Launch verification failed.'};Write-Host 'PASS: rendered frames, FAULT=0'}
}finally{foreach($v in $saved.Keys){[Environment]::SetEnvironmentVariable($v,$saved[$v],'Process')}}
