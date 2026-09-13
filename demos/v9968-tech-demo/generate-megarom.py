"""Generate banked assets: projected geometry, scanlines, LRMM and water maps.
Python 3 + Pillow. No network or copied OpenGL code.
"""
from pathlib import Path
import math, struct, json, hashlib
from PIL import Image, ImageDraw

P=Path(__file__).resolve().parent
OUT=P/'assets'
BANK=16384
banks=[bytes(BANK)]  # bank 0 is replaced by the linked C program
layout={}
def add(name,data,stride=0):
    start=len(banks)
    for n in range(0,len(data),BANK):banks.append(data[n:n+BANK].ljust(BANK,b'\xff'))
    entry={'bank':start,'bytes':len(data),'stride':stride}
    if stride:
        # bank_record() addresses these by frame index. The runtime masks the
        # index with FRAMES-1, so the count must be a power of two and fit in
        # the unsigned char it is passed as. Without this the demo would read
        # into whatever asset follows.
        assert len(data)%stride==0,f'{name}: {len(data)} bytes is not a multiple of stride {stride}'
        frames=len(data)//stride
        assert 0<frames<=256 and frames&(frames-1)==0,f'{name}: {frames} frames must be a power of two, 1..256'
        assert BANK%stride==0,f'{name}: stride {stride} must divide the {BANK}-byte bank window'
        entry['frames']=frames
    layout[name]=entry
def packed(im):
    v=im.tobytes();return bytes((v[i]<<4)|v[i+1] for i in range(0,len(v),2))
def ints(v):return struct.pack('<'+'h'*len(v),*v)
T=math.tau
def proj(x,y,z,a,tilt,scale=160):
    xx=x*math.cos(a)+z*math.sin(a);zz=z*math.cos(a)-x*math.sin(a)
    yy=y*math.cos(tilt)-zz*math.sin(tilt);d=y*math.sin(tilt)+zz*math.cos(tilt)+256
    return round(128+xx*scale/d),round(96+yy*scale/d),d

