param([Parameter(Mandatory=$true)][string]$Runtime,[switch]$SlowCommands,[switch]$Trace,[switch]$DiagnosticTest,[switch]$Standard,[string]$CaptureScript)
$ErrorActionPreference='Stop'
$cfg=Get-Content "$Runtime/config.json" -Raw|ConvertFrom-Json
$work=Join-Path $PSScriptRoot ('test-output/'+$cfg.mode+'-'+(Get-Date -Format 'yyyyMMdd-HHmmss'))
[IO.Directory]::CreateDirectory($work)|Out-Null
$sourceRom=if($DiagnosticTest){'V9968-TECH-DEMO-DIAGNOSTIC.rom'}else{'V9968-TECH-DEMO.rom'}
Copy-Item "$PSScriptRoot/build/$sourceRom" (Join-Path $work 'V9968-TECH-DEMO.rom')
Copy-Item "$PSScriptRoot/capture.tcl" $work
$mapText=Get-Content "$PSScriptRoot/build/V9968-TECH-DEMO.map" -Raw
if($mapText -notmatch '(?m)^_flip\s*=\s*\$([0-9A-Fa-f]+)'){throw 'Missing flip symbol'}
('set flip_address 0x'+$Matches[1]) | Set-Content "$work/test-symbols.tcl" -Encoding ascii
$layout=Get-Content "$PSScriptRoot/assets/bank-layout.json" -Raw|ConvertFrom-Json
$payload=[IO.File]::ReadAllBytes("$PSScriptRoot/assets/megarom-data.bin")
foreach($name in @('BACKGROUND','SEABED')){
 $expected=New-Object byte[] 22528
 [Array]::Copy($payload,($layout.$name.bank-1)*16384+2048,$expected,0,22528)
 [IO.File]::WriteAllBytes((Join-Path $work "$name.bin"),$expected)
}
if($CaptureScript){
 if($Standard -or $DiagnosticTest){throw 'CaptureScript cannot be combined with Standard or DiagnosticTest'}
 Copy-Item -LiteralPath $CaptureScript -Destination "$work/capture.tcl"
}
if($DiagnosticTest){
@'
set save_settings_on_exit false
set throttle false
set maxframeskip 0
set sound_driver null
after time 9 {set throttle true}
after time 10 {
 screenshot -raw diagnostic.png
 set f [open telemetry.txt w]
 binary scan [debug read_block memory 0xcf20 60] s* d
 puts $f $d
 close $f
 exit
}
'@ | Set-Content "$work/capture.tcl" -Encoding ascii
}
if($Standard){
@'
set save_settings_on_exit false
set throttle false
set sound_driver null
after time 9 {set throttle true}
after time 10 {
 set f [open telemetry.txt w]
 puts $f [get_screen]
 close $f
 exit
}
'@ | Set-Content "$work/capture.tcl" -Encoding ascii
}
if($SlowCommands){Add-Content "$work/capture.tcl" 'after time 8 {debug write "VDP regs" 20 48}'}
if($Trace){Add-Content "$work/capture.tcl" 'set vdpcmdtrace true'}
$env:OPENMSX_HOME=Join-Path $work 'user'
$env:OPENMSX_USER_DATA=Join-Path $work 'user/share'
$env:OPENMSX_SYSTEM_DATA=Join-Path $Runtime 'emulator/share'
if($cfg.mode -eq 'fsa1gt'){
 $romdir=Join-Path $work 'user/share/systemroms'
 [IO.Directory]::CreateDirectory($romdir)|Out-Null
 Copy-Item "$Runtime/bios/*.rom" $romdir
}
Push-Location $work
try{
 $exe=if($Standard){"$Runtime/emulator/openmsx-standard.exe"}else{"$Runtime/emulator/openmsx.exe"}
 $machine=if($Standard){$cfg.standardMachine}else{$cfg.machine}
 $expected=if($Standard){$cfg.standardSha256}else{$cfg.forkSha256}
 if((Get-FileHash -LiteralPath $exe).Hash -ne $expected){throw 'Emulator hash mismatch'}
 $p=Start-Process -FilePath $exe -ArgumentList @('-machine',$machine,'-cart','V9968-TECH-DEMO.rom','-romtype','ASCII16','-script','capture.tcl') -WorkingDirectory $work -WindowStyle Hidden -PassThru -RedirectStandardOutput "$work/stdout.log" -RedirectStandardError "$work/stderr.log"
 $handle=$p.Handle
 if(!$p.WaitForExit(60000)){$p.Kill();throw 'Emulator test timed out'}
 if($p.ExitCode -ne 0){throw 'Emulator failed; inspect test logs'}
 if($CaptureScript){if((Get-Content "$work/telemetry.txt" -Raw) -notmatch 'CAPTURE=PASS'){throw 'Capture failed'}}
 elseif($Standard){if((Get-Content "$work/telemetry.txt" -Raw) -notmatch 'V9968 REQUIRED'){throw 'Unsupported VDP check failed'}}
 elseif(!$DiagnosticTest -and (Get-Content "$work/telemetry.txt" -Raw) -notmatch 'SCENES_AND_ESCAPE=PASS'){throw 'Scene sequence or Escape test failed; inspect telemetry'}
 Get-Content "$work/telemetry.txt"
 Write-Host $work
}
finally{Pop-Location}
