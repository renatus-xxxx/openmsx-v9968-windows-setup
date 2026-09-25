/* Targets buppu3/openMSX d884c4b: R20 HS=1, EPAL=16. Bit 5 of R20 is not the
   same thing everywhere and is chosen at run time; see r20_select(). */
#include <stdlib.h>
#include <stdio.h>
#include "v9968.h"
#include "mapper.h"
#include "bank-layout.h"
#define ORB_SIZE 80
#ifndef VDP_BASE
#define VDP_BASE 152 /* 0x98 */
#endif
static const u8 palette_rgb5[48]={0,0,1,1,2,3,2,3,5,3,5,7,4,7,10,6,10,13,9,13,16,13,18,21,5,6,7,9,10,11,14,15,16,20,21,22,25,27,28,31,31,30,9,27,31,23,17,8};
__sfr __at (VDP_BASE+1) vctrl;
__sfr __at (VDP_BASE) vdata;
__sfr __at (VDP_BASE+2) vpal;
__sfr __at (VDP_BASE+3) vcmd;
__sfr __at (VDP_BASE+4) visacr;
volatile u16 ticks;
u8 back_page;
static u8 irq_live;
static u8 mesh_destination_page;
static u8 water_cached_valid,water_cached_frame;
static u8 water_bbox_x,water_bbox_y,water_bbox_h;
static u16 water_bbox_w;
void water_work_reset(void){water_cached_valid=0;}
#ifdef SCENE3_BENCHMARK
u8 benchmark_vdp, benchmark_mode;
#endif
#ifdef V9968_DEMO_DIAGNOSTIC
static u8 diag_index;
#endif

void orig_vdp_prepare(void){
#if VDP_BASE == 0x88
#asm
    di
    xor a
    out (099h),a
    ld a,080h
    out (099h),a
    xor a
    out (099h),a
    ld a,081h
    out (099h),a
#endasm
#endif
}

/* DI/EI protect the two-write control latch. Restore this module's IRQ
   policy (irq_live), not an unconditional EI or a portable C substitute. */
void reg(u8 r,u8 v){
#asm
    di
#endasm
    vctrl=v;vctrl=128|r;
    if(irq_live){
#asm
        ei
#endasm
    }
}
void clock_poll(void){}
/* C meaning: return ticks. Keep a single LD HL,(ticks): a C bytewise load
   could tear across the ISR increment. No portable C-only atomic equivalent. */
u16 clock_ticks(void) __naked {
#asm
    ld hl,(_ticks)
    ret
#endasm
}
/* Private IM2 vector table at D000-D100, trampoline D1D1-D1D3.
   Cartridge RAM map is checked in build/test; no BIOS ISR runs in graphics. */
/* Body in C notation: select_status(0); acknowledge_vblank();
   select_status(2); ++ticks; music_tick();
   Entry/exit must save both register sets plus IX/IY and use EI/RETI.
   A normal C function cannot replace this interrupt ABI. */
void frame_irq(void) __naked {
#asm
    GLOBAL _vctrl
    push af
    push bc
    push de
    push hl
    push ix
    push iy
    ex af,af'
    push af
    exx
    push bc
    push de
    push hl
    exx
    ld a,0
    out (_vctrl),a
    ld a,08fh
    out (_vctrl),a
    in a,(_vctrl)
    ld a,2
    out (_vctrl),a
    ld a,08fh
    out (_vctrl),a
    ld hl,(_ticks)
    inc hl
    ld (_ticks),hl
    call _music_tick
    exx
    pop hl
    pop de
    pop bc
    exx
    pop af
    ex af,af'
    pop iy
    pop ix
    pop hl
    pop de
    pop bc
    pop af
    ei
    reti
#endasm
}
void timer_start(void){
    u16 i;
    for(i=0;i<257;++i)*((u8*)0xd000+i)=0xd1;
    *((u8*)0xd1d1)=0xc3;*((u16*)0xd1d2)=(u16)frame_irq;
    reg(15,0);inp(VDP_BASE+1);reg(15,2);reg(1,96);
#asm
    ld a,0d0h
    ld i,a
    im 2
#endasm
    irq_live=1;
#asm
    ei
#endasm
}
static void command_fault(void){
    *((volatile u8*)0xcf06)=1;video_stop();reg(7,15);
    for(;;){inp(0xa9);}
}
/* Hot-loop wait: AF/BC clobbered, DE/HL preserved. Same bounded 65535-poll
   watchdog and fault marker as the C path; IRQ remains enabled throughout.
   ISR always restores S#2, never R#17 or the mapper. */
/* C reference: wait_cmd() below. Identical poll budget and fault action;
   elapsed timeout and instruction/IRQ timing deliberately differ. */
