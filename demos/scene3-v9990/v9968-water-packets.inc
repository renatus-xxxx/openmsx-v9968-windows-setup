/* Included only by the isolated V9968 packet build.
 * Source page 2 stays immutable while commands write the back display page.
 * Record: count16, then R32..R46 bytes. Only DY high (byte 7) is dynamic.
 * Both implementations use the existing bounded CE wait and fault action.
 */
#ifdef V9968_WATER_PACKETS_C
static void stream_water_packets(const u8 *p) __z88dk_fastcall {
    u16 count=(u16)p[0]|((u16)p[1]<<8);
    u8 i;
    p+=2;
    while(count--){
        wait_cmd();reg(17,32);
        for(i=0;i<15;++i){vcmd=(i==7)?back_page:*p;++p;}
    }
}
#else
/* C equivalent above. IRQ preserves both register sets, restores S#2,
 * and never touches the mapper or R17. DI/EI protects the control latch.
 * stream_wait preserves DE/HL, clobbering AF/BC; no timing-only CE shortcut.
 */
static void stream_water_packets(const u8 *p) __z88dk_fastcall __naked {
#asm
    GLOBAL _vctrl
    GLOBAL _vcmd
    ld e,(hl)
    inc hl
    ld d,(hl)
    inc hl
wp_next:
    ld a,d
    or e
    ret z
    call _stream_wait
    di
    ld a,32
    out (_vctrl),a
    ld a,091h
    out (_vctrl),a
    ei
    ld b,7
    ld c,_vcmd
    otir
    ld a,(_back_page)
    out (_vcmd),a
    inc hl
    ld b,7
    otir
    dec de
    jr wp_next
#endasm
}
#endif

void water_draw(const u8 *p){stream_water_packets(p);}
