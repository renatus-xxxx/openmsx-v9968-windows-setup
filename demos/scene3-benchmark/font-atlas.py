"""Pack the existing MSX 8x8 font into the benchmark's LABELS bank."""
from pathlib import Path
import re,sys,json
p=Path(__file__).resolve().parent
shared=p.parent/'v9968-tech-demo'
s=(shared/'third-party/fonts/msx8x8-ascii.asm').read_text(encoding='utf-8')
glyphs={}
for section,base in [('PGT1',32),('PGT2',65)]:
    part=s.split(section+':',1)[1].split('PGT2:',1)[0]
    for n,row in enumerate(re.findall(r'^\s*DB\s+([^;]+)',part,re.M)):
        glyphs[base+n]=[int(x,16) for x in re.findall(r'#([0-9A-Fa-f]{2})',row)]
atlas=bytearray(3072)
for c in range(32,128):
    for y,bits in enumerate(glyphs.get(c,[0]*8)):
        for x in range(8):
            if bits&(128>>x):
                px=((c-32)%32)*8+x;py=((c-32)//32)*8+y
                atlas[py*128+px//2]|=14<<(0 if px&1 else 4)
rom=Path(sys.argv[1]);data=bytearray(rom.read_bytes())
bank=json.loads((shared/'assets/bank-layout.json').read_text())['LABELS']['bank']
data[bank*16384:bank*16384+len(atlas)]=atlas
rom.write_bytes(data)
