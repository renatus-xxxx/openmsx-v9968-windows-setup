/* Standalone V9968 conformance cartridge.

   There is no single agreed V9968: the pinned openMSX fork and the FPGA
   implementations disagree on at least one register bit, and that was found
   only because a demo written against the emulator would not run on hardware.
   This cartridge does not assume which side is right. It runs a fixed set of
   experiments and prints what the machine it is running on actually did, so
   that the same ROM produces a comparable line of numbers everywhere.

   Read the printed values against docs/v9968-divergence.md, which records what
   each implementation has been observed to report.

   Identification sequence: HRA! devcon/msx_vdp.c, init_vdp().
   Intended for C-BIOS MSX2+ startup (not an ISR or a generic saved-state API).

   Fresh cartridge startup only: experiments overwrite scratch VRAM and VDP
   registers, then initialize a new text screen. This is not state preserving.
   Requested addresses are >=0x8000; an unknown implementation can alias them.
   No disk, flash programming or mapper writes are performed by this code. */
#include <stdio.h>
#include <stdlib.h>

#define CTRL 0x99
#define DATA 0x98

static unsigned char id;
static unsigned char b5_off, b5_on;          /* R20 bit 5 and extended commands */
static unsigned char lrmm_timp, lrmm_imp;    /* the transparent logical operation */
static unsigned char step0, step1;           /* where the source reading starts */
static unsigned int  ce_rise, ce_fall;       /* how long the engine takes to react */
static unsigned char vram[4];                /* aliasing above 32 KiB */
static unsigned char fault, ce_seen, selected_r20, lrmm_available;
#define START_POLLS 1024
#define IDLE_POLLS 20000

static void wr(unsigned char r, unsigned char v) {
    outp(CTRL, v); outp(CTRL, r | 0x80);
}
static void wrw(unsigned char r, unsigned int v) {
    wr(r, (unsigned char)v); wr(r + 1, (unsigned char)(v >> 8));
}
/* Wait for the command engine, but never forever: a machine that does not
   implement the command at all must still reach the end of the run. */
static void idle(void) {
    unsigned int budget = IDLE_POLLS;
    wr(15, 2);
    while ((inp(CTRL) & 1) && --budget) ;
    if (!budget) { fault = 1; wr(46, 0); } /* abort, never use partial results */
    wr(15, 0);
}
/* A bounded grace period for a late CE assertion. Not a hardware timing
   guarantee: a pulse can finish unseen or a command may be unsupported. */
static void finish_command(void) {
    unsigned int spin;
    wr(15, 2);
    for (spin=0; spin<START_POLLS; ++spin) if (inp(CTRL)&1) break;
    idle();
}
static void poke(unsigned int addr, unsigned char page, unsigned char v) {
    wr(14, page);
    outp(CTRL, (unsigned char)addr);
    outp(CTRL, (unsigned char)(0x40 | ((addr >> 8) & 0x3f)));
    outp(DATA, v);
}
static unsigned char peek(unsigned int addr, unsigned char page) {
    wr(14, page);
    outp(CTRL, (unsigned char)addr);
    outp(CTRL, (unsigned char)((addr >> 8) & 0x3f));
    return inp(DATA);
}
/* A rectangle fill, used to prepare and to mark. LMMV writes one colour into
   every pixel of the rectangle, so it needs no source. */
static void box(unsigned int x, unsigned int y,
                 unsigned int w, unsigned int h, unsigned char c) {
    if (fault) return;
    idle(); if (fault) return;
    wrw(36, x); wrw(38, y); wrw(40, w); wrw(42, h);
    wr(44, c); wr(45, 0); wr(46, 0x80);
    finish_command();
}
/* One LRMM with the given logical operation in the low nibble of the command.
   vx/vy are the source step in 256ths of a pixel: 256 is one to one. */
