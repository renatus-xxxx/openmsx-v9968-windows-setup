set save_settings_on_exit false
set throttle false
set sound_driver null
set cmdtiming real
proc finish_check {} {
 set f [open fault-check.txt w]
 set fault [debug read memory 0xcf06]
 set muted [expr {[debug read {PSG regs} 8]==0 && [debug read {PSG regs} 9]==0 && [debug read {PSG regs} 10]==0}]
 puts $f "FAULT=$fault MUTED=$muted"
 close $f
 if {$fault != @FAULT@ || !$muted} {exit 1}
 exit
}
debug set_bp @_scene_ready@ {} {
 if {@FAULT@==3} {
  debug write {Sunrise GFX9000 regs} 9 0
 } else {
  # Inject a non-completing command: CPU-to-VRAM transfer with no input data.
  debug write {Sunrise GFX9000 regs} 40 255
  debug write {Sunrise GFX9000 regs} 41 0
  debug write {Sunrise GFX9000 regs} 42 255
  debug write {Sunrise GFX9000 regs} 43 0
  debug write {Sunrise GFX9000 regs} 52 16
 }
 after time 3 finish_check
 debug cont
}
after realtime @TIMEOUT@ {exit 1}
