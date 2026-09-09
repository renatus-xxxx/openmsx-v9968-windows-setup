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
    if {[string first "VDP ID=$env(V9968_EXPECT_ID)" $result] >= 0} {
        puts $f "SELFTEST=PASS"
    } else {
        puts $f "SELFTEST=FAIL"
    }
    close $f
    catch {screenshot -raw "$env(V9968_TEST_LOG).png"}
    exit
}
