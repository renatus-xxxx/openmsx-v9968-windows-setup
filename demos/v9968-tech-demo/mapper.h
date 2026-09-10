#ifndef V9968_DEMO_MAPPER_H
#define V9968_DEMO_MAPPER_H
/* ASCII16 page-2 window (register at 7000h); IRQ code and PSG data stay in
   fixed bank 0. Bank numbers stay below 256, so the write is plain ASCII16
   and also works unchanged on ASCII16-X hardware. */
void bank_select(unsigned int bank) __z88dk_fastcall;
const unsigned char *bank_record(unsigned char first,unsigned char frame,unsigned int stride);
unsigned char mapper_check(void);
#endif
