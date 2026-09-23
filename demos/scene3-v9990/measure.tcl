set save_settings_on_exit false
set throttle false
set maxframeskip 0
set sound_driver null
set cmdtiming real
set log [open timings.tsv w];fconfigure $log -buffering line
set epoch -1;set started -1;set drawn -1;set measuring 0;set index 0
proc next_sample {} {global index;debug write memory 0xcf12 [expr {$index&127}];debug write memory 0xcf13 $index;debug write memory 0xcf11 1}
debug set_bp @_scene_ready@ {} {
 set epoch [machine_info time]
 debug write memory 0xcf10 0
 debug cont
}
debug set_bp @_frame_start@ {} {set started [machine_info time];debug cont}
debug set_bp @_draw_done@ {} {set drawn [machine_info time];debug cont}
debug set_bp @_frame_done@ {} {
 set ended [machine_info time]
 if {(@MODE@==0 && $epoch>=0 && $started >= $epoch+5) || (@MODE@==1 && $measuring)} {
  puts $log "$started\t$drawn\t$ended\t[debug read memory 0xcf04]\t[debug read memory 0xcf05]"
 }
 if {[debug read memory 0xcf06]} {close $log;exit 1}
 if {@MODE@==0 && $epoch>=0 && $ended >= $epoch+20} {close $log;exit}
 if {@MODE@==1 && $ended >= $epoch+5} {
  if {$measuring} {incr index} else {set measuring 1;debug write memory 0xcf10 2}
  if {$index==256} {close $log;exit}
  after time 0.001 {next_sample}
 }
 debug cont
}
after realtime @TIMEOUT@ {puts $log "TIMEOUT";close $log;exit 1}
