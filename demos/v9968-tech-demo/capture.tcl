set save_settings_on_exit false
set throttle false
set maxframeskip 0
set sound_driver null
set seen {}
set controls_ok 1
set labels_ok 1
set water_motion_ok 0
set water_check {}
set water_off_visible 0
set water_on_visible 0
source test-symbols.tcl
proc check_water_frame {} {
 global water_check water_off_visible water_on_visible
 if {$water_check eq {}} {return}
 # Before flip: completed back page, same-frame immutable source on page 2.
 set back [expr {1-(([debug read "VDP regs" 2] >> 5) & 1)}]
 set source [debug read_block VRAM [expr {65536+20*128}] [expr {156*128}]]
 set drawn [debug read_block VRAM [expr {$back*32768+20*128}] [expr {156*128}]]
 if {$water_check eq {off} && $source eq $drawn} {set water_off_visible 1}
 if {$water_check eq {on} && $source ne $drawn} {set water_on_visible 1}
}
debug set_bp $flip_address {} {check_water_frame}
proc sample {n} {
    global throttle seen labels_ok
    screenshot -raw "scene-$n.png"
    set f [open telemetry.txt a]
    binary scan [debug read_block memory 0xcf00 5] cu* d
    puts $f "[machine_info time] $d"
    puts $f "CPU=[get_active_cpu]"
    lappend seen [lindex $d 4]
    set scene [lindex $d 4]
    set expected_name [expr {$scene == 2 ? {SEABED.bin} : {BACKGROUND.bin}}]
    set expected_file [open $expected_name rb]
    set expected [read $expected_file];close $expected_file
    if {$expected ne [debug read_block VRAM 100352 22528]} {set labels_ok 0}
    puts $f "BACKGROUND_MATCH=$labels_ok"
    set page [expr {([debug read "VDP regs" 2] >> 5) & 1}]
    for {set row 0} {$row < 8} {incr row} {
        set source [expr {122880+$scene*1024+$row*128}]
        set dest [expr {$page*32768+(5+$row)*128+4}]
        if {[debug read_block VRAM $source 28] ne [debug read_block VRAM $dest 28]} {set labels_ok 0}
    }
    puts $f "SCENE_LABELS=$labels_ok"
    # Only Scene 3 restores the full header; other scenes may draw below text.
    set first_row [expr {$scene == 2 ? 0 : 5}]
    set end_row [expr {$scene == 2 ? 16 : 13}]
    for {set row $first_row} {$row < $end_row} {incr row} {
        set source [expr {98304+$row*128+32}]
        set dest [expr {$page*32768+$row*128+32}]
        if {[debug read_block VRAM $source 64] ne [debug read_block VRAM $dest 64]} {set labels_ok 0}
    }
    puts $f "TITLE_STABLE=$labels_ok"
    puts $f "FAULT=[debug read memory 0xcf06]"
    binary scan [debug read_block "VDP regs" 0 28] cu* regs
    puts $f "regs=$regs"
    close $f
    set throttle false
}
after time 9 {set throttle true}
after time 10 {sample 0}
after time 24 {set throttle true}
after time 25 {sample 1}
after time 39 {set throttle true}
after time 40 {sample 2}
after time 41 {
 set water_source_before [debug read_block VRAM 65536 24576]
}
after time 43 {
 set water_motion_ok [expr {[debug read memory 0xcf04] == 2 && $water_source_before ne [debug read_block VRAM 65536 24576]}]
}
after time 54 {set throttle true}
after time 55 {sample 3}
after time 69 {set throttle true}
after time 70 {sample 4}
after time 79 {set throttle true}
after time 80 {sample 5;keymatrixdown 0 8}
after time 82 {
 keymatrixup 0 8
 if {[debug read memory 0xcf04] != 2} {set controls_ok 0}
 # MSX Technical Data Book 1.3.5: row 5 bit 6 is Y, bit 4 is W.
 keymatrixdown 5 64
}
after time 83 {
 keymatrixup 5 64
 if {[debug read memory 0xcf08] != 1} {set controls_ok 0}
 keymatrixdown 5 16
}
after time 84 {
 if {[debug read memory 0xcf08] != 0} {set controls_ok 0}
 set water_check off
}
after time 84.5 {
 if {[debug read memory 0xcf08] != 0} {set controls_ok 0}
 keymatrixup 5 16
}
after time 85 {set water_check {};keymatrixdown 5 16}
after time 86 {set water_check on}
after time 87 {
 keymatrixup 5 16
 if {[debug read memory 0xcf08] != 1} {set controls_ok 0}
 set water_check {}
 keymatrixdown 0 2
}
after time 89 {
 keymatrixup 0 2
 if {[debug read memory 0xcf04] != 0} {set controls_ok 0}
 keymatrixdown 0 1
}
after time 90 {keymatrixup 0 1;keymatrixdown 7 4}
after time 93 {
    set f [open telemetry.txt a]
    puts $f "CONTROLS=$controls_ok MAPPER=[debug read memory 0xcf07] WATER_POLYGON_MOVES=$water_motion_ok"
    puts $f "WATER_OFF_VISIBLE=$water_off_visible WATER_ON_VISIBLE=$water_on_visible"
    set ok [expr {[lsort -unique $seen] eq "0 1 2 3 4" && [debug read memory 0xcf06] == 0 && [debug read "VDP regs" 1] == 0 && $water_off_visible && $water_on_visible && $controls_ok && $labels_ok && $water_motion_ok && [debug read memory 0xcf07] == 1}]
    puts $f "SCENES_AND_ESCAPE=[expr {$ok ? {PASS} : {FAIL}}]"
    close $f
    exit
}