static void stream_wait(void) __naked {
#asm
    GLOBAL _vctrl
    ld bc,65535
mc_wait_busy:
    in a,(_vctrl)
    and 1
    ret z
    dec bc
    ld a,b
    or c
    jr nz,mc_wait_busy
    jp _command_fault
#endasm
}
static void wait_cmd(void){
    u16 budget=65535;
    while(inp(VDP_BASE+1)&1){
        if(--budget==0){
            command_fault();
        }
    }
}
static void word(u8 r,u16 v){reg(r,v);reg(r+1,v>>8);}
void rect(int x,int y,int w,int h,u8 c){
    if(x<0){w+=x;x=0;} if(y<0){h+=y;y=0;}
    if(x+w>256)w=256-x;if(y+h>192)h=192-y;
    if(w<=0||h<=0)return;
    wait_cmd();reg(17,36);
    vcmd=x;vcmd=0;vcmd=y;vcmd=back_page;
    vcmd=w;vcmd=w>>8;vcmd=h;vcmd=0;
    if(!((x|w)&1)){vcmd=c*17;vcmd=0;vcmd=0xc0;}
    else{vcmd=c;vcmd=0;vcmd=0x80;}
}
void line(int x,int y,int xx,int yy,u8 c){
    int dx,dy,t;u8 a=0;
    /* Geometry is bounded; reject out-of-window segments. */
    if(x<0||x>255||xx<0||xx>255||y<0||y>191||yy<0||yy>191)return;
    dx=abs(xx-x);dy=abs(yy-y);
    if(dy>dx){t=dx;dx=dy;dy=t;}
    /* Recompute from endpoints: preserves MAJ/DIY with pinned zsdcc optimizer.
       Diagnostic validates vertical lines in both directions. */
    a=(xx<x?4:0)+(yy<y?8:0)+(abs(yy-y)>abs(xx-x)?1:0);
#ifdef V9968_DEMO_DIAGNOSTIC
    {volatile u16 *p=(u16*)(0xcf20+diag_index*10);*p++=x;*p++=y;*p++=dx;*p++=dy;*p=a;++diag_index;}
#endif
    wait_cmd();reg(17,36);
    vcmd=x;vcmd=0;vcmd=y;vcmd=back_page;
    vcmd=dx;vcmd=0;vcmd=dy;vcmd=0;vcmd=c;vcmd=a;vcmd=0x70;
}
void palette(u8 phase){
    u8 i;
    (void)phase;
    reg(16,0);
    #ifdef SCENE3_BENCHMARK
    if(benchmark_mode!=0){
        for(i=0;i<48;i+=3){
            u8 r=(palette_rgb5[i]*7+15)/31;
            u8 g=(palette_rgb5[i+1]*7+15)/31;
            u8 b=(palette_rgb5[i+2]*7+15)/31;
            vpal=(r<<4)|b;vpal=g;
        }
        return;
    }
#endif
    for(i=0;i<48;++i)vpal=palette_rgb5[i];
}
/* Opening of Scene 6 only. No header is on screen there, so the whole palette
   is free and brightness can be defined as the population count of the colour
   index. Clearing any one bit then always steps a pixel exactly one level
   darker, whatever it started from. The solid is drawn at 15, so it fades
   15 -> 14 -> 12 -> 8 -> 0 (popcount 4,3,2,1,0): an even four-step greyscale
   afterglow, and no pixel can drop straight to the background the way an index
   with no low bits would. Greyscale keeps the opening monochrome; colour
   returns with the header. The next ordinary palette() call restores all
   sixteen entries, so nothing leaks into the second half. */
/* Indices 4, 5 and 10 carry the ordinary colours so the bottom HUD looks the
   same here as in every other scene. The decay clears one bit per frame in a
   fixed cyclic order, so from 15 it can only reach indices whose cleared bits
   are consecutive in that order: 14,13,11,7 then 12,9,3,6 then 8,1,2,4 then 0.
   5 and 10 are unreachable and are free for the bottom rule and the active
   indicator. Index 4 is reachable, but it sits at brightness level 1 and the
   ordinary colour there has almost the same luminance as the grey it replaces,
   so the ramp is unchanged to the eye. */
static const u8 glow_rgb5[48]={
     0, 0, 1,   6, 6, 7,   6, 6, 7,  13,13,14,
     4, 7,10,   6,10,13,  13,13,14,  21,21,22,
     6, 6, 7,  13,13,14,  23,17, 8,  21,21,22,
    13,13,14,  21,21,22,  21,21,22,  31,31,30};
void palette_glow(void){
    u8 i;
    reg(16,0);
    for(i=0;i<48;++i)vpal=glow_rgb5[i];
}
void flip(void){
    u16 t;
    wait_cmd();t=clock_ticks();while(t==clock_ticks())clock_poll();
    reg(2,31+32*back_page);back_page^=1;
}
static void vram_begin(u16 address){
#asm
    di
#endasm
    vctrl=address;vctrl=64|(address>>8);
    if(irq_live){
#asm
        ei
#endasm
    }
}
static u8 vram_peek(u16 address){
    u8 v;
#asm
    di
#endasm
    vctrl=address;vctrl=address>>8;
    v=vdata;
    if(irq_live){
#asm
        ei
#endasm
    }
    return v;
}
/* ---------------------------------------------------------------------------
   R20 bit 5 probe. Temporary: delete this block when the emulators agree with
   the FPGA about what the bit means.

   Bit 5 of R20 means different things on different V9968 builds. On the pinned
   openMSX fork it enables the extended commands, and without it LRMM does
   nothing at all, which would cost Scene 6 its feedback. On HRA's June FPGA
   map the same bit selects flat interlace, which we do not want, and LRMM
   works without it. One constant cannot serve both, so the bit is chosen by
   asking the hardware: write the byte without it, run one 1:1 LRMM between two
   small rectangles on page 0, and read the destination back. If the transfer
   happened, extended commands are already live and the bit stays clear; if it
   did not, the bit is what turns them on. Page 0 is cleared straight after
   this, so the two rectangles leave nothing behind. The selected byte is
   reported at 0xcf09 and the confirmation at 0xcf0a, for the emulator tests.

   To retire it, set V9968_R20_PROBE to 0: the probe compiles out and R20 is
   written once with the FPGA meaning, which is what an emulator that has been
   corrected would also want. Nothing outside this block changes; video_init()
   calls r20_select() either way and the same two bytes are reported. The
   capture test asserts the byte the pinned fork needs, so retiring the probe
   means changing that expectation with it; DEVELOPMENT.md keeps the whole
   description in one section.
   --------------------------------------------------------------------------- */
