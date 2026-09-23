set save_settings_on_exit false
set throttle false
set sound_driver null
set cmdtiming real
set injected 0
proc finish_check {} {
 set fault [debug read memory 0xcf06]
 set muted [expr {[debug read {PSG regs} 8]==0 && [debug read {PSG regs} 9]==0 && [debug read {PSG regs} 10]==0}]
 set f [open fault-check.txt w];puts $f "FAULT=$fault MUTED=$muted";close $f
 if {$fault!=1 || !$muted} {exit 1}
 exit
}
debug set_bp @_stream_water_packets@ {} {
 if {!$injected} {
  set injected 1
  # HMMC waits for CPU input forever. Exercise the new stream's CE watchdog.
  debug write {VDP regs} 46 0
  foreach r {36 37 38 39 41 43 45} {debug write {VDP regs} $r 0}
  debug write {VDP regs} 40 128
  debug write {VDP regs} 42 128
  debug write {VDP regs} 46 240
  after time 3 finish_check
 }
 debug cont
}
after realtime @TIMEOUT@ {exit 1}
