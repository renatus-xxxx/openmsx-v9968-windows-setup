set log [open result.txt w]
fconfigure $log -buffering line
after realtime @TIMEOUT@ {puts $log "TIMEOUT";close $log;exit 1}
set save_settings_on_exit false
set throttle false
set maxframeskip 0
set sound_driver null
set cmdtiming real
after time 2 {if {@V9990@} {catch {set videosource GFX9000} err;puts $log $err}}
puts $log [debug list]
debug set_bp @_scene_ready@ {} {puts $log "READY";debug cont}
after time 10 {
 puts $log "FRAME=[peek16 0xcf00] FAULT=[debug read memory 0xcf06] TICKS=[peek16 0xcf02]"
 catch {screenshot -raw frame.png} err;puts $log $err
 set f [open regs.bin wb]
 if {@V9990@} {puts -nonewline $f [debug read_block {Sunrise GFX9000 regs} 0 64]}
 close $f
 close $log
 exit
}