#define V9968_R20_PROBE 1
#if V9968_R20_PROBE
static u8 lrmm_moved(void){
    u16 spin;
    rect(0,0,8,2,15);
    rect(16,0,8,2,0);
    wait_cmd();
    word(32,0);word(34,0);              /* source start */
    word(36,16);word(38,0);             /* destination, page 0 */
    word(40,8);word(42,2);              /* 8x2 pixels */
    word(47,256);word(49,0);            /* 8.8 steps: 1:1, no rotation */
    word(51,0);word(53,0);word(55,255);word(57,191);
    reg(44,0);reg(45,0);reg(46,0x38);
    /* CE does not rise the instant the command byte lands. The fork completes
       the transfer immediately, so polling straight away happens to work
       there, but on real hardware LRMM takes time: a status read that beats CE
       going high returns at once, the destination is read before the transfer
       arrives, and the probe would conclude nothing moved. Spin for CE to
       appear first. How long that takes on a real V9968 is not known here, so
       the count is a bound rather than a guarantee: if CE is never seen the
       loop simply falls through, and the result is confirmed afterwards
       instead of being assumed correct. */
    for(spin=0;spin<1024;++spin)if(inp(VDP_BASE+1)&1)break;
    wait_cmd();
    reg(14,0);
    return vram_peek(8)==0xff;
}
static void r20_select(void){
    u8 moved;
    reg(20,0x11);
    moved=lrmm_moved();
    if(!moved)reg(20,0x31);
    /* Running the probe again after the switch turns a silent wrong answer
       into a visible one: whichever byte was chosen, LRMM has to work under
       it. Reported at 0xcf0a for the emulator tests. */
    *((volatile u8*)0xcf0a)=moved?1:lrmm_moved();
    *((volatile u8*)0xcf09)=moved?0x11:0x31;
}
#else
static void r20_select(void){
    reg(20,0x11);
    *((volatile u8*)0xcf09)=0x11;
    *((volatile u8*)0xcf0a)=1;
}
#endif
/* --------------------------------------------------- end of the R20 probe -- */
u8 video_init(void){
    u8 id,y;u16 i;const u8 *p;
    orig_vdp_prepare();
    visacr=0;
    reg(21,0x3a);reg(15,1);id=(inp(VDP_BASE+1)>>1)&31;
    #ifdef SCENE3_BENCHMARK
    if(id>3){reg(15,0);return 0;}
    benchmark_vdp=id;benchmark_mode=(id==3)?0:2;
#else
    if(id!=3){reg(15,0);reg(21,0x3b);return 0;}
#endif
    reg(0,6);reg(1,0);reg(2,31);reg(7,0);reg(8,10);
    reg(9,0);
#ifdef SCENE3_BENCHMARK
    if(id==3)reg(20,17); /* HS + EPAL only; no extended commands. */
#endif
    reg(23,0);
#ifdef SCENE3_BENCHMARK
    if(id!=0){reg(25,0);reg(26,0);reg(27,0);}
#else
    reg(25,0);reg(26,0);reg(27,0);
#endif
    reg(15,2);back_page=0;
#ifndef SCENE3_BENCHMARK
    /* Needs R15 for wait_cmd() and a destination page, so it runs here rather
       than beside the other register writes. */
    r20_select();
#endif
    palette(0);rect(0,0,256,192,0);
    wait_cmd();back_page=1;rect(0,0,256,192,0);wait_cmd();
    textures_load();
    background_load(BANK_BACKGROUND);
    /* Seven nine-row header strips, shadow and text already composited, in the
       VRAM above the background. 63 rows of the 64 that are free. */
    bank_select(BANK_HUDLINE);p=(const u8*)0x8000;reg(14,7);
    for(y=0;y<63;++y){
        vram_begin(0x2000+y*128);
        for(i=0;i<93;++i)vdata=*p++;
    }
    reg(1,64);
    return 1;
}
void orb_draw(int x,int y){
    wait_cmd();word(32,0);word(34,512);word(36,x);word(38,y+back_page*256);
    word(40,ORB_SIZE);word(42,ORB_SIZE);reg(45,0);reg(46,0x98);
}
void video_stop(void){
#asm
    di
#endasm
    irq_live=0;reg(1,0);reg(8,10);silence();
}
void background(void){
    wait_cmd();reg(17,32);
    vcmd=0;vcmd=0;vcmd=0;vcmd=3;
    vcmd=0;vcmd=0;vcmd=0;vcmd=back_page;
    vcmd=0;vcmd=1;vcmd=192;vcmd=0;vcmd=0;vcmd=0;vcmd=0xd0;
}

