set save_settings_on_exit false
set throttle true
set maxframeskip 0
set sound_driver null
after time 12 {
 set f [open missing-check.txt w]
 set fault [debug read memory 0xcf06]
 set text_present [expr {[string first "VIDEO DEVICE REQUIRED" [debug read_block VRAM 0 1024]]>=0}]
 set display [expr {([debug read {VDP regs} 1] & 64)!=0}]
 puts $f "FAULT=$fault DISPLAY=$display TEXT=$text_present"
 puts $f "RENDERER=$renderer SOURCE=$videosource"
 set pf [open diagnostic-palette.bin wb];puts -nonewline $pf [debug read_block {VDP palette} 0 32];close $pf
 set vf [open diagnostic-vram.bin wb];puts -nonewline $vf [debug read_block VRAM 0 16384];close $vf
 set rf [open diagnostic-regs.bin wb];puts -nonewline $rf [debug read_block {VDP regs} 0 64];close $rf
 close $f
 screenshot -raw [file join [pwd] missing-device.png]
 if {$fault!=2 || !$display || !$text_present} {exit 1}
 exit
}
after realtime @TIMEOUT@ {exit 1}