static void lrmm(unsigned int sx, unsigned int sy,
                 unsigned int dx, unsigned int dy,
                 unsigned int w, unsigned int h,
                 unsigned int vx, unsigned int vy, unsigned char cmd) {
    if (fault) return;
    idle(); if (fault) return;
    wrw(32, sx); wrw(34, sy); wrw(36, dx); wrw(38, dy);
    wrw(40, w); wrw(42, h);
    wrw(47, vx); wrw(49, vy);
    wrw(51, 0); wrw(53, 256); wrw(55, 255); wrw(57, 1023);
    wr(44, 0); wr(45, 0); wr(46, cmd);
    finish_command();
}

/* --- the experiments ----------------------------------------------------- */

/* Does the extended command set need bit 5 of R20 to be on? The pinned fork
   gates the extended commands on it; an FPGA map documented by HRA! uses the
   same bit for flat interlace and runs the commands without it. Running one
   1:1 transfer under each setting tells them apart without assuming either. */
static void probe_r20_bit5(void) {
    wr(20, 0x11);
    box(0, 256, 8, 2, 15);
    box(16, 256, 8, 2, 0);
    if (fault) return;
    if (peek(0,2)!=0xff || peek(8,2)!=0) { fault=2; return; }
    lrmm(0, 256, 16, 256, 8, 2, 256, 0, 0x38);
    b5_off = (peek(0x0008, 2) == 0xff);
    if (fault) return;

    wr(20, 0x31);
    box(0, 256, 8, 2, 15);
    box(16, 256, 8, 2, 0);
    if (fault) return;
    if (peek(0,2)!=0xff || peek(8,2)!=0) { fault=2; return; }
    lrmm(0, 256, 16, 256, 8, 2, 256, 0, 0x38);
    b5_on = (peek(0x0008, 2) == 0xff);
    selected_r20=b5_off?0x11:0x31;
    lrmm_available=b5_off||b5_on;
    wr(20, selected_r20); /* do not leave FPGA flat-interlace enabled */
}

/* The low nibble of the command byte is the logical operation. Operation 8 is
   the transparent variant, which must leave the destination alone wherever the
   source pixel is colour 0; operation 0 must overwrite it. Filling the
   destination with 15 and the source with 0 separates the two: transparent
   leaves 0xff behind, opaque leaves 0x00. */
static void probe_transparency(void) {
    box(0, 258, 8, 2, 0);
    box(16, 258, 8, 2, 15);
    lrmm(0, 258, 16, 258, 8, 2, 256, 0, 0x38);
    lrmm_timp = peek(0x0108, 2);

    box(16, 258, 8, 2, 15);
    lrmm(0, 258, 16, 258, 8, 2, 256, 0, 0x30);
    lrmm_imp = peek(0x0108, 2);
}

/* Does the source reading position advance before the first destination pixel
   or after it? A 1:1 opaque copy of a row whose pixels all differ answers it:
   if the first destination pixel is the first source pixel, the position
   advances after the write; if it is the second, it advances before. */
static void probe_step(void) {
    unsigned char x;
    idle(); if (fault) return;
    wr(14, 2);
    outp(CTRL, 0x00);
    outp(CTRL, 0x42);                        /* physical 0x8200: y=260, x=0 */
    for (x = 0; x < 4; ++x) outp(DATA, (unsigned char)(((2 * x + 1) << 4) | (2 * x + 2)));
    box(16, 260, 4, 1, 15);
    lrmm(0, 260, 16, 260, 4, 1, 256, 0, 0x30);
    x=peek(0x0208, 2);
    step0 = x >> 4;
    step1 = x & 15;
}

/* How long does the engine take to say it is busy, and then to finish? On an
   emulator that completes a command between two instructions the first count
   is zero and the flag may never be seen high at all; on real silicon it is
   not. A probe that reads the result back too early concludes that nothing
   happened, which is the failure this cartridge exists to make visible. */
