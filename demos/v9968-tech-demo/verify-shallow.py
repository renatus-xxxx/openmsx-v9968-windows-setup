"""Offline bounds/format checks; emulator pixel checks are separate.
Run after generate-megarom.py. Never reports unperformed hardware tests.
"""
from pathlib import Path
import json,hashlib
from PIL import Image
root=Path(__file__).resolve().parent
layout=json.loads((root/'assets/bank-layout.json').read_text())
data=(root/'assets/megarom-data.bin').read_bytes()
floor=Image.open(root/'assets/shallow-floor.png')
atlas=Image.open(root/'assets/shallow-caustics.png')
assert set(floor.tobytes())<=set(range(4))
assert set(atlas.tobytes())=={0,4,8,12}
assert atlas.size==(256,20480) and floor.size==(256,192)
start=(layout['SHALLOW_WAVE']['bank']-1)*16384
table=data[start:start+32768]
for phase in range(128):
    record=table[phase*256:(phase+1)*256];n=record[0];y=20
    assert 0<n<=63
    for i in range(n):
        sx,sy,dy,h=record[1+i*4:5+i*4]
        assert sx%2==0 and 0<=sx<=16 and 0<=sy and sy+h<=192 and h>0 and dy==y
        y+=h
    assert y==180 and not any(record[1+n*4:])
