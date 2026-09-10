#include "mapper.h"
void bank_select(unsigned int bank) __z88dk_fastcall __naked {
#asm
    ld a,l
    ld l,0
    ld b,a
    ld a,h
    and 15
    or 070h
    ld h,a
    ld (hl),b
    ret
#endasm
}
const unsigned char *bank_record(unsigned char first,unsigned char frame,unsigned int stride){
    unsigned int offset=(unsigned int)(frame % (16384/stride))*stride;
    bank_select(first+frame/(16384/stride));
    return (const unsigned char *)(0x8000+offset);
}
/* A known signature in the last data bank tests switching beyond startup banks. */
unsigned char mapper_check(void){
    const unsigned char *p=(const unsigned char *)0xbff0;
    bank_select(63);
    if(p[0]!='M'||p[1]!='C'||p[2]!='X'||p[3]!='2')return 0;
    bank_select(1);
    return 1;
}

