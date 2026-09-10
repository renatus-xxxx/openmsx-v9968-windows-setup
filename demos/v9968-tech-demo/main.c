#include <stdlib.h>
#include <stdio.h>
#include "v9968.h"
#include "platform.h"
#include "mapper.h"
#include "bank-layout.h"
static u8 angle;
/* Read from runtime-math.asm: selects the R800 MULUW path over the Z80
   software multiply. Not static; the assembly references it as _use_r800. */
u8 use_r800;
static void core(u8 a){
    const u8 *p=bank_record(BANK_CORE,a,128);
    u8 i,j,pass,k;
    for(pass=0;pass<2;++pass){
        if(pass)orb_draw(88,56);
        for(i=0;i<32;++i){
            k=(p[64+(i>>3)]>>(i&7))&1;if(k!=pass)continue;
            j=(i&16)|((i+1)&15);
            line(p[i*2],p[i*2+1],p[j*2],p[j*2+1],pass?12:5);
            line(p[i*2],p[i*2+1]+1,p[j*2],p[j*2+1]+1,(i&16)?14:9);
        }
    }
}
/* Assets with fewer than 256 frames must be masked; bank_record() takes the
   index as an unsigned char, so the 256-frame tables are already bounded. */
static void mesh(u8 a){stream_spans(bank_record(BANK_MESH,a&(FRAMES_MESH-1),4096));}
static void triangle(int x0,int y0,int x1,int y1,int x2,int y2,u8 col){
    int tmp,dl,ds1,ds2,xl,xs,y,left,right;
    if(y1<y0){tmp=y0;y0=y1;y1=tmp;tmp=x0;x0=x1;x1=tmp;}
    if(y2<y0){tmp=y0;y0=y2;y2=tmp;tmp=x0;x0=x2;x2=tmp;}
    if(y2<y1){tmp=y1;y1=y2;y2=tmp;tmp=x1;x1=x2;x2=tmp;}
    if(y0==y2)return;
    dl=(x2-x0)*64/(y2-y0);
    ds1=y1==y0?0:(x1-x0)*64/(y1-y0);
    ds2=y2==y1?0:(x2-x1)*64/(y2-y1);
    xl=x0*64;xs=xl;
    for(y=y0;y<=y2;++y){
        if(y==y1)xs=x1*64;
        left=xl>>6;right=xs>>6;
        if(left>right){tmp=left;left=right;right=tmp;}
        rect(left,y,right-left+1,1,col);
        xl+=dl;xs+=(y<y1)?ds1:ds2;
    }
}
static void shards(u8 a){
    const u8 *p=bank_record(BANK_SHARDS,a,128);
    u8 i,k;const u8 *v;
    for(i=0;i<12;++i){
        k=p[72+i];v=p+k*6;
        triangle(v[0],v[1],v[2],v[3],v[4],v[5],9+(k&3));
        line(v[0],v[1],v[2],v[3],13);
    }
}
int main(void){
    u8 scene,row,key,previous=255,manual=0,wave=1,was_w=0;u16 frame=0,now;
    if(!mapper_check()){puts("ASCII16 REQUIRED\nReset to exit.");for(;;){inp(0xa9);}}
    *((volatile u8*)0xcf07)=1;
    /* MSX BIOS generation byte: 3 = turbo R; CHGCPU, R800 ROM mode. */
    if(*((u8*)0x002d)==3){
        platform_r800_rom();
        use_r800=1;
    }
#asm
    di
#endasm
    if(!video_init()){
#asm
        ei
#endasm
        puts("V9968 TECH DEMO\nV9968 REQUIRED\nReset to exit.");for(;;){inp(0xa9);}
    }
    *((volatile u8*)0xcf06)=0;
    timer_start();
#ifdef V9968_DEMO_DIAGNOSTIC
    background();
    line(40,40,200,40,14);line(200,40,200,150,14);
    line(200,150,40,150,14);line(40,150,40,40,14);
    line(40,40,200,150,15);line(200,40,40,150,15);
    flip();for(;;){inp(0xa9);}
#endif
    for(;;){
        now=clock_ticks();angle=now/2;scene=manual?manual-1:(now/900)%5;
        if(previous==2 && scene!=2){textures_load();background_load(BANK_BACKGROUND);}
        if(previous!=2 && scene==2)background_load(BANK_SEABED);
        if(scene!=2)background();
        if(scene==0)mesh((u8)(now>>1));
        if(scene==1){floor_draw((const int*)bank_record(BANK_FLOOR,(now>>1)&(FRAMES_FLOOR-1),512));core(angle);}
        if(scene==2){
            /* Same pose clock as Scene 1; capture clean geometry every frame. */
            background();mesh((u8)(now>>1));water_capture();
            /* Q8 phase: 522/256 steps/tick, ~3.003 rad/s at 60 Hz. */
            if(wave)water_draw(bank_record(BANK_WATER,(u8)(((unsigned long)now*522)>>8),512));
            else{bank_select(BANK_IDENTITY);water_draw((const u8*)0x8000);}
            title_restore();
        }
        if(scene==3)panel_draw((const int*)bank_record(BANK_ROTATION,(u8)now,8));
        if(scene==4){core(angle);shards(angle);}
        previous=scene;
        line(12,16,244,16,5);line(12,176,244,176,5);
        for(row=0;row<5;++row)rect(106+row*10,182,6,2,row==scene?15:4);
        scene_label(scene);palette(angle);flip();++frame;
        /* Runtime telemetry for emulator tests, ordinary MSX RAM. */
        *((volatile u16*)0xcf00)=frame;*((volatile u16*)0xcf02)=ticks;
        *((volatile u8*)0xcf04)=scene;
        *((volatile u8*)0xcf08)=wave;
        /* platform_keyboard_row() saves and restores the PPI row select. */
        key=platform_keyboard_row(7);
        if(!(key&4)){video_stop();for(;;){inp(0xa9);}}
        key=platform_keyboard_row(0);
        for(row=0;row<6;++row)if(!(key&(1<<row)))manual=row;
        key=!(platform_keyboard_row(5)&0x10);if(key&&!was_w)wave^=1;was_w=key;
    }
}

