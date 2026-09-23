set save_settings_on_exit false
set throttle false
set maxframeskip 0
set sound_driver null
set cmdtiming real
set log [open integration.txt w];fconfigure $log -buffering line
set captured 0
proc check {condition label} {global log;if {![uplevel 1 [list expr $condition]]} {puts $log "FAIL $label";close $log;exit 1};puts $log "PASS $label"}
proc sample_psg {} {lappend ::psg_samples [debug read_block {PSG regs} 0 16];if {[llength $::psg_samples]<10} {after time 0.08 sample_psg}}
proc controls {} {
 global log
 debug write memory 0xcf10 0;debug write memory 0xcf11 1
 puts $log "CPU [get_active_cpu]"
 after time 60 {check {[debug read memory 0xcf06]==0 && [peek16 0xcf00]>60} continuous;keymatrixdown 5 16}
 after time 62 {check {[debug read memory 0xcf15]==0} water_off;keymatrixup 5 16}
 after time 64 {keymatrixdown 5 16}
 after time 66 {check {[debug read memory 0xcf15]==1} water_on;keymatrixup 5 16;keymatrixdown 4 32}
 after time 68 {keymatrixup 4 32;check {[debug read memory 0xcf04]==0 && [debug read memory 0xcf05]==0} pause;set ::psg_samples {};sample_psg}
 after time 69 {check {[llength [lsort -unique $::psg_samples]]>1} psg_changes;keymatrixdown 4 32}
 after time 71 {keymatrixup 4 32}
 after time 73 {check {[debug read memory 0xcf04]!=0 || [debug read memory 0xcf05]!=0} resume;keymatrixdown 7 4}
 after time 75 {check {[debug read memory 0xcf0f]==1} escape;check {[debug read {PSG regs} 8]==0 && [debug read {PSG regs} 9]==0 && [debug read {PSG regs} 10]==0} muted;close $log;exit}
}
proc capture {} {
 screenshot -raw [file join [pwd] frame.png]
 if {@V9990@} {
  set expected {0 0 1 1 2 3 2 3 5 3 5 7 4 7 10 6 10 13 9 13 16 13 18 21 5 6 7 9 10 11 14 15 16 20 21 22 25 27 28 31 31 30 9 27 31 23 17 8}
  set actual {}
  for {set c 0} {$c<16} {incr c} {
   for {set channel 0} {$channel<3} {incr channel} {
    lappend actual [expr {[debug read {Sunrise GFX9000 palette} [expr {$c*4+$channel}]] & 31}]
   }
  }
  check {$actual eq $expected} palette_rgb5
  set f [open palette.bin wb];puts -nonewline $f [debug read_block {Sunrise GFX9000 palette} 0 64];close $f
 }
 set f [open debuggables.txt w];puts $f [debug list];close $f
 controls
}
debug set_bp @_scene_ready@ {} {
 if {@V9990@} {after time 0.01 {set videosource GFX9000}}
 debug write memory 0xcf10 2;debug write memory 0xcf12 37;debug write memory 0xcf13 37;debug write memory 0xcf11 1
 debug cont
}
debug set_bp @_frame_done@ {} {
 if {!$captured} {set captured 1;after time 0.05 capture}
 debug cont
}
after realtime @TIMEOUT@ {puts $log TIMEOUT;close $log;exit 1}