/* LRMM applies the precomputed inverse rotation/zoom to a large detailed panel. */
void panel_draw(const int *p){
    wait_cmd();word(32,p[0]);word(34,p[1]);
    word(36,16);word(38,24+back_page*256);word(40,224);word(42,144);
    word(47,p[2]);word(49,p[3]);word(51,0);word(53,608);word(55,255);word(57,735);
    reg(44,0);reg(45,0);reg(46,0x38);
}

/* Reload page-2 textures after it has served as the water capture buffer. */
void textures_load(void){
    u16 i;u8 y;const u8 *p;
    water_work_reset();
    wait_cmd();bank_select(BANK_ORB);p=(const u8*)0x8000;
    reg(14,4);
    for(y=0;y<80;++y){
        vram_begin(y*128);
        for(i=0;i<40;++i)vdata=*p++;
    }
    bank_select(BANK_PANEL);p=(const u8*)0x8000;
    reg(14,4);vram_begin(0x3000);
    for(i=0;i<16384;++i)vdata=*p++;
}
/* Precomputed LMMV packets. Only the destination-page byte is substituted.
   Called after timer_start; the ISR does not modify R17 or switch ROM banks. */
/* C reference for mc_span_next: count is little-endian; each record has
   11 bytes for R36..R46. Replace only DY high (byte 3). Zero count is a no-op.
   This is compiled and tested, not disabled sample code. */
#ifdef V9968_SCENE3_C_STREAM
static void stream_mesh_page(const u8 *packets) __z88dk_fastcall {
    u16 count=(u16)packets[0]|((u16)packets[1]<<8);
    u8 i;
    packets+=2;
    while(count--){
        wait_cmd();reg(17,36);
        for(i=0;i<11;++i)vcmd=(i==3)?mesh_destination_page:packets[i];
        packets+=11;
    }
}
#else
static void stream_mesh_page(const u8 *packets) __z88dk_fastcall __naked {
#asm
    GLOBAL _vctrl
    GLOBAL _vcmd
    ld e,(hl)
    inc hl
    ld d,(hl)
    inc hl
mc_span_next:
    ld a,d
    or e
    ret z
#endasm
#asm
    call _stream_wait
#endasm
#asm
    di
    ld a,36
    out (_vctrl),a
    ld a,091h
    out (_vctrl),a
    ei
    ld b,3
    ld c,_vcmd
    otir
    ld a,(_mesh_destination_page)
    out (_vcmd),a
    inc hl
    ld b,7
    otir
    dec de
    jr mc_span_next
#endasm
}
#endif
void stream_spans(const u8 *packets){
    mesh_destination_page=back_page;stream_mesh_page(packets);
}
/* Page 2 is clean background plus one cached mesh, never HUD or distortion.
   HMMM works in packed bytes: expand the exact bbox to even X boundaries. */
static void water_restore(u8 x,u8 y,u16 w,u8 h){
    wait_cmd();reg(17,32);
    vcmd=x;vcmd=0;vcmd=y;vcmd=3;
    vcmd=x;vcmd=0;vcmd=y;vcmd=2;
    vcmd=w;vcmd=w>>8;vcmd=h;vcmd=0;vcmd=0;vcmd=0;vcmd=0xd0;
}
void water_prepare(u8 frame){
    const u8 *p,*bbox;
    /* zsdcc drops an in-place mask on the argument at -SO3; assign the masked result to a separate variable.
       volatile is not the workaround; retained to preserve the measured ROM. */
    volatile u8 pose=frame&(FRAMES_MESH-1);
    if(water_cached_valid && pose==water_cached_frame)return;
    if(water_cached_valid)water_restore(water_bbox_x,water_bbox_y,water_bbox_w,water_bbox_h);
    else water_restore(0,0,256,192);
    p=bank_record(BANK_MESH,pose,4096);bbox=p+MESH_BBOX_OFFSET;
    water_bbox_x=bbox[0]&254;water_bbox_y=bbox[1];water_bbox_h=bbox[3];
    water_bbox_w=(((u16)bbox[0]+bbox[2]+1)&0xfffe)-water_bbox_x;
    mesh_destination_page=2;stream_mesh_page(p);
    water_cached_frame=pose;water_cached_valid=1;
}
/* Same packet walk as stream_spans, but the colour byte in each packet is
   replaced by 15 instead of being sent through. That flattens the shaded solid
   to one level for the Scene 6 opening without a second copy of the half-
   megabyte span data, and leaves Scene 1 reading the same packets unchanged. */
/* C reference for mc_glow_next: same 11-byte walk; substitute destination
   page at byte 3 and colour 15 at byte 8. Width/height and command are retained. */
