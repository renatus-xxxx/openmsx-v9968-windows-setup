set save_settings_on_exit false
set throttle false
set maxframeskip 0
set sound_driver null
proc frame {} {expr {[debug read memory 0xcf00]+256*[debug read memory 0xcf01]}}
after time 5 {keymatrixdown 0 128}
after time 6 {keymatrixup 0 128}
after time 11 {set f0 [frame];set t0 [machine_info time]}
after time 26 {
 set f [open telemetry.txt w]
 puts $f "FRAMES=[expr {([frame]-$::f0)&65535}] SECONDS=[expr {[machine_info time]-$::t0}] SCENE=[debug read memory 0xcf04] FAULT=[debug read memory 0xcf06]"
 puts $f "FPS=[expr {double(([frame]-$::f0)&65535)/([machine_info time]-$::t0)}]"
 puts $f "CAPTURE=[expr {[debug read memory 0xcf04]==6 && [debug read memory 0xcf06]==0 ? {PASS} : {FAIL}}]"
 close $f
 exit
}

