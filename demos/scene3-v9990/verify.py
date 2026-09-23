"""Independent raster/water oracle; never reads pixels from emulator as reference."""
from pathlib import Path
import argparse,json,hashlib,math
from PIL import Image
p=argparse.ArgumentParser();p.add_argument('directory');p.add_argument('--variant',required=True);p.add_argument('--fixture',action='store_true');a=p.parse_args()
root=Path(__file__).resolve().parent;shared=root.parent/'v9968-tech-demo';layout=json.loads((shared/'assets/bank-layout.json').read_text());rom=(shared/'V9968-TECH-DEMO.rom').read_bytes()
def block(name,frame=0):
 e=layout[name];pos=e['bank']*16384+frame*e.get('stride',0);return rom[pos:pos+e['bytes'] if not frame else pos+e['stride']]
def unpack(data):return bytearray(c for b in data for c in (b>>4,b&15))
bg=unpack(block('SEABED')[:24576]);headers=unpack(block('HUDLINE')[:5022]);colors=[0,0,1,1,2,3,2,3,5,3,5,7,4,7,10,6,10,13,9,13,16,13,18,21,5,6,7,9,10,11,14,15,16,20,21,22,25,27,28,31,31,30,9,27,31,23,17,8]
if a.fixture:
 bg=bytearray((1+((x//7+y//5)%15)) for y in range(192) for x in range(256))
def mesh(pose):
 dst=bg.copy();p=block('MESH',pose);count=int.from_bytes(p[:2],'little')
 for i in range(count):
  q=p[2+11*i:13+11*i];x,y=q[0],q[2];w=int.from_bytes(q[4:6],'little');h=int.from_bytes(q[6:8],'little');c=q[8]
  assert 0<=x<256 and 0<=y<192 and w>0 and h>0 and x+w<=256 and y+h<=192, 'mesh rectangle outside comparison area'
  for yy in range(y,y+h):dst[yy*256+x:yy*256+x+w]=bytes([c])*w
 return dst
def water(src,phase):
 dst=bytearray(49152)
 for y in range(0,192,2):
  bottom=190-y;sy=round(190-max(0,min(190,bottom+4*math.sin((bottom+1)*math.tau/64+phase*math.tau/256))))
  shift=2*round(math.sin((y+1)*math.tau/96-phase*math.tau/256))
  for dy in range(2):
   for x in range(256):dst[(y+dy)*256+x]=src[(sy+dy)*256+max(0,min(255,x-shift))]
 return dst
def hud(dst):
 for y in range(9):
  for x in range(186):
   c=headers[(18+y)*186+x]
   if c:dst[(5+y)*256+8+x]=c
 return dst
out=Path(a.directory);rows=(out/'frames.tsv').read_text().splitlines();assert len(rows)==385
results=[]
for row in rows:
 i,pose,phase,page=map(int,row.split());raw=(out/f'vram-{i:03}.bin').read_bytes()
 if not a.variant.startswith('reference'):
  decoded=bytearray(131072);decoded[::2]=raw[:65536];decoded[1::2]=raw[65536:];raw=decoded
 work=unpack(raw[65536:90112]);source=mesh(pose);expected=hud(water(source,phase));actual=unpack(raw[page*32768:page*32768+24576])
 assert len(raw)==131072
 if not a.variant.startswith('reference'):assert not any(raw[page*32768+24576:page*32768+27136]), 'unused display rows changed'
 mw=sum(x!=y for x,y in zip(work,source));md=sum(x!=y for x,y in zip(actual,expected))
 results.append({'sample':i,'pose':pose,'phase':phase,'page':page,'work_mismatch':mw,'display_mismatch':md})
 if i in [0,37,165]:
  for name,pixels in [('actual',actual),('expected',expected)]:
   im=Image.frombytes('P',(256,192),bytes(pixels));im.putpalette([round(c*255/31) for c in colors]+[0]*(768-48));im.convert('RGB').resize((768,576),Image.Resampling.NEAREST).save(out/f'{name}-{i}.png')
 if mw or md:print('MISMATCH',results[-1]);break
passed=len(results)==385 and all(not x['work_mismatch'] and not x['display_mismatch'] for x in results)
(out/'verification.json').write_text(json.dumps({'pass':passed,'samples':results},indent=2));print('PASS' if passed else 'FAIL',len(results));raise SystemExit(0 if passed else 1)