#ifdef V9968_SCENE3_C_STREAM
void stream_spans_glow(const u8 *packets) __z88dk_fastcall {
    u16 count=(u16)packets[0]|((u16)packets[1]<<8);
    u8 i,value;
    packets+=2;
    while(count--){
        wait_cmd();reg(17,36);
        for(i=0;i<11;++i){
            value=packets[i];
            if(i==3)value=back_page;
            if(i==8)value=15;
            vcmd=value;
        }
        packets+=11;
    }
}
#else
void stream_spans_glow(const u8 *packets) __z88dk_fastcall __naked {
#asm
    GLOBAL _vctrl
    GLOBAL _vcmd
    ld e,(hl)
    inc hl
    ld d,(hl)
    inc hl
mc_glow_next:
    ld a,d
    or e
    ret z
    push de
    push hl
    call _wait_cmd
    pop hl
    pop de
    di
    ld a,36
    out (_vctrl),a
    ld a,091h
    out (_vctrl),a
    ei
    ld b,3
    ld c,_vcmd
    otir
    ld a,(_back_page)
    out (_vcmd),a
    inc hl
    ld b,4
    ld c,_vcmd
    otir
    ld a,15
    out (_vcmd),a
    inc hl
    ld b,2
    ld c,_vcmd
    otir
    dec de
    jr mc_glow_next
#endasm
}
#endif
void floor_draw(const int *p){
    u8 y;
    for(y=64;y<176;y+=2){
        wait_cmd();word(32,p[0]);word(34,p[1]);word(36,16);word(38,y+back_page*256);
        word(40,224);word(42,2);word(47,p[2]);word(49,p[3]);
        word(51,0);word(53,608);word(55,255);word(57,735);
        reg(44,0);reg(45,0);reg(46,0x38);p+=4;
    }
}
/* Scene 6 keeps its accumulation image on page 2, the same page that otherwise
   holds textures and the water capture. A single LMMV with the AND operation
   clears one bit of every colour index on the whole screen, which is the whole
   fade: with this palette the grey mesh ramp (8-13) drops into the darker blue
   ramp (0-5) and from there to black. Cycling four masks clears the four bits
   in turn, so a freshly drawn pixel reaches black in at most four frames. */
void trail_clear(void){
    wait_cmd();reg(17,36);
    vcmd=0;vcmd=0;vcmd=0;vcmd=2;
    vcmd=0;vcmd=1;vcmd=192;vcmd=0;
    vcmd=0;vcmd=0;vcmd=0xc0;
}
void trail_decay(u8 mask,u8 page){
    wait_cmd();reg(17,36);
    vcmd=0;vcmd=0;vcmd=0;vcmd=page;
    vcmd=0;vcmd=1;vcmd=192;vcmd=0;
    vcmd=mask;vcmd=0;vcmd=0x81;
}
/* Scene 6 second half, recursive feedback. The history frame lives on page 2,
   the same
   borrowed page Scene 3 and Scene 6 use, so no extra VRAM is needed and the
   scenes never run at the same time. Source and destination are always
   different pages, so no overlap handling or work buffer is required.
   Decay is geometric: whatever the transform does not cover stays at the
   colour-0 clear, so the history erodes from the edges instead of being
   faded arithmetically, which the VDP cannot do. */
void feedback_shift(int dx,int dy){
    u16 nx,ny;u8 sx,ddx,sy,ddy;
    if(dx>=0){sx=0;ddx=dx;nx=256-dx;}else{sx=-dx;ddx=0;nx=256+dx;}
    if(dy>=0){sy=0;ddy=dy;ny=192-dy;}else{sy=-dy;ddy=0;ny=192+dy;}
    wait_cmd();reg(17,32);
    vcmd=sx;vcmd=0;vcmd=sy;vcmd=2;
    vcmd=ddx;vcmd=0;vcmd=ddy;vcmd=back_page;
    vcmd=nx;vcmd=nx>>8;vcmd=ny;vcmd=0;vcmd=0;vcmd=0;vcmd=0xd0;
}
/* LRMM maps the destination through the inverse transform, so vx/vy are the
   source step per destination pixel in 8.8 fixed point: 256 is 1:1 and a
   smaller value magnifies. The source start places the centre of the screen
   on the centre of the history, using the same half-width/half-height form as
   panel_draw. Page 2 occupies Y 512..703 in the shared coordinate space. */
void feedback_warp(int vx,int vy){
    wait_cmd();
    word(32,128-(((int)128*vx-(int)96*vy)>>8));
    word(34,608-(((int)128*vy+(int)96*vx)>>8));
    word(36,0);word(38,back_page*256);word(40,256);word(42,192);
    word(47,vx);word(49,vy);
    word(51,0);word(53,512);word(55,255);word(57,703);
    reg(44,0);reg(45,0);reg(46,0x38);
}
void feedback_capture(void){
    wait_cmd();reg(17,32);
    vcmd=0;vcmd=0;vcmd=0;vcmd=back_page;
    vcmd=0;vcmd=0;vcmd=0;vcmd=2;
    vcmd=0;vcmd=1;vcmd=192;vcmd=0;vcmd=0;vcmd=0;vcmd=0xd0;
}
/* Page 3 is never displayed; only replace it at scene boundaries. */
void background_load(u8 bank){
    u16 i;const u8 *p;
    water_work_reset();
    wait_cmd();reg(14,6);vram_begin(0);
    bank_select(bank);p=(const u8*)0x8000;
    for(i=0;i<16384;++i)vdata=*p++;
    bank_select(bank+1);p=(const u8*)0x8000;
    for(i=0;i<8192;++i)vdata=*p++;
    wait_cmd();
}
/* One opaque blit after all scene effects keeps the scene number stable. */
/* The header, drawn straight onto the picture in one transparent blit. The
   strip already holds the drop shadow behind the text, and the VDP skips
   source colour 0, so the glyphs and their shadow land on whatever is there
   and nothing else is touched. No scene has to restore a strip of the
   background image behind its header, and the title is not baked into the
   background images any more. */
