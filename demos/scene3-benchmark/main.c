/* Scene 3 only. Same ROM, geometry and commands on V9938/V9958/V9968. */
#include <stdio.h>
#include <stdlib.h>
#include "v9968.h"
#include "platform.h"
#include "mapper.h"
#include "bank-layout.h"
extern u8 benchmark_vdp,benchmark_mode;
void benchmark_set_mode(u8 mode);
void benchmark_font(void);
void benchmark_text(u8 x,u8 y,const char *s);
u8 use_r800;
/* Test-visible completed-frame boundary, also useful for fixed-pose captures. */
void benchmark_present(void){flip();}
int main(void){
    u8 was_f=0,was_p=0,key,paused=0;
    u16 frame=0,epoch,start,count=0,fps10=0,now,elapsed,dt;
    char text[32];
    if(*((u8*)0x002d)<1){puts("MSX2 OR LATER REQUIRED");for(;;){}}
    if(!mapper_check()){puts("ASCII16 1M REQUIRED");for(;;){}}
    if(*((u8*)0x002d)==3){platform_r800_rom();use_r800=1;}
#asm
    di
#endasm
    if(!video_init()){
#asm
        ei
#endasm
        puts("V9938/V9958/V9968 REQUIRED");for(;;){}
    }
    background_load(BANK_SEABED);benchmark_font();
    *((volatile u8*)0xcf06)=0;*((volatile u8*)0xcf07)=1;
    timer_start();epoch=start=clock_ticks();
    for(;;){
        now=clock_ticks();elapsed=paused?0:(u16)(now-epoch);
        background();
        stream_spans(bank_record(BANK_MESH,(elapsed>>1)&127,4096));
        water_capture();
        water_draw(bank_record(BANK_WATER,(u8)(((unsigned long)elapsed*522)>>8),512));
        rect(0,0,256,16,0);rect(0,176,256,16,0);
        benchmark_text(8,0,"SCENE3 BENCHMARK");
        benchmark_text(8,8,benchmark_mode==0?"FULL  HS ON  RGB5":
            (benchmark_mode==1?"FAST  HS ON  RGB3":"COMPAT HS OFF RGB3"));
        sprintf(text,"V%u %s FPS %u.%u",benchmark_vdp==3?9968:(benchmark_vdp==2?9958:9938),
            use_r800?"R800":"Z80",fps10/10,fps10%10);
        benchmark_text(8,180,text);
        benchmark_present();++frame;++count;
        now=clock_ticks();dt=now-start;
        if(dt>=120){fps10=(u16)((unsigned long)count*600/dt);count=0;start=now;}
        *((volatile u16*)0xcf00)=frame;*((volatile u16*)0xcf02)=now;
        *((volatile u8*)0xcf04)=2;
        *((volatile u8*)0xcf09)=benchmark_mode;
        *((volatile u8*)0xcf0a)=benchmark_vdp;
        *((volatile u8*)0xcf0b)=use_r800;
        *((volatile u16*)0xcf0c)=fps10;
        *((volatile u8*)0xcf0e)=paused;
        if(!(platform_keyboard_row(7)&4)){video_stop();for(;;){}}
        key=!(platform_keyboard_row(3)&8); /* F: row 3 bit 3 */
        if(key&&!was_f&&benchmark_vdp==3){
            benchmark_set_mode((benchmark_mode+1)%3);
            epoch=start=clock_ticks();count=0;fps10=0;
        }
        was_f=key;
        key=!(platform_keyboard_row(4)&32); /* P: row 4 bit 5 */
        if(key&&!was_p){paused^=1;epoch=start=clock_ticks();count=0;fps10=0;}
        was_p=key;
    }
}
