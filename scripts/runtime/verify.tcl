# This script only checks our cartridge's screen output, not a BIOS ID heuristic.
set save_settings_on_exit false
set throttle false
set sound_driver null
after time 9 {set throttle true}
after time 10 {
    set result [get_screen]
    set f [open $env(V9968_TEST_LOG) w]
    fconfigure $f -encoding utf-8
    puts $f [openmsx_info version]
    puts $f [machine_info config_name]
    puts $f [get_active_cpu]
    puts $f $result
    set expected $env(V9968_EXPECT_ID)
    set id_ok [regexp -line "^ *VDP ID=$expected *$" $result]
    set completed [expr {[string first "REPORT THESE LINES" $result] >= 0}]
    set failed [expr {[string first "PROBE ERROR" $result] >= 0}]
    if {$id_ok && $completed && !$failed} {
        puts $f "SELFTEST=PASS"
    } else {
        puts $f "SELFTEST=FAIL"
    }
    close $f
    catch {screenshot -raw "$env(V9968_TEST_LOG).png"}
    exit
}
