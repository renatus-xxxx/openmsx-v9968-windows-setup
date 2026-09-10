/* Original three-voice D minor arpeggio, PSG only; 112.5 BPM at 60 Hz.
   Synth-like pulse bass, classical broken chords and a high counterline. */
#include <stdlib.h>
#include "v9968.h"
static const u16 notes[]={381,320,254,190,453,381,320,226,571,480,381,285,508,404,339,254};
static void psg(u8 r,u8 v){outp(0xa0,r);outp(0xa1,v);}
void silence(void){psg(8,0);psg(9,0);psg(10,0);}
void music_tick(void){
    u16 n;u8 s,chord,step,io;
    if(ticks%8)return;
    step=ticks/8;chord=(step/16)&3;s=chord*4+(step&3);n=notes[s];
    outp(0xa0,7);io=inp(0xa2)&192;psg(7,io|56);
    psg(0,n);psg(1,n>>8);psg(8,10);
    n=notes[chord*4]*2;psg(2,n);psg(3,n>>8);psg(9,(step&1)?7:11);
    n=notes[chord*4+((step/2+2)&3)]/2;psg(4,n);psg(5,n>>8);psg(10,7);
}
