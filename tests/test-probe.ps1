param([Parameter(Mandatory=$true)][string]$Runtime,[switch]$Standard,
 [string]$ProbeRom,[ValidateSet(0,1,2,3)][int]$ExpectedError=0,
 [ValidateSet("31","11","none")][string]$ExpectedR20="11",
 [ValidateSet(0,1)][int]$ExpectedHigh=1)
$ErrorActionPreference='Stop'
$repo=Split-Path -Parent $PSScriptRoot
$Runtime=[IO.Path]::GetFullPath($Runtime)
$cfg=Get-Content -LiteralPath (Join-Path $Runtime 'config.json') -Raw | ConvertFrom-Json
$kind=if($Standard){'standard'}else{'v9968'}
$relative='user-probe-test/'+[guid]::NewGuid().ToString('N')
$work=Join-Path $Runtime $relative
[IO.Directory]::CreateDirectory((Join-Path $work 'home/share/systemroms'))|Out-Null
if($cfg.mode -eq 'fsa1gt'){
 foreach($name in @('fs-a1gt_firmware.rom','fs-a1gt_kanjifont.rom')){
  Copy-Item -LiteralPath (Join-Path $Runtime "bios/$name") -Destination (Join-Path $work "home/share/systemroms/$name")
 }
}
if(!$ProbeRom){$ProbeRom=Join-Path $repo 'probe/PROBE.rom'}
Copy-Item -LiteralPath $ProbeRom -Destination (Join-Path $work 'PROBE.rom')
$tcl=@'
set save_settings_on_exit false
set throttle false
set sound_driver null
after time 10 {
 catch {screenshot -raw "@SHOT@"}
 set f [open result.txt w]
 puts $f [get_active_cpu]
 puts $f [get_screen]
 puts $f "RESTORE R14=[debug read {VDP regs} 14] R20=[debug read {VDP regs} 20]"
 close $f
 exit
}
'@
# Use runtime as cwd, keeping all emulator data arguments relative for Unicode paths.
$tcl=$tcl.Replace('@SHOT@',($relative+'/screen.png'))
$tcl=$tcl.Replace('open result.txt w',('open "'+$relative+'/result.txt" w'))
[IO.File]::WriteAllText((Join-Path $work 'test.tcl'),$tcl)
$saved=@{}
foreach($v in @('OPENMSX_HOME','OPENMSX_USER_DATA','OPENMSX_SYSTEM_DATA')){$saved[$v]=[Environment]::GetEnvironmentVariable($v,'Process')}
try{
 $env:OPENMSX_HOME="$relative/home";$env:OPENMSX_USER_DATA="$relative/home/share";$env:OPENMSX_SYSTEM_DATA='emulator/share'
 $exe=Join-Path $Runtime $(if($Standard){'emulator/openmsx-standard.exe'}else{'emulator/openmsx.exe'})
 $expected=if($Standard){$cfg.standardSha256}else{$cfg.forkSha256}
 if((Get-FileHash -LiteralPath $exe).Hash -ne $expected){throw 'Emulator hash mismatch'}
 $machine=if($Standard){$cfg.standardMachine}else{$cfg.machine}
 $args=@('-machine',$machine,'-cart',"$relative/PROBE.rom",'-script',"$relative/test.tcl")
 $p=Start-Process -FilePath $exe -ArgumentList $args -WorkingDirectory $Runtime -WindowStyle Hidden -PassThru -RedirectStandardOutput (Join-Path $work 'stdout.log') -RedirectStandardError (Join-Path $work 'stderr.log')
 $null=$p.Handle
 if(!$p.WaitForExit(60000)){$p.Kill();$p.WaitForExit();throw 'Probe test timed out'}
 if($p.ExitCode -ne 0){throw 'Probe emulator failed'}
 $result=Get-Content -LiteralPath (Join-Path $work 'result.txt') -Raw
 $required=@('V9968 / C ROM TEST','REPORT THESE LINES','RESTORE R14=0 R20=0','PROBE REV=2')
 if($Standard){$required+=@('VDP ID=2','V9968 NOT IDENTIFIED','NO FURTHER TESTS RUN')}
 elseif($ExpectedError){$required+=@('VDP ID=3',"PROBE ERROR code=$ExpectedError",'PARTIAL RESULTS DISCARDED')}
 else{
  $required+=@('VDP ID=3','V9968 IDENTIFIED','EXTID=3 R21=3a','VRAM   a1 a2 a3 a4','CESEEN value=1')
  if($ExpectedR20 -eq 'none'){$required+=@('R20B5  off=0 on=0','R20SEL NONE','LRMM TESTS SKIPPED')}
  else{
   $required+=@("R20SEL value=$ExpectedR20","LRHIGH ok=$ExpectedHigh")
   if($ExpectedR20 -eq '31'){$required+=@('R20B5  off=0 on=1','LRRAW off=00 on=ff')}
   # The pinned 14215c7 fork transfers under both settings and prefers 0x11.
   if($ExpectedR20 -eq '11'){$required+=@('R20B5  off=1 on=1','LRRAW off=ff on=ff')}
   if($ExpectedHigh){$required+=@('LRMMOP timp=ff imp=00','LRMMST d0=1 d1=2')}
   else{$required+='LRMM TESTS SKIPPED'}
  }
 }
 foreach($line in $required){if($result -notmatch [regex]::Escape($line)){throw "Missing probe output: $line"}}
 if(!$ExpectedError -and $result -match 'PROBE ERROR|PARTIAL RESULTS'){throw 'Probe reported incomplete experiments'}
 Write-Output $result
 Write-Output "PASS: $($cfg.mode)/$kind probe; output and text-mode restoration"
}finally{foreach($v in $saved.Keys){[Environment]::SetEnvironmentVariable($v,$saved[$v],'Process')}}
