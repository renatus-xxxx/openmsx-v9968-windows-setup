#include <stdlib.h>
#include <stdio.h>
#include "v9968.h"
#include "platform.h"
#include "mapper.h"
#include "bank-layout.h"
static u8 angle;
/* Each mask clears exactly one bit, and the four between them clear all four.
   Under the popcount palette of the opening that means a pixel loses exactly
   one brightness level per frame whatever its phase, so the solid drawn at 15
   fades 15 -> 14 -> 12 -> 8 -> 0 in four even steps. Clearing bits can only
   lower the population count, so the trail can never brighten. */
static const u8 decay_mask[4]={0x0e,0x0d,0x0b,0x07};
/* Second-half drift timeline and 8.8 warp steps. 256 is 1:1; below magnifies. */
static const int drift_dx[8]={2,4,2,0,-2,-4,-2,0};
static const int drift_dy[8]={0,1,1,1,0,-1,-1,-1};
static const int spin_vx[8]={251,251,250,250,249,250,250,251};
static const int spin_vy[8]={0,2,3,4,3,2,0,-2};
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
/* Same span data, drawn flat at 15 for the Scene 6 opening. */
static void mesh_glow(u8 a){stream_spans_glow(bank_record(BANK_MESH,a&(FRAMES_MESH-1),4096));}
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
    u8 scene,row,key,previous=255,manual=0,wave=1,was_w=0,top_hud,revealed=0;
    u16 frame=0,now,scene_entry=0;
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
        now=clock_ticks();angle=now/2;scene=manual?manual-1:(now/900)%6;
        if(previous==2 && scene!=2){textures_load();background_load(BANK_BACKGROUND);}
        if(previous!=2 && scene==2)background_load(BANK_SEABED);
        /* Scene 6 borrows page 2 as Scene 3 does: cleared on entry, textures
           reloaded on exit. It also records its entry tick, so its own opening
           always plays from the start instead of dropping in wherever the free
           running clock happens to be when the scene is selected by hand. */
        if(previous==5 && scene!=5)textures_load();
        if(previous!=5 && scene==5){trail_clear();scene_entry=now;revealed=0;}
        if(scene!=2 && scene!=5)background();
        if(scene==0)mesh((u8)(now>>1));
        if(scene==1){floor_draw((const int*)bank_record(BANK_FLOOR,(now>>1)&(FRAMES_FLOOR-1),512));core(angle);}
        if(scene==2){
            /* Same pose clock as Scene 1; capture clean geometry every frame. */
            background();mesh((u8)(now>>1));water_capture();
            /* Q8 phase: 522/256 steps/tick, ~3.003 rad/s at 60 Hz. */
            if(wave)water_draw(bank_record(BANK_WATER,(u8)(((unsigned long)now*522)>>8),512));
            else{bank_select(BANK_IDENTITY);water_draw((const u8*)0x8000);}
        }
        if(scene==3)panel_draw((const int*)bank_record(BANK_ROTATION,(u8)now,8));
        if(scene==4){core(angle);shards(angle);}
        top_hud=1;
        if(scene==5){
            u16 el=now-scene_entry;
            if(el<180){
                /* Opening: the decay trail, deliberately with no header, scene
                   label or top rule, so the reveal below lands on a bare frame.
                   This is staging, not a regression: the second half restores
                   exactly the same HUD every other scene draws. */
                top_hud=0;
                /* The solid redraws itself over almost the same pixels, so a
                   trail that stays put is hidden under it. Growing the held
                   page a little every frame walks the fading copies out from
                   underneath. The step is large enough to matter within the
                   four frames a pixel survives; a gentler one would be over
                   before it moved. The clear is needed because the transform
                   is a transparent copy: the low nibble of 0x38 is the logical
                   operation, and 8 leaves the destination alone wherever the
                   source pixel is colour 0, which most of the history is.
                   Coverage was never the question; every destination pixel
                   does have a source inside page 2, but the ones reading
                   colour 0 are not written and would keep what the back page
                   held two frames ago. An opaque 0x30 removes the need for
                   the clear and was measured at 16.3 against 16.2 frames per
                   second here, inside the resolution of the measurement, so
                   both halves keep the same transform. */
                rect(0,0,256,192,0);
                feedback_warp(244,0);
                trail_decay(decay_mask[frame&3],back_page);
                mesh_glow((u8)(now>>1));
                feedback_capture();
            } else {
                /* Recursive feedback. The trail left on page 2 by the opening
                   becomes the first history frame, so the two halves join with
                   no visible cut. Capture runs before any HUD so the overlay
                   never recurses. The four phases repeat while the scene is
                   held by hand. */
                u16 p=(el-180)%720;u8 slot=(now>>4)&7;
                /* The opening leaves popcount indices on page 2, and 13, 14
                   and 15 are white, cyan and orange in the ordinary palette.
                   The feedback half recycles that page every frame, so without
                   a conversion those three would ride along for many
                   generations. One AND clearing bit 2 moves every index the
                   opening can produce into the grey mesh band at 8-11 or the
                   dim ramp at 0-3, in the same order, so the handoff stays
                   continuous instead of flashing. */
                if(!revealed){trail_decay(0x0b,2);revealed=1;}
                rect(0,0,256,192,0);
                if(p<180)feedback_shift(2,0);
                else if(p<360)feedback_shift(drift_dx[slot],drift_dy[slot]);
                else if(p<540)feedback_warp(251,0);
                else feedback_warp(spin_vx[slot],spin_vy[slot]);
                mesh((u8)(now>>1));
                feedback_capture();
            }
        }
        previous=scene;
        if(top_hud)line(12,16,244,16,5);
        line(12,176,244,176,5);
        /* The opening runs the popcount palette, where index 15 is the flat
           solid and cannot also be the indicator colour. It borrows index 10,
           which the decay can never produce, and the palette gives 10 the
           ordinary indicator colour for the duration. */
        for(row=0;row<6;++row)rect(101+row*10,182,6,2,row==scene?(top_hud?15:10):4);
        if(top_hud)header_shadow(scene);
        flip();++frame;
        /* One palette upload per frame, and only once flip() has waited for
           the tick, so the bytes land in the vertical blank. Uploading during
           active display tore the picture: the scanlines the beam reached
           between two uploads were drawn with the other palette, which put an
           orange band across the Scene 6 opening because its solid is index
           15 and 15 is orange in the ordinary palette. Doing it after the page
           swap also guarantees each frame is shown under its own palette.
           video_init() seeds the palette before enabling display. */
        if(scene==5 && !top_hud)palette_glow();else palette(angle);
        /* Runtime telemetry for emulator tests, ordinary MSX RAM. */
        *((volatile u16*)0xcf00)=frame;*((volatile u16*)0xcf02)=ticks;
        *((volatile u8*)0xcf04)=scene;
        *((volatile u8*)0xcf08)=wave;
        /* platform_keyboard_row() saves and restores the PPI row select. */
        key=platform_keyboard_row(7);
        if(!(key&4)){video_stop();for(;;){inp(0xa9);}}
        key=platform_keyboard_row(0);
        for(row=0;row<7;++row)if(!(key&(1<<row)))manual=row;
        key=!(platform_keyboard_row(5)&0x10);if(key&&!was_w)wave^=1;was_w=key;
    }
}

