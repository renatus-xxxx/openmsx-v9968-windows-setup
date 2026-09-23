"""Build a separate V9968 ROM. Shared source and baseline ROMs stay unchanged."""
import argparse,hashlib,importlib.util,json,os,re,shutil,subprocess
from pathlib import Path

p=argparse.ArgumentParser()
p.add_argument('--z88dk',required=True)
p.add_argument('--c-stream',action='store_true',help='Diagnostic C-language water stream; separate ROM/map')
a=p.parse_args()
root=Path(__file__).resolve().parent;shared=root.parent/'v9968-tech-demo'
variant='reference-packets-c' if a.c_stream else 'reference-packets'
name='SCENE3-V9968-PACKETS'+('-C' if a.c_stream else '')
dest=root/'build'/variant;dest.mkdir(parents=True,exist_ok=True)
spec=importlib.util.spec_from_file_location('packets',root/'generate-v9968-packets.py')
mod=importlib.util.module_from_spec(spec);spec.loader.exec_module(mod)
bank_layout=json.loads((shared/'assets/bank-layout.json').read_text())
assert bank_layout['WATER']['bank']==46 and bank_layout['WATER']['stride']==512 and bank_layout['WATER']['frames']==256, 'Water layout changed; review generator'
assert bank_layout['IDENTITY']['bank']==54 and bank_layout['IDENTITY']['bytes']<=512, 'Identity layout changed'
assert all(e['bank']*16384+e['bytes']<=1048576 for e in bank_layout.values() if isinstance(e,dict) and 'bank' in e), 'Shared assets overlap packet banks'
assert all(e['bank']!=54 for k,e in bank_layout.items() if k!='IDENTITY' and isinstance(e,dict) and 'bank' in e), 'Identity bank is shared'
source=(shared/'V9968-TECH-DEMO.rom').read_bytes();payload,layout=mod.generate(source)
for f in ['v9968.h','platform.h','platform.c','mapper.h','mapper.c','music.c','runtime-math.asm']:
    shutil.copyfile(shared/f,dest/f)
shutil.copyfile(shared/'assets/bank-layout.h',dest/'bank-layout.h')
for f in ['main.c','v9968-water-packets.inc']:shutil.copyfile(root/f,dest/f)
text=(shared/'v9968.c').read_text(encoding='utf-8-sig')
start=text.index('/* Source page 2 is immutable during all bands: no cumulative feedback. */')
end=text.index('#ifdef SCENE3_BENCHMARK',start)
assert text[start:end].count('void water_draw(')==2, 'Shared water section changed; review integration'
text=text[:start]+'#include "v9968-water-packets.inc"\n\n'+text[end:]
text+='\nvoid video_wait(void){wait_cmd();}\n'
(dest/'v9968.c').write_text(text,encoding='utf-8')
z=Path(a.z88dk).resolve();exe=z/'bin'/('zcc.exe' if os.name=='nt' else 'zcc')
env=os.environ.copy();env['PATH']=str(z/'bin')+os.pathsep+env.get('PATH','');env['ZCCCFG']=str(z/'lib/config')
defines=['-DV9968_WATER_PACKETS']+(['-DV9968_WATER_PACKETS_C'] if a.c_stream else [])
cmd=[str(exe),'+msx','-subtype=rom','-compiler=sdcc','-SO3','--max-allocs-per-node20000',*defines,
     '-create-app','main.c','v9968.c','music.c','runtime-math.asm','mapper.c','platform.c','-o',name,'-m']
subprocess.run(cmd,cwd=dest,env=env,check=True)
fixed=(dest/(name+'.rom')).read_bytes();assert len(fixed)<=16384
mapping=(dest/(name+'.map')).read_text();bss=int(re.search(r'__BSS_END_tail\s*=\s*\$([0-9A-Fa-f]+)',mapping)[1],16);assert bss<=0xcf00
rom=fixed.ljust(16384,b'\0')+payload;assert len(rom)==2097152
(dest/(name+'.rom')).write_bytes(rom);shutil.copyfile(dest/(name+'.rom'),root/(name+'.rom'))
info={'file':name+'.rom','size':len(rom),'sha256':hashlib.sha256(rom).hexdigest(),
      'payload_sha256':hashlib.sha256(payload).hexdigest(),'bss_end':hex(bss),'fixed_bytes':len(fixed)}
meta=root/'roms.json';records=json.loads(meta.read_text());records[variant]=info;meta.write_text(json.dumps(records,indent=2)+'\n')
(dest/'packet-layout.json').write_text(json.dumps(layout,indent=2)+'\n')
(dest/'build-inputs.json').write_text(json.dumps({'shared_rom_sha256':hashlib.sha256(source).hexdigest(),
    'files':{f.name:hashlib.sha256(f.read_bytes()).hexdigest() for f in dest.iterdir() if f.suffix in ['.c','.h','.inc','.asm']},
    'zcc_sha256':hashlib.sha256(exe.read_bytes()).hexdigest()},indent=2)+'\n')
print(json.dumps(info,indent=2))
