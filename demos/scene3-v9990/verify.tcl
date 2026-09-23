set save_settings_on_exit false
set throttle false
set maxframeskip 0
set sound_driver null
set cmdtiming real
set log [open frames.tsv w];fconfigure $log -buffering line
set sample 0
proc request_frame {} {
 global sample
 set pose [expr {$sample<128?$sample:37}]
 set phase [expr {$sample<128?0:($sample-128)&255}]
 debug write memory 0xcf12 $pose
 debug write memory 0xcf13 $phase
 debug write memory 0xcf11 1
}
debug set_bp @_scene_ready@ {} {
 debug write memory 0xcf10 2
 request_frame
 debug cont
}
debug set_bp @_frame_done@ {} {
 if {[debug read memory 0xcf06]} {puts $log "FAULT";close $log;exit 1}
 set f [open [format "vram-%03d.bin" $sample] wb]
 if {@V9990@} {
  puts -nonewline $f [debug read_block {Sunrise GFX9000 VRAM} 0 65536]
  puts -nonewline $f [debug read_block {Sunrise GFX9000 VRAM} 262144 65536]
 } else {puts -nonewline $f [debug read_block VRAM 0 131072]}
 close $f
 puts $log "$sample\t[debug read memory 0xcf04]\t[debug read memory 0xcf05]\t[debug read memory 0xcf07]"
 incr sample
 if {$sample==385} {close $log;exit}
 after time 0.001 {request_frame}
 debug cont
}
after realtime @TIMEOUT@ {puts $log "TIMEOUT";close $log;exit 1}