# Reconstruct every delta, including wrap; verify sizes and all write ranges.
import struct
full_offset=(layout['CAUSTICS']['bank']-1)*16384
delta_offset=(layout['CAUSTIC_DELTA']['bank']-1)*16384
raw=[]
for m in range(128):
    pixels=atlas.crop((0,m*160,256,(m+1)*160)).tobytes()
    raw.append(bytes((pixels[i]<<4)|pixels[i+1] for i in range(0,len(pixels),2)))
    if m%8==0:assert data[full_offset+(m//8)*32768:][:20480]==raw[-1]
assert layout['CAUSTICS']['frames']==16
for m in range(128):
    old=raw[(m-1)&127]
    expected=raw[m];actual=bytearray(old)
    for chunk,(base,limit) in enumerate([(0,16384),(16384,4096)]):
        record=data[delta_offset+m*16384+chunk*8192:][:8192]
        count=struct.unpack_from('<H',record)[0];pos=2;end=0
        for i in range(count):
            address,length=struct.unpack_from('<HB',record,pos);pos+=3
            assert length>0 and address>=end and address+length<=limit and pos+length<=8192
            actual[base+address:base+address+length]=record[pos:pos+length];pos+=length;end=address+length
        assert not any(record[pos:])
    assert actual==expected
    pixels=atlas.crop((0,m*160,256,(m+1)*160)).tobytes()
    assert expected==bytes((pixels[i]<<4)|pixels[i+1] for i in range(0,len(pixels),2))
for distance in [2,3]:
    # Direct two-phase jump records reconstruct the target without replay.
    entry=layout['CAUSTIC_JUMP'+str(distance)];off=(entry['bank']-1)*16384
    for m in range(128):
        actual=bytearray(raw[(m-distance)&127]);expected=raw[m]
        record=data[off+m*16384:][:16384];tail=struct.unpack_from('<H',record)[0]
        assert 2<tail<16384
        for start,base,limit,record_end in [(2,0,16384,tail),(tail,16384,4096,16384)]:
            count=struct.unpack_from('<H',record,start)[0];pos=start+2;end=0
            for i in range(count):
                address,length=struct.unpack_from('<HB',record,pos);pos+=3
                assert length>0 and address>=end and address+length<=limit and pos+length<=record_end
                actual[base+address:base+address+length]=record[pos:pos+length];pos+=length;end=address+length
            if start==2:assert pos==tail
            else:assert not any(record[pos:])
        assert actual==expected
# All generated Sprite mode3 SAT phases: source extent, palette, transparency,
# header exclusion, end marker and hardware scanline-plane limit.
pattern_start=(layout['SURFACE_PATTERN']['bank']-1)*16384
assert layout['SURFACE_PATTERN']['bytes']==4096
sparkle_pattern=data[pattern_start+2048:pattern_start+4096]
assert all((b>>4) in ({0}|set(range(8,16))) and (b&15) in ({0}|set(range(8,16))) for b in sparkle_pattern)
assert any(sparkle_pattern)
entry=layout['SURFACE_ATTRS'];off=(entry['bank']-1)*16384
opacity_seen=set();max_scanline=0;max_step=0
for phase in range(128):
    record=data[off+phase*512:][:512];spans=[]
    following=data[off+((phase+1)&127)*512:][:512]
    for i in range(62):
        y,sz,h,pal,x,pts,width,px=record[i*8:i*8+8]
        assert sz==0 and pts==32 and px>>4 in (10,11) and pal&15==1 and pal>>6 in (0,1,2,3)
        assert 8<=x and x+width<=248 and 20<=y and y+h+1<=180
        spans.append((y+1,y+1+h))
        opacity_seen.add(pal>>6)
        if i<20:assert px>>4==11 and px&15<=12 and 100<=x and x+width<=165
        elif i<30:assert px in (0xac,0xbc) and pal>>6 in (1,2,3)
        else:assert px>>4==10 and px&15<12
        max_step=max(max_step,abs(following[i*8]-y),abs(following[i*8+4]-x))
    assert max(sum(a<=y<b for a,b in spans) for y in range(192))<=16
    assert record[496]==216 and not any(record[504:])
    max_scanline=max(max_scanline,max(sum(a<=y<b for a,b in spans) for y in range(192)))
    for row in range(8):
        for seg in range(3):
            a=(30+row*4+seg)*8;b=a+8
            assert record[a+4]+record[a+6]==record[b+4]
            assert record[a]==record[b] and record[a+2:a+4]==record[b+2:b+4]
assert opacity_seen=={0,1,2,3} and max_step<=4  # includes phase 127 -> 0

assert 0x10000+20480==0x15000 and 0x16000<=0x17e00 and 0x17e00+512==0x18000
assert layout['CAUSTIC_JUMP3']['bank']>255
# Analytic pinhole identities: a world point projects back to the source pixel.
import importlib.util
spec=importlib.util.spec_from_file_location('shallow',root/'generate-shallow.py');g=importlib.util.module_from_spec(spec);spec.loader.exec_module(g)
import math
for phase in range(128):
    t=phase*math.tau/128
    for row,y0 in enumerate([48,63,77,89,100,110,121,134,147,158]):
        for side in range(2):
            x0=139-.12*(y0-48)+[-4,3][side]+[-2,1,3,-1,0,2,-3,1,0,-1][row]
            y1=y0+([-2,3][side] if row%2 else [2,-3][side])
            u,v=g.ground(x0,y1);x,z=g.follow_water(u,v,t);uu,vv=g.water_warp(x,z,t)
            assert max(abs(u-uu),abs(v-vv))<1e-5
generated_patterns,generated_attrs=g.surface_assets()
assert data[pattern_start:pattern_start+4096]==generated_patterns
assert data[off:off+65536]==generated_attrs
for y in range(192):
    for x in (0,8,128,248,255):
        xx,z=g.ground(x,y)
        assert abs((28800/z-84)-y)<1e-10
        assert abs((128+xx*180/z)-x)<1e-10
assert g.ground(228,20)[0]>2.5*g.ground(228,180)[0]
assert 960+7*9<=1024
assert layout['summary']['allocated_bytes']<=layout['summary']['rom_bytes']-16384
result=dict(pass_offline=True,wave_phases=128,native_light_pixels=256*160,
            mask_frames=128,affine_states=128,all_cross_product_pixels_tested=False,
            vram_bytes=131072,rom_bytes=layout['summary']['rom_bytes'],
            floor_sha256=hashlib.sha256(floor.tobytes()).hexdigest(),
            atlas_sha256=hashlib.sha256(atlas.tobytes()).hexdigest())
print(json.dumps(result,indent=2))
