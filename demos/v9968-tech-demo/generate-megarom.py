"""Generate banked assets: projected geometry, scanlines, LRMM and water maps.
Python 3 + Pillow. No network or copied OpenGL code.
"""
from pathlib import Path
import argparse, math, struct, json, hashlib
from PIL import Image

P=Path(__file__).resolve().parent
OUT=P/'assets'
BANK=16384
DEFAULT_MESH_RADIUS=88.0
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

def resolve_mesh_obj(value):
    path=Path(value)
    if not path.is_absolute():
        # Command-line paths are normally relative to the caller. If that does
        # not exist, also accept a path relative to this demo directory so
        # build scripts can use "assets/foo.obj" from any current directory.
        caller=Path.cwd()/path
        path=caller if caller.exists() else P/path
    path=path.resolve()
    if not path.is_file():raise FileNotFoundError(f'Mesh OBJ not found: {path}')
    return path

def obj_lines(path):
    """Join backslash continuations, reporting the first physical line."""
    pending=[];start=0
    for lineno,raw in enumerate(path.read_text(encoding='utf-8-sig',errors='replace').splitlines(),1):
        line=raw.split('#',1)[0].strip()
        if not pending:start=lineno
        continued=line.endswith(chr(92))
        pending.append(line[:-1] if continued else line)
        if continued:continue
        yield start,' '.join(pending)
        pending=[]
    if pending:raise ValueError(f'{path}:{start}: unfinished line continuation')

def load_obj(path):
    """Read geometry-only Wavefront OBJ data and triangulate polygon faces.

    Supported face tokens are v, v/vt, v//vn and v/vt/vn, including negative
    vertex indices. Texture coordinates, supplied normals, materials, groups
    and smoothing directives are intentionally ignored: this demo computes its
    own flat lighting and renders only indexed geometry.
    """
    vertices=[];faces=[];triangles=[]
    for lineno,line in obj_lines(path):
        if not line:continue
        fields=line.split();kind=fields[0]
        if kind=='v':
            if len(fields)<4:raise ValueError(f'{path}:{lineno}: vertex needs x y z')
            values=tuple(float(v) for v in fields[1:4])
            if not all(math.isfinite(c) for c in values):
                raise ValueError(f'{path}:{lineno}: vertex must be finite')
            vertices.append(values)
        elif kind=='f':
            if len(fields)<4:raise ValueError(f'{path}:{lineno}: face needs at least three vertices')
            face=[]
            for token in fields[1:]:
                head=token.split('/',1)[0]
                if not head:raise ValueError(f'{path}:{lineno}: face token has no vertex index: {token!r}')
                index=int(head)
                if index==0:raise ValueError(f'{path}:{lineno}: OBJ indices are 1-based; zero is invalid')
                index=index-1 if index>0 else len(vertices)+index
                if not 0<=index<len(vertices):raise ValueError(f'{path}:{lineno}: vertex index out of range: {token!r}')
                face.append(index)
            # OBJ polygons are commonly convex; a fan is sufficient for the
            # low-poly assets this generator targets and also handles quads.
            face_id=len(faces);faces.append(tuple(face))
            for i in range(1,len(face)-1):triangles.append((face[0],face[i],face[i+1],face_id))
    if not vertices:raise ValueError(f'{path}: no vertices found')
    if not triangles:raise ValueError(f'{path}: no faces found')
    return vertices,faces,triangles

def normalize_obj(vertices,target_radius=DEFAULT_MESH_RADIUS):
    mins=[min(v[i] for v in vertices) for i in range(3)]
    maxs=[max(v[i] for v in vertices) for i in range(3)]
    center=[(mins[i]+maxs[i])*.5 for i in range(3)]
    centered=[tuple(v[i]-center[i] for i in range(3)) for v in vertices]
    radius=max(math.sqrt(sum(c*c for c in v)) for v in centered)
    if radius<=1e-12:raise ValueError('Mesh OBJ collapses to a single point')
    scale=target_radius/radius
    return [tuple(c*scale for c in v) for v in centered]

def transform_mesh_vertex(vertex,a,tilt,scale,xdrift):
    x,y,z=vertex
    ca,sa=math.cos(a),math.sin(a);ct,st=math.cos(tilt),math.sin(tilt)
    xx=x*ca+z*sa;zz=z*ca-x*sa
    yy=y*ct-zz*st;depth=y*st+zz*ct+256.0
    if depth<=1.0:return None
    return (128.0+xdrift+xx*scale/depth,96.0+yy*scale/depth,1.0/depth,xx,yy,depth-256.0)

