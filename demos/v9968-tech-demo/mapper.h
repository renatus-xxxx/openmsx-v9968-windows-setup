#ifndef V9968_DEMO_MAPPER_H
#define V9968_DEMO_MAPPER_H
/* ASCII16 page-2 window (register at 7000h); IRQ code and PSG data stay in
   fixed bank 0. Bank selection and record first-bank arguments carry 16-bit values;
   ASCII16-X encodes the upper four bank bits in the register address. */
void bank_select(unsigned int bank) __z88dk_fastcall;
const unsigned char *bank_record(unsigned int first,unsigned char frame,unsigned int stride);
unsigned char mapper_check(void);
#endif
