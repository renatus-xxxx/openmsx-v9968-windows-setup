"""Independent packet layout/coverage check; does not execute an emulator."""
import importlib.util,json,struct
from pathlib import Path
root=Path(__file__).resolve().parent
spec=importlib.util.spec_from_file_location('generator',root/'generate-v9968-packets.py')
gen=importlib.util.module_from_spec(spec);spec.loader.exec_module(gen)
source=(root.parent/'v9968-tech-demo/V9968-TECH-DEMO.rom').read_bytes()
payload,layout=gen.generate(source);rom=bytes(16384)+payload
for phase in range(257):
    oldpos=46*16384+phase*512 if phase<256 else 54*16384
    pos=64*16384+phase*4096 if phase<256 else 54*16384
    old=source[oldpos:oldpos+512];count=int.from_bytes(rom[pos:pos+2],'little')
    assert pos//16384==(pos+2+count*15-1)//16384
    assert 2+count*15<=4080
    # Encode each source pixel as its coordinate, so repeated edge pixels are distinguishable.
    expected=[None]*49152;y=0
    for i in range(old[0]):
        sx,dx,w,sy,h=old[1+i*5:6+i*5];w=w or 256
        for yy in range(h):
            for x in range(256):expected[(y+yy)*256+x]=(sy+yy)*256+max(0,min(255,x+sx-dx))
        y+=h
    actual=[None]*49152;writes=[0]*49152;body=edges=0
    for i in range(count):
        sx,sy,dx,dy,w,h,color,arg,cmd=struct.unpack_from('<6H3B',rom,pos+2+15*i)
        assert 512<=sy<704 and sy+h<=704 and 0<=dy<192 and dy+h<=192
        assert w>0 and h>0 and sx+w<=256 and dx+w<=256 and color==arg==0
        assert cmd in [0xd0,0x90]
        if cmd==0xd0:
            assert not ((sx|dx|w)&1);body+=1
        else:
            assert w==1 and sx in [0,255] and dx in [0,1,254,255];edges+=1
        for yy in range(h):
            for xx in range(w):
                off=(dy+yy)*256+dx+xx;writes[off]+=1;actual[off]=(sy-512+yy)*256+sx+xx
    assert body==old[0] and edges%2==0 and all(n==1 for n in writes)
    assert actual==expected
assert rom[127*16384+0x3ff0:127*16384+0x3ff4]==b'S3WP'
# Deliberately unsupported geometry must be rejected, not silently truncated.
bad=bytearray(source);bad[46*16384+1]=1
try:gen.generate(bad)
except ValueError:pass
else:raise AssertionError('Invalid source geometry was accepted')
print(json.dumps({'pass':True,'wave_phases':256,'identity_records':1,
 'pixels_checked':257*49152,'overlaps':0,'holes':0,'negative_geometry_rejected':True,
 'layout':layout},indent=2))
