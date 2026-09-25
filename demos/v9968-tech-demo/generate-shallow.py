"""Independent shallow-water assets. Python/Pillow; no imported artwork.

Base colours 0..3; OR 0/4/8/12 selects four illumination levels. The mask
uses two high index bits. This is indexed-colour lighting, not alpha blending.
"""
import math
import random
from PIL import Image

# Four material tones x four light levels. OR with 0/4/8/12 selects
# a pre-designed shade, not physical additive or alpha blending.
PALETTE = [(0,3,4),(1,5,6),(3,8,9),(5,11,12),
           (3,8,8),(5,11,11),(8,15,14),(11,19,17),
           (8,16,13),(12,21,17),(17,26,21),(23,29,25),
           (17,25,21),(22,29,25),(28,31,28),(31,31,30)]

def ground(x,y):
    """Inverse pinhole projection of a horizontal plane, fixed off-axis view.
    Focal length 180, height 160, principal point/horizon at (128,-84).
    The displayed window is below the horizon. Same map for floor/light.
    """
    d=y+84.0
    return (x-128.0)*160.0/d,28800.0/d


def water_warp(x,z,t,sin=math.sin):
    """One periodic field shared by bottom caustics and surface reflections.
    This maps positions to texture coordinates, so visible features must follow
    its INVERSE, not add the displacement with the opposite motion direction.
    Accepts numpy.sin for the existing vectorized caustic generator.
    """
    u=x+5*sin(z*math.tau/128-t)+2*sin(x*math.tau/128+z*math.tau/64+2*t)+2*sin(z*math.tau/32-2*t)
    v=z+3*sin(x*math.tau/128+t)+1.4*sin(x*math.tau/64-z*math.tau/128-2*t)+1.5*sin(x*math.tau/32+t)
    return u,v


def follow_water(u,v,t):
    """Invert the shared flow with Newton iterations; Python build-time only."""
    x,z=u,v
    for unused in range(12):
        a,b=water_warp(x,z,t);du=a-u;dv=b-v
        if max(abs(du),abs(dv))<1e-8:break
        ax,bx=water_warp(x+.001,z,t);az,bz=water_warp(x,z+.001,t)
        j00=(ax-a)/.001;j10=(bx-b)/.001;j01=(az-a)/.001;j11=(bz-b)/.001
        det=j00*j11-j01*j10
        assert abs(det)>.08
        x-=(j11*du-j01*dv)/det;z-=(-j10*du+j00*dv)/det
    a,b=water_warp(x,z,t)
    assert max(abs(a-u),abs(b-v))<1e-5
    return x,z