void header_shadow(u8 scene){
    u16 sy=960+(u16)scene*9;
    wait_cmd();reg(17,32);
    vcmd=0;vcmd=0;
    vcmd=(u8)sy;vcmd=(u8)(sy>>8);
    vcmd=8;vcmd=0;
    vcmd=5;vcmd=back_page;
    vcmd=186;vcmd=0;
    vcmd=9;vcmd=0;
    vcmd=0;vcmd=0;vcmd=0x98;
}
/* Source page 2 is immutable during all bands: no cumulative feedback. */
#ifdef V9968_SCENE3_C_STREAM
void water_draw(const u8 *p){
    u8 y=0,sx,dx,w,sy,i,edge,h,count=*p++;
    /* Every destination pixel is overwritten, including both repeated edges. */
    while(count--){
        sx=*p++;dx=*p++;w=*p++;sy=*p++;h=*p++;
        wait_cmd();reg(17,32);
        vcmd=sx;vcmd=0;vcmd=sy;vcmd=2;
        vcmd=dx;vcmd=0;vcmd=y;vcmd=back_page;
        vcmd=w;vcmd=(w==0);vcmd=h;vcmd=0;vcmd=0;vcmd=0;vcmd=0xd0;
        if(sx || dx){
            /* Repeat the outermost pixel, not the outermost two-pixel pair. */
            edge=dx?0:255;
            for(i=0;i<2;++i){
                wait_cmd();reg(17,32);
                vcmd=edge;vcmd=0;vcmd=sy;vcmd=2;
                vcmd=dx?i:254+i;vcmd=0;vcmd=y;vcmd=back_page;
                vcmd=1;vcmd=0;vcmd=h;vcmd=0;vcmd=0;vcmd=0;vcmd=0x90;
            }
        }
        y+=h;
    }
}

#else
/* Compact record: count, then sx/dx/width/sy/height per run. Width zero
   encodes 256. The buffer is private to the main loop; IRQ never touches it.
   Source page 2 remains immutable. All command registers are written only
   after CE clears, and R#17 selection is atomic. */
/* Label mapping to the C water_draw above:
   mc_water_next/width = decode one run; mc_water_right/edge = repeat the
   outermost pixel twice; mc_water_advance = y += h; mc_water_submit =
   wait_cmd(); reg(17,32); output the 15 R32..R46 bytes. */
static u8 water_packet[15]={0,0,0,2,0,0,0,0,0,0,0,0,0,0,0xd0};
static void stream_water_runs(const u8 *p) __z88dk_fastcall __naked {
#asm
    GLOBAL _vctrl
    GLOBAL _vcmd
    ld a,(_back_page)
    ld (_water_packet+7),a
    ld d,(hl)
    inc hl
    ld e,0
mc_water_next:
    ld a,d
    or a
    ret z
    ld a,(hl)
    ld (_water_packet),a
    inc hl
    ld a,(hl)
    ld (_water_packet+4),a
    inc hl
    ld a,(hl)
    ld (_water_packet+8),a
    inc hl
    or a
    ld a,0
    jr nz,mc_water_width
    inc a
mc_water_width:
    ld (_water_packet+9),a
    ld a,(hl)
    ld (_water_packet+2),a
    inc hl
    ld a,(hl)
    ld (_water_packet+10),a
    inc hl
    ld a,e
    ld (_water_packet+6),a
    ld a,0d0h
    ld (_water_packet+14),a
    call mc_water_submit
    ld a,(_water_packet)
    ld b,a
    ld a,(_water_packet+4)
    or b
    jr z,mc_water_advance
    ld a,(_water_packet+4)
    or a
    jr z,mc_water_right
    xor a
    ld (_water_packet),a
    ld (_water_packet+4),a
    jr mc_water_edge
mc_water_right:
    ld a,255
    ld (_water_packet),a
    dec a
    ld (_water_packet+4),a
mc_water_edge:
    ld a,1
    ld (_water_packet+8),a
    xor a
    ld (_water_packet+9),a
    ld a,090h
    ld (_water_packet+14),a
    call mc_water_submit
    ld a,(_water_packet+4)
    inc a
    ld (_water_packet+4),a
    call mc_water_submit
mc_water_advance:
    ld a,(_water_packet+10)
    add a,e
    ld e,a
    dec d
    jp mc_water_next
mc_water_submit:
    call _stream_wait
    di
    ld a,32
    out (_vctrl),a
    ld a,091h
    out (_vctrl),a
    ei
    push hl
    ld hl,_water_packet
    ld b,0fh
    ld c,_vcmd
    otir
    pop hl
    ret
#endasm
}
void water_draw(const u8 *p){stream_water_runs(p);}
#endif

