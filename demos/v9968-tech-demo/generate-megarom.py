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
    layout[name]={'bank':start,'bytes':len(data),'stride':stride}
def packed(im):
    v=im.tobytes();return bytes((v[i]<<4)|v[i+1] for i in range(0,len(v),2))
def ints(v):return struct.pack('<'+'h'*len(v),*v)
T=math.tau
def proj(x,y,z,a,tilt,scale=160):
    xx=x*math.cos(a)+z*math.sin(a);zz=z*math.cos(a)-x*math.sin(a)
    yy=y*math.cos(tilt)-zz*math.sin(tilt);d=y*math.sin(tilt)+zz*math.cos(tilt)+256
    return round(128+xx*scale/d),round(96+yy*scale/d),d

font = json.loads((OUT/'fonts.json').read_text(encoding='utf-8'))['msx8x8']
def titled_background(path):
    im=Image.open(path).copy()
    for pos,char in enumerate('V9968 TECH DEMO'):
        for y,bits in enumerate(font[char]):
            for x in range(8):
                if bits & (128>>x):im.putpixel((73+pos*8+x,5+y),12)
    return packed(im)
add('BACKGROUND',titled_background(OUT/'chamber-256.png'))
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
    row=b''.join(p[1] for p in pieces)+bytes(sorted(range(12),key=lambda i:pieces[i][0],reverse=True))
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
labels = Image.new('P',(56,40))
for scene in range(5):
    for pos,char in enumerate('SCENE '+str(scene+1)):
        for y,bits in enumerate(font[char]):
            for x in range(8):
                if bits & (128>>x): labels.putpixel((pos*8+x,scene*8+y),14)
add('LABELS',packed(labels))
add('SEABED',titled_background(OUT/'seabed-256.png'))

assert len(banks)<=64
used=len(banks)*BANK
banks += [b'\xff'*BANK]*(64-len(banks))
banks[-1]=banks[-1][:-16]+b'MCX2'+bytes(12)
(OUT/'megarom-data.bin').write_bytes(b''.join(banks[1:]))
header='/* Generated by generate-megarom.py; ASCII16-X banked data. */\n'
for name,entry in layout.items():header+=f'#define BANK_{name} {entry["bank"]}\n'
header+='#define MEGAROM_BYTES 1048576UL\n'
(OUT/'bank-layout.h').write_text(header,encoding='ascii')
layout['summary']={'rom_bytes':1048576,'allocated_bytes':used,'mesh_max_spans':max(span_counts),'mesh_mean_spans':sum(span_counts)/128}
(OUT/'bank-layout.json').write_text(json.dumps(layout,indent=2)+'\n')
print(layout['summary'])






