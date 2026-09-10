proc schedule {t script} {after time $t [list guarded $script]}
proc guarded {script} {
 global report
 if {[catch {uplevel #0 $script} error opts]} {
  puts $report "TCL_ERROR=$error"
  puts $report [dict get $opts -errorinfo]
  flush $report
 }
}
set save_settings_on_exit false
set throttle false
set maxframeskip 0
set sound_driver null
set report [open results.txt w]
set failed 0
proc check {name condition} {
 global failed report
 puts $report "$name=[expr {$condition ? {PASS} : {FAIL}}]"
 if {!$condition} {set failed 1}
}
proc shot {name} {
 global throttle
 set throttle true
 schedule 0.2 [list finish_shot $name]
}
proc finish_shot {name} {
 global report throttle
 if {[catch {screenshot -raw $name} error]} {puts $report "SCREENSHOT_ERROR=$error"}
 set throttle false
}
proc state {mode} {
 check "mode-$mode" [expr {[debug read memory 0xcf09]==$mode}]
 check "fault-$mode" [expr {[debug read memory 0xcf06]==0}]
 if {[debug read memory 0xcf0a]==3} {
  check "R20-$mode" [expr {[debug read {VDP regs} 20]==[lindex {17 1 0} $mode]}]
 }
}
proc begin_sample {mode} {
 global sample_frame sample_ticks
 state $mode
 set sample_frame [peek16 0xcf00];set sample_ticks [peek16 0xcf02]
}
proc end_sample {mode} {
 global sample_frame sample_ticks report
 set frames [expr {([peek16 0xcf00]-$sample_frame)&65535}]
 set ticks [expr {([peek16 0xcf02]-$sample_ticks)&65535}]
 check "frames-$mode" [expr {$frames>0 && $ticks>0}]
 puts $report "SAMPLE $mode $frames $ticks [expr {$frames*60.0/$ticks}]"
 shot "mode-$mode.png"
}
proc press_f {} {keymatrixdown 3 8;schedule 0.8 {keymatrixup 3 8}}
schedule 8 {keymatrixdown 4 32}
schedule 9 {keymatrixup 4 32}
schedule 10 {
 global report
 puts $report "VDP=[debug read memory 0xcf0a] CPU=[debug read memory 0xcf0b]"
 set extended [expr {[debug read memory 0xcf0a]==3}]
 set initial [expr {$extended?0:2}]
 begin_sample $initial
 schedule 12 [list end_sample $initial]
 if {$extended} {
  schedule 13 {press_f}
  schedule 15 {begin_sample 1}
  schedule 27 {end_sample 1}
  schedule 28 {press_f}
  schedule 30 {begin_sample 2}
  schedule 42 {end_sample 2}
  schedule 43 {press_f}
  schedule 45 {state 0}
 } else {
  schedule 13 {press_f}
  schedule 15 {state 2}
 }
 schedule 46 {set throttle true}
 # P freezes geometry and water at a reproducible pose without pausing rendering.
 schedule 48 {
  check pause [expr {[debug read memory 0xcf0e]==1}]
  screenshot -raw fixed-full.png
  set f [open full-palette.bin wb];puts -nonewline $f [debug read_block {VDP palette} 0 [debug size {VDP palette}]];close $f
  schedule 1 {press_f}
 }
 schedule 52 {
  screenshot -raw fixed-fast.png
  set f [open fast-palette.bin wb];puts -nonewline $f [debug read_block {VDP palette} 0 [debug size {VDP palette}]];close $f
  schedule 1 {press_f}
 }
 schedule 56 {screenshot -raw fixed-compat.png;schedule 1 {keymatrixdown 7 4}}
 schedule 58 {
  check escape [expr {([debug read {VDP regs} 1]&64)==0}]
  puts $report "TEST=[expr {$failed?{FAIL}:{PASS}}]"
  close $report;exit $failed
 }
}
schedule 75 {exit 1}