#ifdef SCENE3_BENCHMARK
/* Toggle only at an idle command engine, blanking during palette replacement.
   Keep VBlank IRQ and PSG running. R20 bits follow pinned d884c4b. */
void benchmark_set_mode(u8 mode){
    u16 t;
    wait_cmd();t=clock_ticks();while(t==clock_ticks()){}
    reg(1,32);
    benchmark_mode=(benchmark_vdp==3)?mode:2;
    if(benchmark_vdp==3)reg(20,mode==0?17:(mode==1?1:0));
    palette(0);reg(1,96);
}
/* Packed 96-glyph MSX 8x8 atlas in page 3, below the 192-line background. */
void benchmark_font(void){
    u16 i;
    const u8 *p;
    wait_cmd();bank_select(BANK_LABELS);p=(const u8*)0x8000;
    reg(14,7);vram_begin(0x2000);
    for(i=0;i<3072;++i)vdata=*p++;
}
void benchmark_text(u8 x,u8 y,const char *s){
    u8 c;
    while(*s && x<249){
        c=*s++-32;
        wait_cmd();reg(17,32);
        vcmd=(c&31)*8;vcmd=0;vcmd=192+(c>>5)*8;vcmd=3;
        vcmd=x;vcmd=0;vcmd=y;vcmd=back_page;
        vcmd=8;vcmd=0;vcmd=8;vcmd=0;vcmd=0;vcmd=0;vcmd=0xd0;
        x+=8;
    }
}
#endif

/* Scene 7: a clean floor and independently animated indexed light mask.
   Floor in page 3; one projected 256x160 mask in page 2, updated from a 128-phase
   ROM animation using changed-byte runs. LMMM OR selects one of four indexed light levels, not alpha.
   Sprite mode3 separately alpha-composites surface glare with the background.
   Phase selection is C; upload/delta streaming have matching C and OTIR paths. */
static const u8 shallow_rgb5[48]={
  0,3,4, 1,5,6, 3,8,9, 5,11,12, 3,8,8, 5,11,11, 8,15,14, 11,19,17,
  8,16,13, 12,21,17, 17,26,21, 23,29,25, 17,25,21, 22,29,25, 28,31,28, 31,31,30
};
static u8 shallow_surface_phase;
/* R14 and VRAM write address are established by shallow_palette(). Both paths
   send exactly 504 bytes: 62 Sprite mode3 entries and one end marker. The
   record stays inside its 512-byte slot and the mapped 16 KiB ROM window. */
#ifdef V9968_SCENE3_C_STREAM
static void shallow_surface_upload(const u8 *p) __z88dk_fastcall {
    u16 i;for(i=0;i<504;++i)vdata=*p++;
}
#else
static void shallow_surface_upload(const u8 *p) __z88dk_fastcall __naked {
#asm
    ld c,_vdata
    ld b,0
    otir
    ld b,248
    otir
    ret
#endasm
}
#endif

void shallow_palette(void){
    u16 i;const u8 *p;
    reg(16,0);for(i=0;i<48;++i)vpal=shallow_rgb5[i];
    /* After the page flip: update the small SAT in vertical blank. Palette
       set 1 is independent of the 16 background colours and stays resident. */
    p=bank_record(BANK_SURFACE_ATTRS,shallow_surface_phase,512);
    reg(14,5);vram_begin(0x3e00);shallow_surface_upload(p);
    reg(20,*((volatile u8*)0xcf09)|8);reg(8,8);
}
void shallow_leave(void){reg(8,10);reg(20,*((volatile u8*)0xcf09));}
/* Matching C and Z80 paths: write the same packed bytes at the same VRAM
   addresses. R14=4 and command-idle are established by the caller. */