def mesh_shade(a,b,c):
    # Camera-space flat normal. abs(dot) intentionally makes imported geometry
    # two-sided: OBJ winding conventions vary and this demo has no material or
    # back-face state. The ordinary mesh palette owns indices 8..12.
    ux=b[3]-a[3];uy=b[4]-a[4];uz=b[5]-a[5]
    vx=c[3]-a[3];vy=c[4]-a[4];vz=c[5]-a[5]
    nx=uy*vz-uz*vy;ny=uz*vx-ux*vz;nz=ux*vy-uy*vx
    length=math.sqrt(nx*nx+ny*ny+nz*nz)
    if length<=1e-12:return 8
    nx/=length;ny/=length;nz/=length
    lx,ly,lz=(-0.35,-0.55,-0.76);ll=math.sqrt(lx*lx+ly*ly+lz*lz)
    intensity=abs((nx*lx+ny*ly+nz*lz)/ll)
    return 8+2*round(2*max(0.0,min(1.0,intensity)))

def rasterize_obj(vertices,faces,triangles,a,tilt,scale):
    width,height=256,192;xdrift=round(10*math.sin(a*2))
    tv=[transform_mesh_vertex(v,a,tilt,scale,xdrift) for v in vertices]
    pixels=bytearray(width*height);depth=[0.0]*(width*height)
    def edge(ax,ay,bx,by,px,py):return (px-ax)*(by-ay)-(py-ay)*(bx-ax)
    face_colours={}
    for ia,ib,ic,face_id in triangles:
        va,vb,vc=tv[ia],tv[ib],tv[ic]
        if va is None or vb is None or vc is None:continue
        ax,ay=va[0],va[1];bx,by=vb[0],vb[1];cx,cy=vc[0],vc[1]
        area=edge(ax,ay,bx,by,cx,cy)
        if abs(area)<1e-9:continue
        minx=max(0,int(math.floor(min(ax,bx,cx))));maxx=min(width-1,int(math.ceil(max(ax,bx,cx))))
        miny=max(0,int(math.floor(min(ay,by,cy))));maxy=min(height-1,int(math.ceil(max(ay,by,cy))))
        if minx>maxx or miny>maxy:continue
        if face_id not in face_colours:
            face=faces[face_id]
            fa,fb,fc=tv[face[0]],tv[face[1]],tv[face[2]]
            face_colours[face_id]=mesh_shade(fa,fb,fc) if fa and fb and fc else 8
        colour=face_colours[face_id];positive=area>0
        for y in range(miny,maxy+1):
            py=y+.5;base=y*width
            for x in range(minx,maxx+1):
                px=x+.5
                w0=edge(bx,by,cx,cy,px,py);w1=edge(cx,cy,ax,ay,px,py);w2=edge(ax,ay,bx,by,px,py)
                if positive:
                    if w0<0 or w1<0 or w2<0:continue
                elif w0>0 or w1>0 or w2>0:continue
                inv_depth=(w0*va[2]+w1*vb[2]+w2*vc[2])/area
                pos=base+x
                if inv_depth>depth[pos]:depth[pos]=inv_depth;pixels[pos]=colour
    return Image.frombytes('P',(width,height),bytes(pixels))

parser=argparse.ArgumentParser(description='Generate V9968 MegaROM assets.')
parser.add_argument('--mesh-obj',default=str(OUT/'octahedron.obj'),help='Wavefront OBJ used by the shared 128-frame MESH asset (default: assets/octahedron.obj)')
parser.add_argument('--mesh-radius',type=float,default=DEFAULT_MESH_RADIUS,help='Auto-normalized object radius before projection (default: 88)')
args=parser.parse_args()
if not 1.0<=args.mesh_radius<=120.0:raise ValueError('--mesh-radius must be between 1 and 120')
mesh_obj_path=resolve_mesh_obj(args.mesh_obj)
mesh_vertices_raw,mesh_faces,mesh_triangles=load_obj(mesh_obj_path)
mesh_vertices=normalize_obj(mesh_vertices_raw,args.mesh_radius)
mesh_obj_sha256=hashlib.sha256(mesh_obj_path.read_bytes()).hexdigest()

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

