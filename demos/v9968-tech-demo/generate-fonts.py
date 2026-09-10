"""Convert upstream row bitmaps to shared HUD data; no resampling."""
from pathlib import Path
import json, re
P=Path(__file__).resolve().parent
CHARS=" 0123456789CDEHMNOSTV"
def load_fonts():
    src=P/'third-party/fonts'
    asm=(src/'msx8x8-ascii.asm').read_text(encoding='utf-8')
    msx={}
    for section,base in [('PGT1',32),('PGT2',65)]:
        part=asm.split(section+':',1)[1].split('PGT2:',1)[0]
        rows=re.findall(r'^\s*DB\s+([^;]+)',part,re.M)
        for n,row in enumerate(rows):
            values=[int(v,16) for v in re.findall(r'#([0-9A-Fa-f]{2})',row)]
            assert len(values)==8
            msx[chr(base+n)]=values
    return {'msx8x8':{c:msx[c] for c in CHARS}}
if __name__=='__main__':
    fonts=load_fonts()
    (P/'assets/fonts.json').write_text(json.dumps(fonts,indent=2)+'\n',encoding='utf-8')
