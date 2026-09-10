"""Compile the background plate and procedural metal into SCREEN 5 data.
Python 3 + Pillow, only needed when changing assets. No network access.
"""
from pathlib import Path
import math
from PIL import Image

ROOT = Path(__file__).resolve().parent
OUT = ROOT / 'assets'
PAL5 = [(0,0,1),(1,2,3),(2,3,5),(3,5,7),(4,7,10),(6,10,13),
        (9,13,16),(13,18,21),(5,6,7),(9,10,11),(14,15,16),
        (20,21,22),(25,27,28),(31,31,30),(9,27,31),(23,17,8)]
PAL = [tuple(round(v*255/31) for v in c) for c in PAL5]
palette_image = Image.new('P',(1,1))
palette_image.putpalette(sum((list(c) for c in PAL), [])+[0]*(768-48))
bg=Image.open(OUT/'chamber-source.png').convert('RGB').resize((256,192),Image.Resampling.BOX)
bg=bg.quantize(palette=palette_image,dither=Image.Dither.NONE)
bg.save(OUT/'chamber-256.png')
seabed=Image.open(OUT/'seabed-source.png').convert('RGB').resize((256,192),Image.Resampling.BOX)
seabed=seabed.quantize(palette=palette_image,dither=Image.Dither.NONE)
seabed.save(OUT/'seabed-256.png')

# Eighty-pixel sphere, computed normals and an analytic reflected environment.
# Zero is reserved for transparent pixels; no claim of runtime ray tracing.
size=80;pix=[]
for y in range(size):
    for x in range(size):
        nx=(x-39.5)/38.5;ny=(y-39.5)/38.5;r2=nx*nx+ny*ny
        c=0
        if r2<=1:
            nz=math.sqrt(1-r2);rx=2*nx*nz;ry=2*ny*nz;rz=2*nz*nz-1
            # Reflected arch, dark horizon and luminous narrow panels.
            v=0.16+0.33*(1-ny)+0.15*math.sin(8*ry+2*rx)
            if -.12<ry<.18:v=.10
            if ry<-.72:v=.88
            if abs(rx+.52)<.06 and rz>-.5:v=1
            c=8+max(0,min(5,int(v*6)))
            if nx>.72:c=14
            if abs(nx)<.04 and ny<-.7:c=13
            if nz<.19:c=12
        pix.append(c)
orb=Image.new('P',(size,size));orb.putpalette(palette_image.getpalette());orb.putdata(pix);orb.save(OUT/'metal-80.png')
print('Generated chamber-256.png, seabed-256.png and metal-80.png; run generate-megarom.py next.')
