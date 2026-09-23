/* Yamaha V9990 B1/BP4, 256x212 output, 256x192 comparison image.
 * Logical VRAM rows: 0/256 display, 512 clean work, 768 background,
 * 960..1013 header strips. 20 unused display rows retain palette index 0 (dark blue).
 * Commands use pixel coordinates; 0 in a water record means width 256.
 */
#include <stdlib.h>
#include "v9968.h"
#include "v9990.h"
#include "mapper.h"
#include "bank-layout.h"
__sfr __at(0x60) data;
__sfr __at(0x61) pal;
__sfr __at(0x63) rd;
__sfr __at(0x64) rs;
__sfr __at(0x65) status;
__sfr __at(0x66) flags;
__sfr __at(0x67) control;
volatile u16 ticks;
u8 back_page;
static u8 valid,cached,bx,by,bh;
static u16 bw;
static const u8 colors[48]={0,0,1,1,2,3,2,3,5,3,5,7,4,7,10,6,10,13,9,13,16,13,18,21,5,6,7,9,10,11,14,15,16,20,21,22,25,27,28,31,31,30,9,27,31,23,17,8};
static void wr(u8 r,u8 v){rs=r;rd=v;}
static void word(u8 r,u16 v){rs=r;rd=v;rd=v>>8;}
static void video_fault(u8 reason){
    /* Stop interrupts before muting: music_tick must not restart the PSG. */
#asm
 di
#endasm
    *((volatile u8*)0xcf06)=reason;wr(9,0);silence();for(;;){}
}
void video_wait(void){
    u16 budget=65535;
    while(status&1){if(!--budget){video_fault(1);}}
}
u16 clock_ticks(void) __naked {
/* Atomic C meaning: return ticks. */
#asm
 ld hl,(_ticks)
 ret
#endasm
}
static void irq(void) __naked {
/* Save both register sets/IX/IY, acknowledge V9990 VBlank, ++ticks,
 * music_tick(), restore registers, EI/RETI. ISR never touches rs/rd. */
#asm
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
 ld a,1
 out (066h),a
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
    *((u8*)0xd1d1)=0xc3;*((u16*)0xd1d2)=(u16)irq;
    flags=7;wr(9,1);
#asm
 ld a,0d0h
 ld i,a
 im 2
 ei
#endasm
}
/* Fully specified A command: no dependencies on previous command registers. */
static void copy(u16 sx,u16 sy,u16 dx,u16 dy,u16 w,u16 h,u8 transparent){
#ifdef V9990_OPTIMIZED
    /* R32..43 auto-increment. ARG/WM are invariant after initialization.
     * Explicit LOG on every copy preserves opaque/transparent transitions. */
    video_wait();rs=32;
    rd=sx;rd=sx>>8;rd=sy;rd=sy>>8;rd=dx;rd=dx>>8;rd=dy;rd=dy>>8;
    rd=w;rd=w>>8;rd=h;rd=h>>8;
    wr(45,transparent?0x1c:0x0c);wr(52,0x40);
#else
    video_wait();word(32,sx);word(34,sy);word(36,dx);word(38,dy);
    word(40,w);word(42,h);wr(44,0);wr(45,transparent?0x1c:0x0c);
    word(46,65535);wr(52,0x40);
#endif
}
static void fill(u16 x,u16 y,u16 w,u16 h,u8 c){
#ifdef V9990_OPTIMIZED
    video_wait();rs=36;
    rd=x;rd=x>>8;rd=y;rd=y>>8;rd=w;rd=w>>8;rd=h;rd=h>>8;
    wr(45,0x0c);rs=48;c=c*17;rd=c;rd=c;wr(52,0x20);
#else
    video_wait();word(36,x);word(38,y);word(40,w);word(42,h);
    wr(44,0);wr(45,0x0c);word(46,65535);word(48,(u16)(c*17)*257);wr(52,0x20);
#endif
}
void flip(void){
    u16 t,budget=65535;
    video_wait();t=clock_ticks();while(t==clock_ticks()){if(!--budget)video_fault(3);}
    wr(17,0);wr(18,back_page);back_page^=1;
}
static void address(u8 hi,u16 lo){wr(0,lo);wr(1,lo>>8);wr(2,hi);}
u8 video_init(void){
    u8 i,y;u16 j;const u8 *p;
#asm
 di
#endasm
    /* P#7 bit1 is SRS (reset), bit0 is MCS. */
    control=2;control=0;
    for(i=0;i<29;++i)wr(i,0);
    wr(6,0x81);wr(7,0);wr(8,0x02); /* B1, BP4, cursor disabled */
    rs=15|0x80;rd=0x15;if((rd&63)!=0x15)return 0;wr(15,0);
    /* Only disable the original VDP after detecting the external device.
     * Missing hardware must leave BIOS text/IRQ state intact. */
    outp(0x99,0);outp(0x99,0x81);
    wr(14,0);for(i=0;i<48;++i)pal=colors[i];
    wr(44,0);word(46,65535);
    fill(0,0,256,1024,0);video_wait();
    bank_select(BANK_HUDLINE);p=(const u8*)0x8000;
    for(y=0;y<54;++y){address(1,0xe000+(u16)y*128);for(j=0;j<93;++j)data=*p++;}
    back_page=0;valid=0;wr(8,0x82);return 1;
}
void background_load(u8 bank){
    u16 i;const u8 *p;video_wait();address(1,0x8000);
    bank_select(bank);p=(const u8*)0x8000;for(i=0;i<16384;++i)data=*p++;
    bank_select(bank+1);p=(const u8*)0x8000;for(i=0;i<8192;++i)data=*p++;
    valid=0;
}