#ifdef V9968_SCENE3_C_STREAM
static void shallow_upload(const u8 *p) __z88dk_fastcall {
    u16 i;for(i=0;i<16384;++i)vdata=*p++;
}
static void shallow_delta(const u8 *p) __z88dk_fastcall {
    u16 count,address;u8 length;
    count=*p++;count|=(u16)*p++<<8;
    while(count--){
        address=*p++;address|=(u16)*p++<<8;length=*p++;
        vram_begin(address);while(length--)vdata=*p++;
    }
}
#else
static void shallow_upload(const u8 *p) __z88dk_fastcall __naked {
#asm
    ld d,64
    ld c,_vdata
shallow_upload_loop:
    ld b,0
    otir
    dec d
    jr nz,shallow_upload_loop
    ret
#endasm
}
static void shallow_delta(const u8 *p) __z88dk_fastcall __naked {
#asm
    ld e,(hl)
    inc hl
    ld d,(hl)
    inc hl
shallow_delta_loop:
    ld a,d
    or e
    ret z
    di
    ld a,(hl)
    inc hl
    out (_vctrl),a
    ld a,(hl)
    inc hl
    or 040h
    out (_vctrl),a
    ld b,(hl)
    inc hl
    ld a,(_irq_live)
    or a
    jr z,shallow_delta_irq_off
    ei
shallow_delta_irq_off:
    ld c,_vdata
    otir
    dec de
    jr shallow_delta_loop
#endasm
}
#endif
/* Final 32 rows occupy the next 4 KiB VRAM segment. Same bytes in both paths. */
#ifdef V9968_SCENE3_C_STREAM
static void shallow_tail_upload(const u8 *p) __z88dk_fastcall {
    u16 i;for(i=0;i<4096;++i)vdata=*p++;
}
#else
static void shallow_tail_upload(const u8 *p) __z88dk_fastcall __naked {
#asm
    ld d,16
    ld c,_vdata
shallow_tail_loop:
    ld b,0
    otir
    dec d
    jr nz,shallow_tail_loop
    ret
#endasm
}
#endif
static u8 shallow_mask;
static void shallow_step(u8 frame,u8 distance){
    const u8 *p;u16 tail;
    wait_cmd();
    if(distance==1){
        p=bank_record(BANK_CAUSTIC_DELTA,frame,16384);
        reg(14,4);shallow_delta(p);reg(14,5);shallow_delta(p+8192);
    }else{
        p=bank_record(distance==2?BANK_CAUSTIC_JUMP2:BANK_CAUSTIC_JUMP3,frame,16384);
        tail=(u16)p[0]|((u16)p[1]<<8);
        reg(14,4);shallow_delta(p+2);reg(14,5);shallow_delta(p+tail);
    }
    shallow_mask=frame;
}
static void shallow_full(u8 frame){
    u8 step;u16 bank=(u16)BANK_CAUSTICS+(u16)(frame>>3)*2;
    /* Key masks every eight phases save ROM; direct 1/2/3-step differences
       reconstruct the exact target, at most three steps after a time jump. */
    wait_cmd();bank_select(bank);reg(14,4);vram_begin(0);
    shallow_upload((const u8*)0x8000);
    bank_select(bank+1);reg(14,5);vram_begin(0);
    shallow_tail_upload((const u8*)0x8000);
    shallow_mask=frame&120;
    while(shallow_mask!=frame){
        step=frame-shallow_mask;if(step>3)step=3;
        shallow_step(shallow_mask+step,step);
    }
}
static void shallow_update(u8 frame){
    u8 step,distance=(frame-shallow_mask)&127;
    if(!distance)return;
    /* Update a skipped shape directly instead of replaying every phase.
       Large jumps reconstruct from a nearby key mask with bounded work. */
    if(distance>9){shallow_full(frame);return;}
    while(distance){
        step=distance>3?3:distance;
        shallow_step((shallow_mask+step)&127,step);distance-=step;
    }
}
void shallow_enter(void){
    u16 i;u8 c;const u8 *p;
    reg(8,10);background_load(BANK_SHALLOW);shallow_full(0);
    /* 0x15000..0x15fff: patterns; 0x17e00..0x17fff: 64-entry SAT.
       Neither overlaps the 20 KiB light cache, background, or header. */
    bank_select(BANK_SURFACE_PATTERN);p=(const u8*)0x8000;
    reg(14,5);vram_begin(0x1000);for(i=0;i<4096;++i)vdata=*p++;
    /* Enable SP3 before refreshing table registers. The pinned emulator's
       SP3-only transition does not refresh its cached table masks. Force
       harmless value transitions while sprites remain disabled; also correct
       on re-entry when the register values are unchanged. */
    reg(20,*((volatile u8*)0xcf09)|8);
    reg(5,248);reg(5,252);reg(11,2);reg(6,1);reg(6,0);
    reg(16,16);
    /* Dark, water-tinted shoulders and a white peak. Index zero is transparent.
       Python generates wave-normal-driven width, opacity and glint positions;
       runtime only selects/upload attributes (no trigonometry or lighting). */
    for(i=0;i<16;++i){
        c=(28*i*i)/225;vpal=3+c;
        c=(23*i*i)/225;vpal=8+c;
        c=(22*i*i)/225;vpal=9+c;
    }
    shallow_surface_phase=0;
}
void shallow_draw(u16 now){
    u8 y,sx,sy,h,count,m=(now>>2)&127;
    const u8 *p;
    *((volatile u16*)0xcf10)=now;
    shallow_surface_phase=(now>>2)&127;
    shallow_update(m);
    /* Refract the clean page-3 floor directly into the display back page.
       Page 2 is now a mask cache. Indexed light is composed afterwards. */
    background();
    p=bank_record(BANK_SHALLOW_WAVE,(now>>1)&127,256);
    count=*p++;
    while(count--){
        sx=*p++;sy=*p++;y=*p++;h=*p++;
        wait_cmd();reg(17,32);
        vcmd=sx;vcmd=0;vcmd=sy;vcmd=3;
        vcmd=8;vcmd=0;vcmd=y;vcmd=back_page;
        vcmd=240;vcmd=0;vcmd=h;vcmd=0;vcmd=0;vcmd=0;vcmd=0xd0;
    }
    /* One full projected surface, no screen-space tile repetition. */
    wait_cmd();reg(17,32);
    vcmd=8;vcmd=0;vcmd=0;vcmd=2;
    vcmd=8;vcmd=0;vcmd=20;vcmd=back_page;
    vcmd=240;vcmd=0;vcmd=160;vcmd=0;
    vcmd=0;vcmd=0;vcmd=0x92;
}
