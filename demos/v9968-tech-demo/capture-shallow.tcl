source test-symbols.tcl
set save_settings_on_exit false
set throttle false
set maxframeskip 0
set sound_driver null
set phases {}
set masks {}
set sampled 0
set forced_tick 0
set forced_index 0
set jumps {0 1 2 3 4 5 6 7 8 9 10 11 12 13 31 63}
# Exhaustive model test only: inject deterministic frame arguments. Timing
# and recording scripts never use these breakpoints.
debug set_bp $shallow_draw_address {} {
 if {$::forced_index>0} {
  set previous [expr {[debug read memory 0xcf10]+256*[debug read memory 0xcf11]}]
  set f [open "sprite-$previous.bin" wb]
  puts -nonewline $f [debug read_block VRAM 97792 504]
  puts -nonewline $f [debug read_block VRAM 86016 4096]
  puts -nonewline $f [debug read_block {VDP regs} 0 32]
  close $f
 }
 set sp [reg SP]
 debug write memory [expr {$sp+2}] [expr {$::forced_tick&255}]
 debug write memory [expr {$sp+3}] [expr {$::forced_tick>>8}]
}
proc inspect {} {
 if {$::forced_index>=272} return
 set tick [expr {[debug read memory 0xcf10]+256*[debug read memory 0xcf11]}]
 set phase [expr {($tick>>1)&127}]
 set mask [expr {($tick>>2)&127}]

 set page [expr {(([debug read "VDP regs" 2]>>5)&1)}]
 set f [open "frame-$tick-$page.bin" wb]
 puts -nonewline $f [debug read_block VRAM 0 131072]
 close $f
 if {[lsearch -exact $::phases $phase]<0} {lappend ::phases $phase}
 if {[lsearch -exact $::masks $mask]<0} {lappend ::masks $mask}
 incr ::sampled
 incr ::forced_index
 if {$::forced_index==272} {after time 0.01 finish_capture}
 if {$::forced_index<256} {
  set ::forced_tick [expr {2*$::forced_index}]
 } elseif {$::forced_index<272} {
  set jump [lindex $::jumps [expr {$::forced_index-256}]]
  set ::forced_tick [expr {($tick+4*$jump)&511}]
 }
}
debug set_bp $shallow_palette_address {} {inspect}
after time 5 {keymatrixdown 0 128}
after time 6 {keymatrixup 0 128}
proc finish_capture {} {
 set f [open telemetry.txt w]
 puts $f "CONTROLLED_FRAMES=$::sampled PHASES=[llength $::phases] MASKS=[llength $::masks] FAULT=[debug read memory 0xcf06]"
 puts $f "CAPTURE=[expr {[llength $::phases]==128 && [llength $::masks]==128 && $::sampled==272 && [debug read memory 0xcf06]==0 ? {PASS} : {FAIL}}]"
 close $f
 exit
}

# Deadline remains a failing completion when coverage is incomplete.
after time 120 finish_capture