font = json.loads((OUT/'fonts.json').read_text(encoding='utf-8'))['msx8x8']
add('BACKGROUND',packed(Image.open(OUT/'chamber-256.png').copy()))
add('ORB',packed(Image.open(OUT/'metal-80.png')))
texture=Image.new('P',(256,128));px=texture.load()
for y in range(128):
    for x in range(256):
        c=3 if ((x//16)^(y//16))&1 else 5
        if x%32==0 or y%32==0:c=14
        elif x%32==1 or y%32==1:c=9
        elif x%8==4 and y%8==4:c=12
        if 60<=y<=63 and 84<x<172:c=15
        px[x,y]=c
add('PANEL',packed(texture))

core=bytearray();shards=bytearray();panel=bytearray()
for f in range(256):
    a=f*T/256
    v=[]
    for i in range(32):
        t=(i%16)*T/16;r=96 if i<16 else 110
        v.append(proj(r*math.cos(t),0,r*math.sin(t),a,.55+.4*math.sin(a) if i<16 else 1-.4*math.sin(a)))
    flags=sum((1<<i) for i in range(32) if v[i][2]+v[(i&16)|((i+1)&15)][2]<512)
    row=bytes(c for x,y,_ in v for c in (x,y))+flags.to_bytes(4,'little')
    core+=row.ljust(128,b'\0')
    pieces=[]
    for i in range(12):
        z=(((i*21+f)%256)-128)*.75;x=55*math.cos(i*43*T/256);y=55*math.sin(i*43*T/256)
        vertices=[proj(x,y,z,a,.3),proj(x+13,y-8,z+4,a,.3),proj(x+5,y+12,z+8,a,.3)]
        pieces.append((vertices[0][2],bytes(c for xx,yy,_ in vertices for c in (xx,yy))))
    order=sorted(range(12),key=lambda i:pieces[i][0],reverse=True)
    # shards() reads these as indices into the 12 six-byte vertex records above.
    assert all(0<=i<12 for i in order),'shard draw order out of range'
    row=b''.join(p[1] for p in pieces)+bytes(order)
    assert len(row)==12*6+12
    shards+=row.ljust(128,b'\0')
    zoom=.42+.25*(1+math.sin(a*2));vx=round(256*zoom*math.cos(a));vy=round(256*zoom*math.sin(a))
    panel+=ints([128-round((112*vx-72*vy)/256),672-round((112*vy+72*vx)/256),vx,vy])
add('CORE',core,128);add('SHARDS',shards,128);add('ROTATION',panel,8)

# An octahedron with faceted lighting and a drifting viewpoint. It is rasterized
# into colored spans offline, then the VDP fills those spans during playback.
mesh=bytearray();span_counts=[]
vertices=[(0,-88,0),(0,88,0),(-76,0,0),(0,0,-76),(76,0,0),(0,0,76)]
faces=[(tip,2+i,2+(i+1)%4) for tip in (0,1) for i in range(4)]
for f in range(128):
    a=f*T/128;tilt=.48+.42*math.sin(a*2)
    v=[proj(x,y,z,a,tilt,210+16*math.sin(a)) for x,y,z in vertices]
    im=Image.new('P',(256,192));draw=ImageDraw.Draw(im)
    for idx in sorted(range(8),key=lambda i:sum(v[j][2] for j in faces[i]),reverse=True):
        face=faces[idx];points=[(v[j][0]+round(10*math.sin(a*2)),v[j][1]) for j in face]
        shade=8+round(4*(.5+.5*math.sin(a+idx*1.7)))
        draw.polygon(points,fill=shade)
        # Filled faces; avoiding per-pixel outline runs keeps the VDP stream compact.
    runs=bytearray()
    for y in range(192):
        x=0
        while x<256:
            c=im.getpixel((x,y));end=x+1
            while end<256 and im.getpixel((end,y))==c:end+=1
            if c:runs+=bytes((x,0,y,0,end-x,0,1,0,c,0,0x80))
            x=end
    count=len(runs)//11;span_counts.append(count)
    assert len(runs)+2<=4096
    mesh+=(struct.pack('<H',count)+runs).ljust(4096,b'\0')
    if f==16:
        pal=Image.open(OUT/'chamber-256.png').getpalette();im.putpalette(pal);im.save(OUT/'mesh-source-preview.png')
add('MESH',mesh,4096)

floor=bytearray();waves=bytearray();identity=bytearray()
for f in range(128):
    a=f*T/128;row=bytearray()
    for band in range(56):
        y=64+2*band
        density=1.0-(y-64)*.006
        vx=round(256*density);vy=round(32*math.sin(a))
        cx=128+round(10*math.sin(a));cy=640+(round(800/(y-48)+f*1.5)%64)
        row+=ints([cx-round(112*vx/256),cy-round(112*vy/256),vx,vy])
    floor+=row.ljust(512,b'\0')
for f in range(256):
    row=bytearray()
    for y in range(0,192,2):
        # Reference vertical component: band center, amplitude 4, period 64.
        # OpenGL's Y grows upward; MSX's Y grows downward.
        bottom_y=190-y
        source_bottom=max(0,min(190,bottom_y+4*math.sin((bottom_y+1)*T/64+f*T/256)))
        sy=round(190-source_bottom)
        # Gentle horizontal extension; runtime repeats the edge pixels.
        dx=2*round(math.sin((y+1)*T/96-f*T/256))
        row+=bytes((max(0,-dx),max(0,dx),256-abs(dx) if dx else 0,sy))
    waves+=row.ljust(512,b'\0')
add('FLOOR',floor,512);add('WATER',waves,512)
for y in range(0,192,2):identity+=bytes((0,0,0,y))
add('IDENTITY',identity)

# Small opaque HUD labels, uploaded below the background in VRAM page 3.
font = json.loads((OUT/'fonts.json').read_text(encoding='utf-8'))['msx8x8']
SCENES=6
# The whole header line, shadow and text already composited, one strip per
# scene. The runtime draws it with a single transparent blit: the VDP skips
# source colour 0, so every non-zero pixel here lands on the picture and
# nothing else is touched.
#
# The shadow is index 1 rather than 0 because on this VDP transparency means
# "colour 0 is not written", and 0 is black: a black glyph is exactly what a
# transparent blit throws away. Index 1 is (1,2,3) of 31, which is black to the
# eye. Writing a true black shadow instead would mean clearing it with an
# opaque AND from an inverse mask, which is a second blit per string.
HUD_W,HUD_H,HUD_SHADOW=186,9,1
hud=Image.new('P',(HUD_W,HUD_H*SCENES))
def hud_line(text,ox,oy,colour):
    for pos,char in enumerate(text):
        for y,bits in enumerate(font[char]):
            for x in range(8):
                if bits & (128>>x):hud.putpixel((ox+pos*8+x,oy+y),colour)
for scene in range(SCENES):
    top=scene*HUD_H
    # Shadow first, one dot down and right, then the text over it. Baking the
    # two here gives exactly what two runtime passes would have produced.
    for text,ox,colour in (('SCENE '+str(scene+1),0,14),('V9968 TECH DEMO',65,12)):
        hud_line(text,ox+1,top+1,HUD_SHADOW)
    for text,ox,colour in (('SCENE '+str(scene+1),0,14),('V9968 TECH DEMO',65,12)):
        hud_line(text,ox,top,colour)
assert len(packed(hud))==HUD_W//2*HUD_H*SCENES
add('HUDLINE',packed(hud))

# The Scene 3 benchmark overwrites this bank with its own font atlas, so the
# bank has to stay even though the demo no longer uploads it.
labels = Image.new('P',(56,8*SCENES))
for scene in range(SCENES):
    for pos,char in enumerate('SCENE '+str(scene+1)):
        for y,bits in enumerate(font[char]):
            for x in range(8):
                if bits & (128>>x): labels.putpixel((pos*8+x,scene*8+y),14)
add('LABELS',packed(labels))
add('SEABED',packed(Image.open(OUT/'seabed-256.png').copy()))

# The ROM is declared as -romtype ASCII16, whose bank register is eight bits
# wide, so bank numbers must stay below 256. bank_select() already places the
# high bits on A8-A11, which is exactly what ASCII16-X decodes, so growing past
# this limit needs no mapper code change: raise ROM_BANKS and switch the
# declared romtype in the launchers. See DEVELOPMENT.md.
MAPPER='ASCII16'
MAPPER_BANK_LIMIT=256
ROM_BANKS=64
assert len(banks)<=ROM_BANKS,f'{len(banks)} banks do not fit the {ROM_BANKS}-bank ROM'
assert ROM_BANKS<=MAPPER_BANK_LIMIT,(
    f'{ROM_BANKS} banks exceed the {MAPPER_BANK_LIMIT}-bank limit of {MAPPER}; '
    'switch the launchers to -romtype ASCII16-X (bank_select already supports it)')
used=len(banks)*BANK
banks += [b'\xff'*BANK]*(ROM_BANKS-len(banks))
banks[-1]=banks[-1][:-16]+b'MCX2'+bytes(12)
(OUT/'megarom-data.bin').write_bytes(b''.join(banks[1:]))
header=f'/* Generated by generate-megarom.py; {MAPPER} banked data, {ROM_BANKS} banks. */\n'
for name,entry in layout.items():
    header+=f'#define BANK_{name} {entry["bank"]}\n'
    # Frame counts travel with the layout so the runtime mask cannot drift
    # away from the number of records actually generated.
    if 'frames' in entry:header+=f'#define FRAMES_{name} {entry["frames"]}\n'
header+='#define MEGAROM_BYTES 1048576UL\n'
(OUT/'bank-layout.h').write_text(header,encoding='ascii')
layout['summary']={'rom_bytes':1048576,'allocated_bytes':used,'mapper':MAPPER,'rom_banks':ROM_BANKS,
                   'mesh_max_spans':max(span_counts),'mesh_mean_spans':sum(span_counts)/128}
(OUT/'bank-layout.json').write_text(json.dumps(layout,indent=2)+'\n')
print(layout['summary'])






