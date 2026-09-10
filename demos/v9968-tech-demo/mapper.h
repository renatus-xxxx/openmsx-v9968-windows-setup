#ifndef V9968_DEMO_MAPPER_H
#define V9968_DEMO_MAPPER_H
/* ASCII16-X page-2 window; IRQ code and PSG data stay in fixed bank 0. */
void bank_select(unsigned int bank) __z88dk_fastcall;
const unsigned char *bank_record(unsigned char first,unsigned char frame,unsigned int stride);
unsigned char mapper_check(void);
#endif
