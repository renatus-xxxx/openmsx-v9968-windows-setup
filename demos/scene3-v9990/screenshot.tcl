set save_settings_on_exit false
set throttle true
set maxframeskip 0
set sound_driver null
set cmdtiming real
set captured 0
proc capture {} {
 if {@V9990@} {
  foreach {name dev len} {regs {Sunrise GFX9000 regs} 64 palette {Sunrise GFX9000 palette} 64 vram {Sunrise GFX9000 VRAM} 524288} {set f [open $name.bin wb];puts -nonewline $f [debug read_block $dev 0 $len];close $f}
 }
 screenshot -raw [file join [pwd] frame.png];exit
}
debug set_bp @_scene_ready@ {} {
 if {@V9990@} {after time 0.01 {set videosource GFX9000}}
 debug write memory 0xcf10 2;debug write memory 0xcf12 37;debug write memory 0xcf13 37;debug write memory 0xcf11 1
 debug cont
}
debug set_bp @_frame_done@ {} {
 incr captured
 if {$captured==1} {after time 0.001 {debug write memory 0xcf11 1}}
 if {$captured==2} {after time 0.2 capture}
 debug cont
}
after realtime @TIMEOUT@ {exit 1}
