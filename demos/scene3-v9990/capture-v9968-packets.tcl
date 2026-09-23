# Capture a settled display (two identical requests), palette, and CPU settings.
set save_settings_on_exit false
set throttle true
set maxframeskip 0
set sound_driver null
set cmdtiming real
set captured 0
proc capture {} {
 screenshot -raw [file join [pwd] frame.png]
 set f [open palette.bin wb];puts -nonewline $f [debug read_block {VDP palette} 0 [debug size {VDP palette}]];close $f
 set f [open conditions.txt w]
 puts $f "CPU=[get_active_cpu] SPEED=[set ::speed]"
 foreach query {z80_freq r800_freq} {
  if {[catch {machine_info $query} value]} {set value "unavailable ($value)"}
  puts $f "$query=$value"
 }
 puts $f "R20=[debug read {VDP regs} 20] FAULT=[debug read memory 0xcf06]"
 close $f;exit
}
debug set_bp @_scene_ready@ {} {
 debug write memory 0xcf10 2;debug write memory 0xcf12 37;debug write memory 0xcf13 37;debug write memory 0xcf11 1
 debug cont
}
debug set_bp @_frame_done@ {} {
 incr captured
 if {$captured==1} {after time 0.001 {debug write memory 0xcf11 1}}
 if {$captured==2} {after time 0.2 {
  if {[catch {capture} error]} {set f [open capture-error.txt w];puts $f $error;close $f;exit 1}
 }}
 debug cont
}
after realtime @TIMEOUT@ {exit 1}