#ifdef V9990_PACKETS
/* Version C packets: no per-command coordinate decoding in the hot loop.
 * C and assembly streams consume identical records and preserve CE checks.
 * Each port is decoded by its low byte; OTIR's changing B is harmless.
 * The ISR preserves registers, does not touch command ports or mapper.
 */
#ifdef V9990_C_STREAM_REFERENCE
static void stream_fill(const u8 *p) __z88dk_fastcall {
    u16 n=p[0]|((u16)p[1]<<8);u8 i;p+=2;wr(45,0x0c);
    while(n--){video_wait();rs=36;for(i=0;i<8;++i)rd=*p++;
        rs=48;rd=*p++;rd=*p++;wr(52,0x20);}
}
static void stream_copy(const u8 *p) __z88dk_fastcall {
    u16 n=p[0]|((u16)p[1]<<8);u8 i;p+=2;wr(45,0x0c);
    while(n--){video_wait();rs=32;for(i=0;i<12;++i){rd=(i==7)?back_page:*p;++p;}wr(52,0x40);}
}
#else
static void stream_timeout(void){video_fault(1);}
/* C equivalent: video_wait(). Preserves HL/DE, clobbers AF/BC only.
 * Same 65535-poll bound; fault path never returns. */
static void stream_wait_c(void) __naked {
#asm
 ld bc,65535
sc_wait:
 in a,(065h)
 and 1
 ret z
 dec bc
 ld a,b
 or c
 jr nz,sc_wait
 jp _stream_timeout
#endasm
}
/* Count in DE, next record in HL. Exactly the C reference above. */
static void stream_fill(const u8 *p) __z88dk_fastcall __naked {
#asm
 ld e,(hl)
 inc hl
 ld d,(hl)
 inc hl
 ld a,45
 out (064h),a
 ld a,00ch
 out (063h),a
sc_fill_next:
 ld a,d
 or e
 ret z
 call _stream_wait_c
 ld a,36
 out (064h),a
 ld bc,00863h
 otir
 ld a,48
 out (064h),a
 ld b,2
 otir
 ld a,52
 out (064h),a
 ld a,020h
 out (063h),a
 dec de
 jr sc_fill_next
#endasm
}
static void stream_copy(const u8 *p) __z88dk_fastcall __naked {
#asm
 ld e,(hl)
 inc hl
 ld d,(hl)
 inc hl
 ld a,45
 out (064h),a
 ld a,00ch
 out (063h),a
sc_copy_next:
 ld a,d
 or e
 ret z
 call _stream_wait_c
 ld a,32
 out (064h),a
 ld bc,00763h
 otir
 ld a,(_back_page)
 out (063h),a
 inc hl
 ld b,4
 otir
 ld a,52
 out (064h),a
 ld a,040h
 out (063h),a
 dec de
 jr sc_copy_next
#endasm
}
#endif
#endif
void water_prepare(u8 frame){
    const u8 *p,*b;u16 n;volatile u8 pose=frame&127; /* zsdcc -SO3 argument-mask workaround. */
    if(valid&&cached==pose)return;
    if(valid)copy(bx,768+by,bx,512+by,bw,bh,0);
    else copy(0,768,0,512,256,192,0);
    p=bank_record(BANK_MESH,pose,4096);b=p+MESH_BBOX_OFFSET;
    bx=b[0]&254;by=b[1];bh=b[3];bw=(((u16)b[0]+b[2]+1)&0xfffe)-bx;
#ifdef V9990_PACKETS
    stream_fill(p);
#else
    n=p[0]|((u16)p[1]<<8);p+=2;
    while(n--){fill(p[0],512+p[2],p[4]|((u16)p[5]<<8),p[6]|((u16)p[7]<<8),p[8]);p+=11;}
#endif
    valid=1;cached=pose;
}
void water_draw(const u8 *p){
#ifdef V9990_PACKETS
    stream_copy(p);
#else
    u8 n=*p++,y=0,sx,dx,sy,h,i;u16 w;
    while(n--){sx=*p++;dx=*p++;w=*p++;if(!w)w=256;sy=*p++;h=*p++;
        copy(sx,512+sy,dx,(u16)back_page*256+y,w,h,0);
        if(sx||dx)for(i=0;i<2;++i)copy(dx?0:255,512+sy,dx?i:254+i,(u16)back_page*256+y,1,h,0);
        y+=h;
    }
#endif
}
void header_shadow(u8 scene){copy(0,960+(u16)scene*9,8,(u16)back_page*256+5,186,9,1);}