# The shared MESH asset is now generated from a Wavefront OBJ. The runtime data
# format is deliberately unchanged: Scene 1, Scene 3 and Scene 6 all continue
# to consume the same 128 fixed 4096-byte records with merged LMMV rectangles
# and a four-byte dirty bounding box at offset 4092.
mesh=bytearray();span_counts=[];rect_counts=[];bbox_areas=[];restore_areas=[];mesh_reference=[]
mesh_preview=None
MAX_MESH_RECTS=(4092-2)//11
for f in range(128):
    a=f*T/128;tilt=.48+.42*math.sin(a*2)
    im=rasterize_obj(mesh_vertices,mesh_faces,mesh_triangles,a,tilt,210+16*math.sin(a))
    runs=bytearray()
    for y in range(192):
        x=0
        while x<256:
            c=im.getpixel((x,y));end=x+1
            while end<256 and im.getpixel((end,y))==c:end+=1
            if c:runs+=bytes((x,0,y,0,end-x,0,1,0,c,0,0x80))
            x=end
    span_counts.append(len(runs)//11)
    original=runs;rectangles=[];active={}
    for y in range(192):
        current={}
        for i in range(0,len(original),11):
            packet=original[i:i+11]
            if packet[2]!=y:continue
            key=(packet[0],packet[4],packet[8])
            if key in active:
                idx=active[key];rectangles[idx][6]+=1
            else:
                idx=len(rectangles);rectangles.append(bytearray(packet))
            current[key]=idx
        active=current
    runs=b''.join(rectangles);count=len(rectangles);rect_counts.append(count)
    if count>MAX_MESH_RECTS:
        raise ValueError(
            f'Mesh OBJ is too detailed for the fixed 4096-byte MESH record: frame {f} needs '
            f'{count} merged rectangles, maximum is {MAX_MESH_RECTS}. Reduce polygon/detail count '
            'or lower --mesh-radius before building the ROM.')
    restored=Image.new('P',(256,192));pixels=restored.load()
    for i in range(0,len(runs),11):
        x,xh,y,yh,w,wh,h,hh,c,arg,cmd=runs[i:i+11]
        assert xh==yh==wh==hh==arg==0 and cmd==0x80
        assert x+w<=256 and y+h<=192 and w>0 and h>0
        for yy in range(y,y+h):
            for xx in range(x,x+w):
                assert pixels[xx,yy]==0, 'Overlapping final raster rectangles'
                pixels[xx,yy]=c
    assert restored.tobytes()==im.tobytes(), f'Mesh mismatch at frame {f}'
    bg=Image.open(OUT/'seabed-256.png').copy()
    bg.paste(im,(0,0),Image.frombytes('L',im.size,bytes(255 if c else 0 for c in im.tobytes())))
    mesh_reference.append({'frame':f,'raster_sha256':hashlib.sha256(packed(im)).hexdigest(),
                           'page2_sha256':hashlib.sha256(packed(bg)).hexdigest()})
    bbox=im.getbbox()
    if bbox is None:raise ValueError(f'Mesh OBJ produced an empty raster at frame {f}')
    x0,y0,x1,y1=bbox
    if not (0<x1-x0<256 and 0<y1-y0<=192):
        raise ValueError(f'Mesh OBJ does not fit the 256x192 render area at frame {f}: bbox={bbox}')
    bbox_areas.append((x1-x0)*(y1-y0))
    restore_areas.append((((x1+1)&~1)-(x0&~1))*(y1-y0))
    mesh+=(struct.pack('<H',count)+runs).ljust(4092,b'\0')+bytes((x0,y0,x1-x0,y1-y0))
    if f==16:
        pal=Image.open(OUT/'chamber-256.png').getpalette();im.putpalette(pal);mesh_preview=im.copy()
add('MESH',mesh,4096)

floor=bytearray();waves=bytearray();identity=bytearray()
water_counts=[];water_shifted=[]
def merge_water(row):
    runs=[]
    for i in range(0,len(row),4):
        sx,dx,w,sy=row[i:i+4]
        if runs and runs[-1][:3]==[sx,dx,w] and runs[-1][3]+runs[-1][4]==sy:
            runs[-1][4]+=2
        else:runs.append([sx,dx,w,sy,2])
    expanded=bytes(c for sx,dx,w,sy,h in runs for offset in range(0,h,2) for c in (sx,dx,w,sy+offset))
    assert expanded==row and sum(run[4] for run in runs)==192
    result=bytes([len(runs)])+bytes(c for run in runs for c in run)
    assert len(result)<=512
    return result,runs
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
    encoded,runs=merge_water(row)
    water_counts.append(len(runs));water_shifted.append(sum(bool(a or b) for a,b,_,_,_ in runs))
    waves+=encoded.ljust(512,b'\0')
add('FLOOR',floor,512);add('WATER',waves,512)
for y in range(0,192,2):identity+=bytes((0,0,0,y))
add('IDENTITY',merge_water(identity)[0])

# Small opaque HUD labels, uploaded below the background in VRAM page 3.
font = json.loads((OUT/'fonts.json').read_text(encoding='utf-8'))['msx8x8']
SCENES=7
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
import importlib.util
_spec=importlib.util.spec_from_file_location('shallow',P/'generate-shallow.py')
_shallow=importlib.util.module_from_spec(_spec);_spec.loader.exec_module(_shallow)
_shallow_floor,_shallow_atlas,_shallow_wave,_shallow_full,_shallow_delta=_shallow.make_assets(OUT)
add('SHALLOW',packed(_shallow_floor))
add('CAUSTICS',b''.join(_shallow_full[i*32768:(i+1)*32768] for i in range(0,128,8)))
layout['CAUSTICS'].update(stride=32768,frames=16,key_step=8,logical_frames=128,banks_per_frame=2)
add('CAUSTIC_DELTA',_shallow_delta,16384)
add('SHALLOW_WAVE',_shallow_wave,256)
_surface_pattern,_surface_attrs=_shallow.surface_assets()
add('SURFACE_PATTERN',_surface_pattern)
add('SURFACE_ATTRS',_surface_attrs,512)
add('CAUSTIC_JUMP2',_shallow.jump_deltas(_shallow_full,2))
add('CAUSTIC_JUMP3',_shallow.jump_deltas(_shallow_full,3))



# ASCII16-X uses 12 bank bits; bank_record carries 16-bit first-bank values.
MAPPER='ASCII16-X'
MAPPER_BANK_LIMIT=4096
ROM_BANKS=512
assert len(banks)<=ROM_BANKS,f'{len(banks)} banks do not fit the {ROM_BANKS}-bank ROM'
assert ROM_BANKS<=MAPPER_BANK_LIMIT,(
    f'{ROM_BANKS} banks exceed the {MAPPER_BANK_LIMIT}-bank limit of {MAPPER}; '
    'switch the launchers to -romtype ASCII16-X (bank_select already supports it)')
used=len(banks)*BANK
banks += [b'\xff'*BANK]*(ROM_BANKS-len(banks))
banks[-1]=banks[-1][:-16]+b'MCX2'+bytes(12)
# All geometry and capacity checks passed before publishing generated files.
mesh_preview.save(OUT/'mesh-source-preview.png')
(OUT/'mesh-reference.json').write_text(json.dumps(mesh_reference,indent=2)+'\n')
(OUT/'megarom-data.bin').write_bytes(b''.join(banks[1:]))
header=f'/* Generated by generate-megarom.py; {MAPPER} banked data, {ROM_BANKS} banks. */\n'
for name,entry in layout.items():
    header+=f'#define BANK_{name} {entry["bank"]}\n'
    # Frame counts travel with the layout so the runtime mask cannot drift
    # away from the number of records actually generated.
    if 'frames' in entry:header+=f'#define FRAMES_{name} {entry["frames"]}\n'
header+='#define MESH_BBOX_OFFSET 4092\n'
header+=f'#define MEGAROM_BYTES {ROM_BANKS*BANK}UL\n'
(OUT/'bank-layout.h').write_text(header,encoding='ascii')
layout['summary']={'rom_bytes':ROM_BANKS*BANK,'allocated_bytes':used,'mapper':MAPPER,'rom_banks':ROM_BANKS,
                   'mesh_obj':mesh_obj_path.name,'mesh_obj_sha256':mesh_obj_sha256,'mesh_radius':args.mesh_radius,
                   'mesh_vertices':len(mesh_vertices_raw),'mesh_faces':len(mesh_faces),'mesh_triangles':len(mesh_triangles),
                   'water_mean_runs':sum(water_counts)/256,'water_min_runs':min(water_counts),'water_max_runs':max(water_counts),
                   'water_mean_shifted_runs':sum(water_shifted)/256,'water_mean_commands':sum(a+2*b for a,b in zip(water_counts,water_shifted))/256,
                   'mesh_bbox_mean_area':sum(bbox_areas)/128,'mesh_restore_mean_area':sum(restore_areas)/128,
                   'mesh_mean_rectangles':sum(rect_counts)/128,'mesh_min_rectangles':min(rect_counts),'mesh_max_rectangles':max(rect_counts),
                   'mesh_max_spans':max(span_counts),'mesh_mean_spans':sum(span_counts)/128}
(OUT/'bank-layout.json').write_text(json.dumps(layout,indent=2)+'\n')
print(layout['summary'])