def make_assets(out):
    rng=random.Random(9968)
    # Local neighbouring cells avoid an O(all stones) search at every sample.
    stones={(i,j):(i*16+rng.uniform(3,13),j*14+rng.uniform(3,11),rng.uniform(-.5,.5))
            for j in range(4,29) for i in range(-19,20)}
    floor=Image.new('P',(256,192))
    for y in range(192):
        for x in range(256):
            samples=[]
            for oy in (.25,.75):
                for ox in (.25,.75):
                    xx,zz=ground(x+ox,y+oy);i=math.floor(xx/16);j=math.floor(zz/14)
                    near=sorted(((xx-a)**2+(zz-b)**2,c,a,b)
                        for ii in range(i-1,i+2) for jj in range(j-1,j+2)
                        for a,b,c in [stones[ii,jj]])[:2]
                    d,c,a,b=near[0];gap=math.sqrt(near[1][0])-math.sqrt(d)
                    light=4.8+c+.06*(a-xx+b-zz)+.26*math.sin(xx*.61+zz*.24)+.18*math.cos(xx*.27-zz*.49)
                    if .65<gap<2:light+=.65 if a+b>xx+zz else -.55
                    samples.append(3 if gap<.65 else max(3,min(7,light)))
            # Distant floor is darker; caustics and surface reflections have their
            # own strengths. Four stone tones reserve two bits for illumination.
            tone=(sum(samples)/4-3)*.72 + .55*(y/191)-.3
            floor.putpixel((x,y),max(0,min(3,round(tone))))
    floor.putpalette([v*255//31 for p in PALETTE for v in p]+[0]*(768-48))
    floor.save(out/'shallow-floor.png')
    points=[((x+.5)*256/11+rng.uniform(-6,6),(y+.5)*128/6+rng.uniform(-5,5))
            for y in range(6) for x in range(11)]
    # Project the whole water surface, with 2x2 subpixel coverage. No screen-space
    # tile repetition: periodicity exists only in world coordinates.
    gx=[];gz=[]
    for y in range(320):
        for x in range(512):
            a,b=ground((x+.5)/2,20+(y+.5)/2);gx.append(a);gz.append(b)
    import numpy as np  # Build-time only, no runtime dependency.
    gx=np.array(gx);gz=np.array(gz)
    atlas=Image.new('P',(256,160*128));raw=[]
    for phase in range(128):
        t=phase*math.tau/128
        u,v=water_warp(gx,gz,t,np.sin)
        first=np.full(u.shape,np.inf);second=first.copy()
        ax=np.zeros(u.shape);ay=ax.copy();bx=ax.copy();by=ax.copy()
        for a,b in points:
            dx=(u-a+128)%256-128;dy=(v-b+64)%128-64;d=dx*dx+dy*dy
            take=d<first;runner=(~take)&(d<second)
            second=np.where(take,first,np.where(runner,d,second))
            bx=np.where(take,ax,np.where(runner,dx,bx));by=np.where(take,ay,np.where(runner,dy,by))
            ax=np.where(take,dx,ax);ay=np.where(take,dy,ay);first=np.minimum(first,d)
        # Distance to the nearest bisector in deformed WORLD coordinates.
        # Its projection naturally widens toward the foreground; unlike label
        # edges in screen pixels it does not enforce a uniform 1-pixel width.
        ridge=(second-first)/(2*np.maximum(.001,np.hypot(ax-bx,ay-by)))
        width=.62+.18*np.sin(u*.09+v*.06-t)+.12*np.sin(v*.13+2*t)
        core=np.exp(-.5*(ridge/width)**2)
        halo=.30*np.exp(-.5*(ridge/(width*2.4))**2)
        depth=np.clip((28800/gz-104)/160,0,1)
        strength=.12+.88*(depth*depth*(3-2*depth))
        light=np.clip((core+halo)*strength,0,1).reshape(320,512)
        light=light.reshape(160,2,256,2).mean(axis=(1,3))
        levels=np.where(light>.76,3,np.where(light>.34,2,np.where(light>.095,1,0))).astype('uint8')
        frame=Image.fromarray(levels*4).convert('P')
        atlas.paste(frame,(0,phase*160));v=frame.tobytes()
        raw.append(bytes((v[i]<<4)|v[i+1] for i in range(0,len(v),2)))
    atlas.putpalette(floor.getpalette());atlas.save(out/'shallow-caustics.png')
    # Consecutive-frame deltas, including the seamless 127->0 wrap. Merge
    # nearby changes to reduce VRAM address setup, while preserving all bytes.
    import struct,json
    deltas=bytearray();stats=[]
    for phase in range(128):
        prev=raw[(phase-1)&127];cur=raw[phase];total=0;nr=0
        replay=bytearray(prev)
        # Separate R14=4 and R14=5 records, no write crosses a 16 KiB boundary.
        for base,end in [(0,16384),(16384,20480)]:
            changed=[i for i in range(base,end) if prev[i]!=cur[i]];runs=[];k=0
            while k<len(changed):
                start=last=changed[k];k+=1
                while k<len(changed) and changed[k]-last<=7 and changed[k]-start<255:
                    last=changed[k];k+=1
                runs.append((start,cur[start:last+1]))
            record=bytearray(struct.pack('<H',len(runs)))
            for start,chunk in runs:
                record+=struct.pack('<HB',start-base,len(chunk))+chunk
                replay[start:start+len(chunk)]=chunk
            assert len(record)<=8192
            total+=len(record);nr+=len(runs);deltas+=record.ljust(8192,b'\0')
        assert replay==cur
        stats.append(dict(bytes=total,runs=nr))
    (out/'shallow-delta-stats.json').write_text(json.dumps(stats,indent=2))
    full=b''.join(frame.ljust(32768,b'\0') for frame in raw)
    waves=bytearray();band_counts=[]
    for phase in range(128):
        rows=[]
        for y in range(20,180):
            _,z=ground(128,y);scale=(y+84)/264
            dx=2*round(scale*(math.sin(z*.075+phase*math.tau/128)+.5*math.sin(z*.13-phase*math.tau/64)))
            dy=round(2*scale*scale*math.sin(z*.11-phase*math.tau/64))
            rows.append((dx,dy))
        runs=[];i=0
        while i<160:
            j=i+1
            while j<160 and rows[j]==rows[i]:j+=1
            dx,dy=rows[i];y=20+i;h=j-i
            sx,sy=8+dx,y+dy
            assert 0<=sx and sx+240<=256 and 0<=sy and sy+h<=192
            runs.append((sx,sy,y,h));i=j
        record=bytes([len(runs)])+bytes(v for run in runs for v in run)
        assert len(record)<=256
        band_counts.append(len(runs));waves+=record.ljust(256,b'\0')
    (out/'shallow-wave-stats.json').write_text(json.dumps(band_counts))
    assert len(waves)==32768
    return floor,atlas,bytes(waves),full,bytes(deltas)


def surface_assets():
    """Precomputed directional-wave slopes and fixed-view specular response.
    Twenty staggered glints, ten soft shoulders and 8x4 ribbons.
    All layers follow the caustic warp; opacity and feathered patterns fade.
    RGB5 transparency is quantized, not continuous alpha or additive blending.
    Integer temporal harmonics give an exact analytic 128-phase loop.
    This is a wave/lighting approximation, not a fluid-dynamics simulation.
    """
    patterns=bytearray(4096)
    for tile in range(16):
        wave=tile&3;envelope=tile>>2
        for y in range(16):
            for x in range(16):
                if tile>=12:
                    # Low-priority slanted optical-glare approximation; core wins where nonzero.
                    dx=(x-7.5)/6.7;dy=(y-(12-9*x/15))/3.5
                    value=15*math.exp(-.65*(dx*dx+dy*dy))
                else:
                    angle=(x/16+wave)*math.pi/2
                    center=7.5+3.0*math.sin(angle);dy=y-center
                    taper=1.0
                    if envelope==1:taper=math.sin(x/15*math.pi/2)**.75
                    elif envelope==2:taper=math.cos(x/15*math.pi/2)**.75
                    value=15*taper*(.86*math.exp(-.5*(dy/.9)**2)+.12*math.exp(-.5*(dy/1.7)**2))
                c=max(0,min(15,round(value)))
                patterns[y*128+tile*8+x//2]|=c<<(4 if x%2==0 else 0)
    # Individual short, skewed glints. Three fade profiles and four bends.
    # No aligned repeated full-width bars; shoulders remain separate sprites.
    for tile in range(12):
        level=tile//4;bend=tile&3
        for y in range(16):
            for x in range(16):
                q=x/15
                center=12-9*q+[.6,-.9,1.2,-.4][bend]*math.sin(q*math.tau)
                taper=math.sin(q*math.pi)**.55*(.83+.17*math.sin(q*math.tau+[0,1.1,2.4,3.7][bend]))
                sigma=[1.35,.95,.60][level]
                value=taper*math.exp(-.5*(max(0,abs(y-center)-.6)/sigma)**2)
                c=0 if value<[.16,.25,.40][level] else min(15,round(8+10*value))
                patterns[2048+y*128+tile*8+x//2]|=c<<(4 if x%2==0 else 0)
    def field(x,z,t):
        # Normal-like slopes are derived from the SAME caustic deformation.
        # This is a coupled artistic approximation, not ray-traced caustics.
        def height(a,b):
            u,v=water_warp(a,b,t)
            return .18*(u-a)+.24*(v-b)
        h=height(x,z)
        dx=(height(x+.05,z)-height(x-.05,z))/.1
        dz=(height(x,z+.05)-height(x,z-.05))/.1
        norm=math.sqrt(1+dx*dx+dz*dz)
        nh=max(0,(1-.04*dx-.09*dz)/(norm*math.sqrt(1+.04**2+.09**2)))
        return h,dx,dz,nh**96
    frames=bytearray()
    for phase in range(128):
        t=phase*math.tau/128;cores=[];ribbons=[];spans=[]
        for row,y0 in enumerate([27,43,61,80,100,121,142,160]):
            depth=(y0-20)/160;scale=(y0+84)/264
            # Sample the same world-space wave at the ribbon centre and sides.
            wx=(row%3-1)*24;_,z=ground(128,y0)
            fx,fz=follow_water(wx,z,t)
            h,dx,dz,shine=field(fx,fz,t)
            cx=128+fx*180/fz
            width=(13+12*depth)*( .88+.24*shine)
            height=5+5*depth+3*shine
            top=28800/fz-84+1.2*scale*h
            # Four true opacity levels; geometry changes soften threshold steps.
            energy=shine*(.30+.70*depth)
            tp=3 if energy<.30 else (2 if energy<.58 else 1)
            bounds=[round(cx+(i-2)*width) for i in range(5)]
            for segment in range(4):
                envelope=1 if segment==0 else (2 if segment==3 else 0)
                pattern=envelope*4+((segment+row)&3)
                sx=bounds[segment];sw=bounds[segment+1]-sx
                # Shared endpoints keep neighbouring segments contiguous in X.
                yy=round(top);hh=round(height)
                ribbons.append(bytes([yy,0,hh,1|(tp<<6),sx,32,sw,0xa0|pattern]))
        sparkles=[];halos=[]
        for row,y0 in enumerate([48,63,77,89,100,110,121,134,147,158]):
            # Two staggered patches per band; a broad-to-narrow specular lobe
            # modulates geometry and alpha, without a per-frame random flicker.
            samples=[]
            for side in range(2):
                x0=139-.12*(y0-48)+[-4,3][side]+[-2,1,3,-1,0,2,-3,1,0,-1][row]
                y1=y0+([-2,3][side] if row%2 else [2,-3][side])
                wx,wz=ground(x0,y1);fx,fz=follow_water(wx,wz,t)
                h,dx,dz,shine=field(fx,fz,t)
                depth=(y0-20)/160
                envelope=math.exp(-.5*((y0-105)/28)**2)
                energy=min(1,1.90*shine**1.20*envelope)
                ww=max(3,round((5+29*energy)*(.60+.45*depth)))
                hh=max(2,round((3+10*energy)*(.65+.35*depth)))
                cx=128+fx*180/fz;cy=28800/fz-84+1.2*(y0+84)/264*h
                tp=3 if energy<.20 else (2 if energy<.36 else (1 if energy<.57 else 0))
                profile=2 if energy<.20 else (1 if energy<.38 else 0)
                pattern=12 if energy<.07 else profile*4+(row+side)%4
                sparkles.append(bytes([round(cy-hh*.5),0,hh,1|(tp<<6),round(cx-ww*.5),32,ww,0xb0+pattern]))
                samples.append((cx,cy,energy))
            cx=sum(a for a,b,c in samples)/2;cy=sum(b for a,b,c in samples)/2
            energy=sum(c for a,b,c in samples)/2
            hw=round(18+27*energy);hh=round(6+6*energy)
            htp=3 if energy<.35 else (2 if energy<.65 else 1)
            hy=max(20,min(179-hh,round(cy-hh*.5)))
            # A blank pattern removes inactive halos instead of leaving bubbles.
            px=0xbc if energy<.14 else 0xac
            halos.append(bytes([hy,0,hh,1|(htp<<6),round(cx-hw*.5),32,hw,px]))
        attrs=b''.join(sparkles+halos+ribbons)
        for i in range(62):
            y,sz,hh,pal,x,pts,ww,px=attrs[i*8:i*8+8]
            assert 8<=x and x+ww<=248 and 20<=y and y+hh+1<=180
            spans.append((y+1,y+1+hh))
        assert max(sum(a<=y<b for a,b in spans) for y in range(192))<=16
        attrs+=bytes([216,0,1,0,0,0,1,0])
        assert len(attrs)==504
        frames+=attrs.ljust(512,b'\0')
    return bytes(patterns),bytes(frames)


def jump_deltas(full,distance):
    """Direct two/three-step update: two variable records in one 16 KiB bank.
    A little-endian offset locates the second (R14=5) record. No ROM/VRAM
    boundary is crossed. Keys every eight phases plus deltas cover all shapes.
    """
    import struct
    raw=[full[i*32768:i*32768+20480] for i in range(128)]
    result=bytearray()
    for phase in range(128):
        prev=raw[(phase-distance)&127];cur=raw[phase];replay=bytearray(prev);sections=[]
        for base,end in [(0,16384),(16384,20480)]:
            changed=[i for i in range(base,end) if prev[i]!=cur[i]];runs=[];k=0
            while k<len(changed):
                start=last=changed[k];k+=1
                while k<len(changed) and changed[k]-last<=7 and changed[k]-start<255:
                    last=changed[k];k+=1
                runs.append((start,cur[start:last+1]))
            record=bytearray(struct.pack('<H',len(runs)))
            for start,chunk in runs:
                record+=struct.pack('<HB',start-base,len(chunk))+chunk
                replay[start:start+len(chunk)]=chunk
            sections.append(record)
        record=struct.pack('<H',2+len(sections[0]))+sections[0]+sections[1]
        assert len(record)<=16384 and replay==cur
        result+=record.ljust(16384,b'\0')
    return bytes(result)
