# Diagnostic trace only: samples32 fixed pose/phase pairs after5sec.
# Command-poll time includes status-reading overhead, not pure hardware busy time.
# Remaining draw time includes C work, OUT/OTIR, other CE waits and IRQ service.
set save_settings_on_exit false
set throttle false
set sound_driver null
set cmdtiming real
set log [open profile.tsv w];fconfigure $log -buffering line
set enabled 0;set epoch -1;set index 0;set poll 0;set calls 0;set entered 0
proc request_profile {} {debug write memory 0xcf12 [expr {($::index*4)&127}];debug write memory 0xcf13 [expr {$::index*8}];debug write memory 0xcf11 1}
debug set_bp @_scene_ready@ {} {if {[debug read memory [expr {@_stream_wait_c@+5}]]!=230 || [debug read memory [expr {@_stream_wait_c@+6}]]!=1 || [debug read memory [expr {@_stream_wait_c@+7}]]!=200} {error "Unexpected polling instructions"};set epoch [machine_info time];debug cont}
debug set_bp @_frame_start@ {} {set started [machine_info time];set poll 0;set calls 0;debug cont}
debug set_bp @_stream_wait_c@ {$::enabled} {set entered [machine_info time];incr calls;debug cont}
debug set_bp [expr {@_stream_wait_c@+7}] {$::enabled && [reg A]==0} {set poll [expr {$poll+[machine_info time]-$entered}];debug cont}
debug set_bp @_draw_done@ {} {set drawn [machine_info time];debug cont}
debug set_bp @_frame_done@ {} {
 if {[debug read memory 0xcf06]} {close $log;exit 1}
 if {$enabled} {puts $log "$index\t[expr {$drawn-$started}]\t$poll\t$calls";incr index}
 if {$index==32} {close $log;exit}
 if {$epoch>=0 && [machine_info time]>=$epoch+5} {set enabled 1;debug write memory 0xcf10 2;after time 0.001 request_profile}
 debug cont
}
after realtime @TIMEOUT@ {close $log;exit 1}
