param([Parameter(Mandatory=$true)][string]$Runtime)
$ErrorActionPreference='Stop'
$cfg=Get-Content "$Runtime/config.json" -Raw|ConvertFrom-Json
$map=Get-Content "$PSScriptRoot/build/V9968-TECH-DEMO.map" -Raw
function Symbol($name){
 $m=[regex]::Match($map,'(?m)^'+[regex]::Escape($name)+'\s*=\s*\$([0-9A-Fa-f]+)')
 if(!$m.Success){throw "Missing map symbol $name"};[Convert]::ToInt32($m.Groups[1].Value,16)
}
$entry=Symbol '_water_draw';$page=Symbol '_back_page'
$identity=(Get-Content "$PSScriptRoot/assets/bank-layout.json" -Raw|ConvertFrom-Json).IDENTITY.bank
$out=Join-Path $PSScriptRoot ('test-output/water-'+$cfg.mode+'-'+(Get-Date -Format 'yyyyMMdd-HHmmss'))
$saved=@{};foreach($v in @('OPENMSX_HOME','OPENMSX_USER_DATA','OPENMSX_SYSTEM_DATA')){$saved[$v]=[Environment]::GetEnvironmentVariable($v,'Process')}
$results=@()
try{
 foreach($mode in @('identity','wave')){
  $work=Join-Path $out $mode;[IO.Directory]::CreateDirectory($work)|Out-Null
  Copy-Item "$PSScriptRoot/build/V9968-TECH-DEMO.rom" "$work/V9968-TECH-DEMO.rom"
  $env:OPENMSX_HOME="$work/user";$env:OPENMSX_USER_DATA="$work/user/share";$env:OPENMSX_SYSTEM_DATA="$Runtime/emulator/share"
  if($cfg.mode -eq 'fsa1gt'){[IO.Directory]::CreateDirectory("$work/user/share/systemroms")|Out-Null;Copy-Item "$Runtime/bios/*.rom" "$work/user/share/systemroms"}
  $tcl=@'
set save_settings_on_exit false
set throttle false
set sound_driver null
proc dump {file space address length} {
 set f [open $file wb];puts -nonewline $f [debug read_block $space $address $length];close $f
}
# Pause the CPU in test RAM while queued VDP work completes. Interrupts remain live.
debug set_bp -once @ENTRY@ {} {
 debug write memory 0xcf80 0xc3
 debug write memory 0xcf81 0x80
 debug write memory 0xcf82 0xcf
 set return_address [peek16 [reg SP]]
 set argument_address [expr {[reg SP]+2}]
 if {@IDENTITY@} {
  debug write memory 0x7000 @BANK@
  debug write memory $argument_address 0
  debug write memory [expr {$argument_address+1}] 0x80
 }
 reg PC 0xcf80
  after time 0.1 {
  if {!@IDENTITY@} {
   # Distinct edge pixels make black gaps and two-pixel repeats detectable.
   for {set y 0} {$y < 192} {incr y} {
    debug write VRAM [expr {65536+$y*128}] 0xab
    debug write VRAM [expr {65536+$y*128+127}] 0xcd
   }
  }
  dump source.bin VRAM 65536 24576
  dump parameters.bin memory [peek16 $argument_address] 384
  debug set_bp -once $return_address {} {
   reg PC 0xcf80
   after time 0.1 {
    dump actual.bin VRAM [expr {[debug read memory @PAGE@]*32768}] 24576
    set f [open status.txt w]
    puts $f "MAPPER=[debug read memory 0xcf07] FAULT=[debug read memory 0xcf06]"
    close $f
    exit
   }
   debug cont
  }
  reg PC @ENTRY@
 }
 debug cont
}
after time 85 {exit 1}
'@
  $tcl=$tcl.Replace('@ENTRY@',"$entry").Replace('@PAGE@',"$page").Replace('@BANK@',"$identity").Replace('@IDENTITY@',$(if($mode -eq 'identity'){'1'}else{'0'}))
  [IO.File]::WriteAllText("$work/water.tcl",$tcl)
  $exe="$Runtime/emulator/openmsx.exe"
  if((Get-FileHash $exe).Hash -ne $cfg.forkSha256){throw 'Emulator hash mismatch'}
  $p=Start-Process -FilePath $exe -ArgumentList @('-machine',$cfg.machine,'-cart','V9968-TECH-DEMO.rom','-romtype','ASCII16-X','-script','water.tcl') -WorkingDirectory $work -WindowStyle Hidden -PassThru -RedirectStandardOutput "$work/stdout.log" -RedirectStandardError "$work/stderr.log"
  $handle=$p.Handle;if(!$p.WaitForExit(60000)){$p.Kill();throw "Water test timed out: $work"}
  if($p.ExitCode -ne 0){throw "Water test failed: $work"}
  $src=[IO.File]::ReadAllBytes("$work/source.bin");$params=[IO.File]::ReadAllBytes("$work/parameters.bin");$actual=[IO.File]::ReadAllBytes("$work/actual.bin")
  if($src.Length -ne 24576 -or $actual.Length -ne 24576 -or $params.Length -ne 384){throw 'Incomplete capture'}
  $expected=New-Object byte[] 24576
  for($band=0;$band -lt 96;$band++){
   $sx=[int]$params[$band*4];$dx=[int]$params[$band*4+1];$w=[int]$params[$band*4+2];$sy=[int]$params[$band*4+3];if($w -eq 0){$w=256}
   if(($sx -ne 0 -and $sx -ne 2) -or ($dx -ne 0 -and $dx -ne 2) -or $sx+$dx -gt 2){throw 'Horizontal excursion exceeds two pixels'}
   if(($sx%2) -or ($dx%2) -or ($w%2) -or $sx+$w -gt 256 -or $dx+$w -gt 256 -or $sy+2 -gt 192){throw 'Invalid band bounds'}
   for($row=0;$row -lt 2;$row++){[Array]::Copy($src,($sy+$row)*128+$sx/2,$expected,($band*2+$row)*128+$dx/2,$w/2)}
   for($row=0;$row -lt 2;$row++){
    if($dx){$color=$src[($sy+$row)*128] -shr 4;$expected[($band*2+$row)*128]=$color*17}
    if($sx){$color=$src[($sy+$row)*128+127] -band 15;$expected[($band*2+$row)*128+127]=$color*17}
   }
  }
  $mismatch=0;for($i=0;$i -lt $expected.Length;$i++){if($actual[$i] -ne $expected[$i]){$mismatch++}}
  [IO.File]::WriteAllBytes("$work/expected.bin",$expected)
  $sourceHash=(Get-FileHash "$work/source.bin").Hash;$actualHash=(Get-FileHash "$work/actual.bin").Hash
  if($mismatch -or ($mode -eq 'identity' -and $sourceHash -ne $actualHash) -or ($mode -eq 'wave' -and $sourceHash -eq $actualHash)){throw "Water comparison mismatch ($mismatch): $work"}
  if((Get-Content "$work/status.txt" -Raw) -notmatch 'MAPPER=1 FAULT=0'){throw 'Mapper or VDP fault'}
  $results+=[pscustomobject]@{mode=$mode;pass=$true;edgeFixture=($mode -eq 'wave');mismatchedBytes=$mismatch;sourceSha256=$sourceHash;actualSha256=$actualHash}
 }
 $results|ConvertTo-Json|Set-Content "$out/results.json"
 Write-Host "PASS: identity and wave match independent byte-level reference; mapper bank check passed. $out"
}finally{foreach($v in $saved.Keys){[Environment]::SetEnvironmentVariable($v,$saved[$v],'Process')}}
