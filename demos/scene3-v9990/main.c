#include <stdlib.h>
#include <stdio.h>
#include "v9968.h"
#include "platform.h"
#include "mapper.h"
#include "bank-layout.h"
#ifdef V9990_TARGET
#include "v9990.h"
#endif
#define T8(n) (*((volatile u8*)(0xcf00+(n))))
#define T16(n) (*((volatile u16*)(0xcf00+(n))))
void video_wait(void);
u8 use_r800;
/* Stable test boundaries; never read or change mapper/VDP state. */
/* Volatile writes prevent optimizer removal of measurement boundaries. */
void scene_ready(void){T8(22)=1;}
void frame_start(void){T8(22)=2;}
void draw_done(void){T8(22)=3;}
void frame_done(void){T8(22)=4;}
#if defined(V9990_PACKETS) || defined(V9968_WATER_PACKETS)
/* Verify the original bank63 and the packet-stream upper bank127. */
static u8 c_mapper_check(void){
    const u8 *p=(const u8*)0xbff0;u8 ok;
    if(!mapper_check())return 0;
    bank_select(127);
#ifdef V9968_WATER_PACKETS
    ok=p[0]=='S'&&p[1]=='3'&&p[2]=='W'&&p[3]=='P';
#else
    ok=p[0]=='S'&&p[1]=='3'&&p[2]=='C'&&p[3]=='P';
#endif
    bank_select(1);return ok;
}
#endif
int main(void){
    u16 frame=0,epoch,now;u8 pose,phase,key,last=0,paused=0,wave=1;
#if defined(V9990_PACKETS) || defined(V9968_WATER_PACKETS)
    if(!c_mapper_check()){puts("ASCII16 2M REQUIRED");return 1;}
#else
    if(!mapper_check()){puts("ASCII16 1M REQUIRED");return 1;}
#endif
    if(*((u8*)0x002d)==3){platform_r800_rom();use_r800=1;}
    /* Install our own video/IM2 state with BIOS interrupts disabled. */
#asm
    di
#endasm
    if(!video_init()){
        T8(6)=2; /* Initialization rejected before replacing the BIOS IRQ. */
        /* Restore CPU interrupt acceptance; BIOS text mode is still intact. */
#asm
        ei
#endasm
        /* BIOS CHGMOD(A=0): initialize text mode for BIOS puts/CHPUT.
         * C meaning: set BIOS foreground/background/border, then SCREEN 0.
         * Direct BIOS ABI has no portable C equivalent; page 0 remains BIOS. */
        *((volatile u8*)0xf3e9)=15;
        *((volatile u8*)0xf3ea)=1;
        *((volatile u8*)0xf3eb)=1;
#asm
        push ix
        push iy
        xor a
        call 005fh
        pop iy
        pop ix
#endasm
        puts("VIDEO DEVICE REQUIRED");for(;;){}
    }
    background_load(BANK_SEABED);
    for(key=0;key<32;++key)T8(key)=0;
    T8(14)=1;timer_start();epoch=clock_ticks();scene_ready();
    for(;;){
        if(T8(16)==2){while(!T8(17)){}pose=T8(18);phase=T8(19);}
        else if(T8(16)==1){pose=frame&127;phase=(u8)frame;}
        else{now=paused?0:clock_ticks()-epoch;pose=(now>>1)&127;phase=(u8)(((unsigned long)now*522)>>8);}
        T8(4)=pose;T8(5)=phase;T8(7)=back_page;frame_start();
        water_prepare(pose);
#if defined(V9990_PACKETS) || defined(V9968_WATER_PACKETS)
        if(wave)water_draw(bank_record(64,phase,4096));
#else
        if(wave)water_draw(bank_record(BANK_WATER,phase,512));
#endif
        else{bank_select(BANK_IDENTITY);water_draw((const u8*)0x8000);}
        if(T8(14))header_shadow(2);
        video_wait();draw_done();
        flip();T16(0)=++frame;T16(2)=clock_ticks();frame_done();
        T8(17)=0;
        if(!(platform_keyboard_row(7)&4)){
            /* No portable C equivalent: mask IRQ before muting PSG so the
             * music ISR cannot restart it while the final image is held. */
#asm
            di
#endasm
            silence();T8(15)=1;for(;;){}
        }
        key=!(platform_keyboard_row(4)&32);
        if(key&&!last){paused^=1;epoch=clock_ticks();}last=key;
        key=!(platform_keyboard_row(5)&16); /* W: row 5 bit 4 */
        if(key&&!T8(20))wave^=1;T8(20)=key;T8(21)=wave;
    }
}
