set save_settings_on_exit false
set throttle false
set maxframeskip 0
set sound_driver null
set seen {}
set controls_ok 1
set labels_ok 1
set header_stats {}
set water_motion_ok 0
set water_check {}
set water_off_visible 0
set water_on_visible 0
set water_header_off 0
set water_header_on 0
source test-symbols.tcl
proc check_water_frame {} {
 global water_check water_off_visible water_on_visible
 global water_header_off water_header_on
 if {$water_check eq {}} {return}
 # Before flip: completed back page, same-frame immutable source on page 2.
 set back [expr {1-(([debug read "VDP regs" 2] >> 5) & 1)}]
 set source [debug read_block VRAM [expr {65536+20*128}] [expr {156*128}]]
 set drawn [debug read_block VRAM [expr {$back*32768+20*128}] [expr {156*128}]]
 if {$water_check eq {off} && $source eq $drawn} {set water_off_visible 1}
 if {$water_check eq {on} && $source ne $drawn} {set water_on_visible 1}
 # Rows 0-4, above the header text, used to be restored from the background
 # page and stood still while everything below them waved. They are part of the
 # distortion now, so they must match the clean source under the identity table
 # and differ from it under the wave, exactly like the body does.
 set hsource [debug read_block VRAM 65536 640]
 set hdrawn [debug read_block VRAM [expr {$back*32768}] 640]
 if {$water_check eq {off} && $hsource eq $hdrawn} {set water_header_off 1}
 if {$water_check eq {on} && $hsource ne $hdrawn} {set water_header_on 1}
}
debug set_bp $flip_address {} {check_water_frame}
# Every scene draws its header onto the picture with one transparent blit from
# a nine-row strip that already holds the drop shadow behind the text. Three
# things have to hold, and checking only the first of them leaves two ways to
# pass while broken. Each non-zero pixel of the strip must appear on the back
# page at the matching place; the strip must actually carry a header, so that a
# source gone blank cannot pass by having nothing left to compare; and the
# picture under the colour-0 pixels must survive, which is what makes the blit
# transparent rather than a black box around the text. Counting how much of the
# picture is still there catches an opaque blit, which would write colour 0
# across the whole strip.
proc row_pixels {addr} {
    binary scan [debug read_block VRAM $addr 128] cu* bytes
    set row {}
    foreach b $bytes {lappend row [expr {$b>>4}] [expr {$b&15}]}
    return $row
}
proc check_shadow_header {page scene} {
    global labels_ok header_stats
    set src {}
    set dst {}
    set base [expr {122880+$scene*9*128}]
    for {set y 0} {$y < 9} {incr y} {lappend src [row_pixels [expr {$base+$y*128}]]}
    for {set y 0} {$y < 14} {incr y} {lappend dst [row_pixels [expr {$page*32768+$y*128}]]}
    set shadow 0
    set glyphs 0
    set kept 0
    for {set y 0} {$y < 9} {incr y} {
        for {set x 0} {$x < 186} {incr x} {
            set glyph [lindex $src $y $x]
            set drawn [lindex $dst [expr {5+$y}] [expr {8+$x}]]
            if {$glyph == 0} {
                if {$drawn != 0} {incr kept}
                continue
            }
            if {$glyph == 1} {incr shadow} else {incr glyphs}
            if {$drawn != $glyph} {set labels_ok 0}
        }
    }
    # Every scene's strip carries about 330 shadow and 380 text pixels. A
    # source gone blank would leave nothing to compare and pass silently.
    if {$shadow < 200 || $glyphs < 200} {set labels_ok 0}
    # Scenes 0 to 4 lay a background image over the whole screen, so the 964
    # colour-0 positions of the strip sit on a picture and about 940 of them
    # come back non-zero; an opaque blit would flatten every one of them to
    # colour 0. Scene 6 composes its own picture and is legitimately almost
    # black behind the header at the sampled moment, so the floor is not
    # applied there; the count is still reported.
    if {$scene != 5 && $kept < 500} {set labels_ok 0}
    # Scene 6 recycles page 2 as the history of its feedback loop, and the HUD
    # is drawn after the capture so that the header never recurses. That is an
    # invariant worth testing rather than asserting: if the order were wrong,
    # the strip would be sitting on page 2 at the very place it occupies on the
    # screen. Count the non-zero strip pixels that do match there. A handful
    # match by chance; a captured header would match nearly all of them.
    set echoed 0
    if {$scene == 5} {
        set hist {}
        for {set y 0} {$y < 14} {incr y} {lappend hist [row_pixels [expr {65536+$y*128}]]}
        for {set y 0} {$y < 9} {incr y} {
            for {set x 0} {$x < 186} {incr x} {
                set glyph [lindex $src $y $x]
                if {$glyph == 0} continue
                if {[lindex $hist [expr {5+$y}] [expr {8+$x}]] == $glyph} {incr echoed}
            }
        }
        if {$echoed > 400} {set labels_ok 0}
    }
    lappend header_stats "$scene:$shadow/$glyphs/$kept/$echoed"
}
proc sample {n} {
    global throttle seen labels_ok header_stats
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
    check_shadow_header $page $scene
    # SCENE_LABELS is now the whole header check. Nothing is restored behind the
    # header any more, in any scene, so there is no strip left to compare
    # against the background page; WATER_HEADER_OFF/ON cover Scene 3's header
    # rows moving with the water.
    puts $f "SCENE_LABELS=$labels_ok HEADER=[lindex $header_stats end]"
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
# Select Scene 6 with key '6' (row 0 bit 6) rather than relying on where the
# automatic cycle happens to be: interrupts are disabled while drawing, so the
# tick clock drifts behind real time by a machine-dependent amount. Sample well
# after entry so the 180-tick opening, which draws no header, has finished.
after time 76 {keymatrixdown 0 64}
after time 76.6 {keymatrixup 0 64}
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
    # Bit 5 of R20 is picked at boot by running one LRMM without it and seeing
    # whether the transfer happened. On this fork it does not, so the byte must
    # come out 0x31 and R20 must actually hold it. The probe then runs again
    # under the chosen byte and reports at 0xcf0a whether LRMM worked, so a
    # wrong choice shows up here instead of silently losing Scene 6's feedback,
    # which is the only thing bit 5 gates.
    set r20_selected [debug read memory 0xcf09]
    set r20_live [debug read "VDP regs" 20]
    set r20_confirmed [debug read memory 0xcf0a]
    set r20_ok [expr {$r20_selected == 0x31 && $r20_live == 0x31 && $r20_confirmed == 1}]
    puts $f "R20_SELECTED=$r20_selected R20_LIVE=$r20_live R20_CONFIRMED=$r20_confirmed R20_OK=$r20_ok"
    puts $f "CONTROLS=$controls_ok MAPPER=[debug read memory 0xcf07] WATER_POLYGON_MOVES=$water_motion_ok"
    puts $f "WATER_OFF_VISIBLE=$water_off_visible WATER_ON_VISIBLE=$water_on_visible"
    puts $f "WATER_HEADER_OFF=$water_header_off WATER_HEADER_ON=$water_header_on"
    set ok [expr {[lsort -unique $seen] eq "0 1 2 3 4 5" && [debug read memory 0xcf06] == 0 && [debug read "VDP regs" 1] == 0 && $water_off_visible && $water_on_visible && $water_header_off && $water_header_on && $r20_ok && $controls_ok && $labels_ok && $water_motion_ok && [debug read memory 0xcf07] == 1}]
    puts $f "SCENES_AND_ESCAPE=[expr {$ok ? {PASS} : {FAIL}}]"
    close $f
    exit
}
