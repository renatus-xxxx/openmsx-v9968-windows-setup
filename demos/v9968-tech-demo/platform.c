/* Original demo platform support. Cartridge startup retains BIOS in page 0.
   CPU: turbo R CHGCPU entry 0180h, A=81h (R800 ROM + CPU LED).
   Keyboard: PPI C low nibble selects row, PPI B returns active-low keys.
   See DEVELOPMENT.md for reference and emulator verification. */
#include "platform.h"
__sfr __at (0xaa) keyboard_select;
__sfr __at (0xa9) keyboard_input;
void platform_r800_rom(void) __naked {
#asm
    push ix
    push iy
    ld a,081h
    call 0180h
    pop iy
    pop ix
    ret
#endasm
}
unsigned char platform_keyboard_row(unsigned char row){
    unsigned char saved=keyboard_select;
    unsigned char keys;
    keyboard_select=(saved&0xf0)|(row&0x0f);
    keys=keyboard_input;
    keyboard_select=saved;
    return keys;
}
