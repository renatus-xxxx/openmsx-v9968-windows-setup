/* Standalone V9968 identification cartridge.
   Identification sequence: HRA! devcon/msx_vdp.c, init_vdp().
   Intended for C-BIOS MSX2+ startup (not an ISR or a generic saved-state API). */
#include <stdio.h>
#include <stdlib.h>
static void wr(unsigned char r,unsigned char v) {
    outp(0x99,v); outp(0x99,r|0x80);
}
int main(void) {
    unsigned char id;
#asm
    di
#endasm
    wr(21,0x3a); wr(15,1);
    id=(inp(0x99)>>1)&31;
    wr(15,0); wr(21,0x3b);
#asm
    ei
#endasm
    puts("V9968 / C ROM TEST");
    printf("VDP ID=%u\n",(unsigned int)id);
    puts(id==3 ? "V9968 IDENTIFIED" : "V9968 NOT IDENTIFIED");

    for(;;) {
#asm
        halt
#endasm
    }
}