static void probe_timing(void) {
    unsigned int spin;
    idle(); if (fault) return;
    wr(15, 2);
    wrw(36, 0); wrw(38, 256); wrw(40, 256); wrw(42, 192);
    wr(44, 0); wr(45, 0); wr(46, 0xc0);      /* HMMV over a whole page */
    ce_rise = 0;
    for (spin = 0; spin < 20000; ++spin) { if (inp(CTRL) & 1) break; ++ce_rise; }
    ce_seen=(spin<20000);
    ce_fall = 0;
    for (spin = 0; spin < 60000; ++spin) { if (!(inp(CTRL) & 1)) break; ++ce_fall; }
    if (spin==60000) { fault=1; wr(46,0); }
    wr(15, 0);
}

/* Four locations inside the first 128 KiB: 8000,10000,18000,1c000.
   These are NOT uniformly 32 KiB apart and do not establish 256 KiB capacity.
   Save before writing so aliases can also be restored. */
static void probe_vram(void) {
    unsigned char saved[4];
    idle(); if (fault) return;
    saved[0]=peek(0,2); saved[1]=peek(0,4);
    saved[2]=peek(0,6); saved[3]=peek(0,7);
    poke(0x0000, 2, 0xa1);
    poke(0x0000, 4, 0xa2);
    poke(0x0000, 6, 0xa3);
    poke(0x0000, 7, 0xa4);
    vram[0] = peek(0x0000, 2);
    vram[1] = peek(0x0000, 4);
    vram[2] = peek(0x0000, 6);
    vram[3] = peek(0x0000, 7);
    poke(0,2,saved[0]); poke(0,4,saved[1]);
    poke(0,6,saved[2]); poke(0,7,saved[3]);
}

int main(void) {
#asm
    di
#endasm
    wr(21, 0x3a); wr(15, 1);
    id = (inp(CTRL) >> 1) & 31;
    wr(15, 0); wr(21, 0x3b);

    if (id == 3) {
        wr(0, 6); wr(1, 0); wr(2, 31); wr(7, 0);
        wr(8,10); wr(9,0); wr(23,0); wr(25,0); wr(26,0); wr(27,0);
        probe_r20_bit5();
        if (!fault && lrmm_available) probe_transparency();
        if (!fault && lrmm_available) probe_step();
        if (!fault) probe_timing();
        if (!fault) probe_vram();
        wr(46,0); wr(20,0); wr(14,0); wr(15,0); wr(16,0); wr(17,0);
        wr(21,0x3b); /* standard palette protocol before BIOS initialization */
    }
#asm
    call 0x006c                              ; INITXT, back to the text screen
    ei
#endasm

    /* The first three lines are the identification report this cartridge has
       always printed, and docs/setup.md tells people to look for them. The
       conformance lines are added after them, not in place of them. */
    puts("V9968 / C ROM TEST");
    printf("VDP ID=%u\n", (unsigned int)id);
    puts(id == 3 ? "V9968 IDENTIFIED" : "V9968 NOT IDENTIFIED");
    if (id != 3) {
        puts("NO FURTHER TESTS RUN");
    } else if (fault) {
        printf("PROBE ERROR code=%u\n", (unsigned int)fault);
        puts("PARTIAL RESULTS DISCARDED");
    } else {
        printf("R20B5  off=%u on=%u\n", (unsigned int)b5_off, (unsigned int)b5_on);
        printf("R20SEL value=%02x\n", (unsigned int)selected_r20);
        if (lrmm_available) {
        printf("LRMMOP timp=%02x imp=%02x\n",
               (unsigned int)lrmm_timp, (unsigned int)lrmm_imp);
        printf("LRMMST d0=%u d1=%u\n", (unsigned int)step0, (unsigned int)step1);
        } else puts("LRMM TESTS SKIPPED");
        printf("CE     rise=%u fall=%u\n", ce_rise, ce_fall);
        printf("CESEEN value=%u\n", (unsigned int)ce_seen);
        printf("VRAM   %02x %02x %02x %02x\n",
               (unsigned int)vram[0], (unsigned int)vram[1],
               (unsigned int)vram[2], (unsigned int)vram[3]);
    }
    puts("REPORT THESE LINES");

    for (;;) {
#asm
        halt
#endasm
    }
}
