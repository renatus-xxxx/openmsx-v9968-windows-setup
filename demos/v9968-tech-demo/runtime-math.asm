; Runtime dispatch for zsdcc's 16-bit product helper.
; ABI: HL * DE -> low 16 bits in HL; AF, BC, DE may be destroyed.
; Compatible with z88dk libsrc/_DEVELOPMENT/l/sdcc/__mulint_callee.asm.
SECTION code_clib
PUBLIC l_mulu_16_16x16
EXTERN _use_r800
EXTERN l_small_mul_16_16x16
l_mulu_16_16x16:
    ld a,(_use_r800)
    or a
    jp z,l_small_mul_16_16x16
    ld b,d
    ld c,e
    defb $ed,$c3 ; R800 MULUW HL,BC, DEHL = unsigned 32-bit product
    and a
    ret
