set save_settings_on_exit false
set throttle false
set maxframeskip 0
set sound_driver null
after time 8 {keymatrixdown 0 8}
after time 9 {keymatrixup 0 8;set throttle true}
for {set i 0} {$i < 16} {incr i} {
 after time [expr {10.0+$i*2.0943951/16.0}] [list screenshot -raw [format "water-%02d.png" $i]]
}
after time 12.5 {
 set f [open telemetry.txt w]
 set ok [expr {[debug read memory 0xcf04] == 2 && [debug read memory 0xcf08] == 1 && [debug read memory 0xcf06] == 0 && [debug read memory 0xcf07] == 1}]
 puts $f "CAPTURE=[expr {$ok ? {PASS} : {FAIL}}]"
 close $f
 exit
}
