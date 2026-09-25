from pathlib import Path
import json,argparse
import numpy as np
from PIL import Image
p=Path(__file__).resolve().parent
parser=argparse.ArgumentParser()
parser.add_argument('--captures',type=Path,required=True)
captures=parser.parse_args().captures
layout=json.loads((p/'assets/bank-layout.json').read_text())
payload=(p/'assets/megarom-data.bin').read_bytes()
offset=(layout['SHALLOW_WAVE']['bank']-1)*16384
waves=payload[offset:offset+32768]
floor=np.array(Image.open(p/'assets/shallow-floor.png'))
atlas=np.array(Image.open(p/'assets/shallow-caustics.png'))
cpu='see emulator telemetry'
phases=set();masks=set();errors=[]
for f in sorted(captures.glob('frame-*.bin')):
    _,tick,page=f.stem.split('-');tick=int(tick);page=int(page)
    b=np.frombuffer(f.read_bytes(),dtype=np.uint8).reshape(1024,128)
    v=np.empty((1024,256),dtype=np.uint8);v[:,::2]=b>>4;v[:,1::2]=b&15
    phase=(tick>>1)&127;m=(tick>>2)&127;phases.add(phase);masks.add(m)
    # Verify the reconstructed live cache against independently generated ROM data.
    frame=atlas[m*160:(m+1)*160]
    assert np.array_equal(v[512:672],frame),f'mask upload mismatch: {f.name}'
    expected=floor.copy()
    record=waves[phase*256:(phase+1)*256]
    for i in range(record[0]):
        sx,sy,y,h=map(int,record[1+i*4:5+i*4])
        expected[y:y+h,8:248]=floor[sy:sy+h,sx:sx+240]
    expected[20:180,8:248]|=frame[:,8:248]
    expected[16,12:245]=5;expected[176,12:245]=5
    for i in range(7):expected[182:184,101+i*10:107+i*10]=15 if i==6 else 4
    header=v[1014:1023,:186];region=expected[5:14,8:194];region[header!=0]=header[header!=0]
    count=int(np.count_nonzero(expected!=v[page*256:page*256+192]))
    if count:errors.append(dict(file=f.name,mismatches=count))
sprite_phases=set()
pat_offset=(layout['SURFACE_PATTERN']['bank']-1)*16384
attr_offset=(layout['SURFACE_ATTRS']['bank']-1)*16384
for f in captures.glob('sprite-*.bin'):
    tick=int(f.stem.split('-')[1]);phase=(tick>>2)&127;b=f.read_bytes()
    assert len(b)==4600+32
    assert b[:504]==payload[attr_offset+phase*512:attr_offset+phase*512+504],f.name
    assert b[504:4600]==payload[pat_offset:pat_offset+4096],f.name
    assert b[4600+20]&8 and not b[4600+8]&2,f.name
    sprite_phases.add(phase)
assert len(sprite_phases)==128
result=dict(sprite_phases=len(sprite_phases),cpu=cpu,wave_phases=len(phases),mask_frames=len(masks),frames=len(list(captures.glob('frame-*.bin'))),mismatches=errors,full_cross_product=False)
(captures/'pixel-result.json').write_text(json.dumps(result,indent=2))
print(result)
assert len(phases)==128 and len(masks)==128 and not errors
