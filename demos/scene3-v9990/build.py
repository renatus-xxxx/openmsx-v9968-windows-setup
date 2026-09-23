"""Isolated Scene 3 builds. Never writes into the existing demo directory."""
import argparse,hashlib,json,os,re,shutil,subprocess,sys
from pathlib import Path
p=argparse.ArgumentParser();p.add_argument('--z88dk',required=True);p.add_argument('--variant',choices=['a','b','c','reference','all'],default='all');p.add_argument('--regenerate-assets',action='store_true');a=p.parse_args()
root=Path(__file__).resolve().parent;shared=root.parent/'v9968-tech-demo';out=root/'build';out.mkdir(exist_ok=True)
z=Path(a.z88dk).resolve();exe=z/'bin'/('zcc.exe' if os.name=='nt' else 'zcc')
env=os.environ.copy();env['PATH']=str(z/'bin')+os.pathsep+env.get('PATH','');env['ZCCCFG']=str(z/'lib/config');env['PYTHONUTF8']='1'
asset_source=shared
if a.regenerate_assets:
    asset_source=out/'asset-source'
    shutil.copytree(shared,asset_source,dirs_exist_ok=True,ignore=shutil.ignore_patterns('build','build-c','test-output','notes','__pycache__'))
    for script in ['generate-fonts.py','generate-megarom.py','verify-water-model.py']:
        subprocess.run([sys.executable,str(asset_source/script)],check=True,env=env)
    payload=(asset_source/'assets/megarom-data.bin').read_bytes()
else:
    # Explicitly reuse the published payload, not an untracked generated cache.
    payload=(shared/'V9968-TECH-DEMO.rom').read_bytes()[16384:]
assert len(payload)==1032192
records={}
original_payload=payload
for variant in (['a','b','c','reference'] if a.variant=='all' else [a.variant]):
    payload=original_payload
    if variant=='c':
        import importlib.util
        spec=importlib.util.spec_from_file_location('c_packets',root/'generate-c-packets.py');mod=importlib.util.module_from_spec(spec);spec.loader.exec_module(mod)
        payload,packet_info=mod.generate(bytes(16384)+original_payload)
        (out/'c-packets.json').write_text(json.dumps(packet_info,indent=2)+'\n')
    dest=out/variant;dest.mkdir(exist_ok=True)
    for f in ['v9968.h','platform.h','platform.c','mapper.h','mapper.c','music.c','runtime-math.asm']:
        shutil.copyfile(shared/f,dest/f)
    shutil.copyfile(asset_source/'assets/bank-layout.h',dest/'bank-layout.h')
    for f in ['main.c','v9990.c','v9990.h']:shutil.copyfile(root/f,dest/f)
    if variant=='reference':
        text=(shared/'v9968.c').read_text(encoding='utf-8-sig')+'\nvoid video_wait(void){wait_cmd();}\n'
        (dest/'v9968.c').write_text(text,encoding='utf8')
    name={'a':'SCENE3-V9990-A','b':'SCENE3-V9990-B','c':'SCENE3-V9990-C','reference':'SCENE3-V9968-REFERENCE'}[variant]
    defines=[] if variant=='reference' else ['-DV9990_TARGET']+(['-DV9990_OPTIMIZED'] if variant in ['b','c'] else [])
    if variant=='c':defines+=['-DV9990_PACKETS']
    cmd=[str(exe),'+msx','-subtype=rom','-compiler=sdcc','-SO3','--max-allocs-per-node20000',*defines,'-create-app','main.c','v9968.c' if variant=='reference' else 'v9990.c','music.c','runtime-math.asm','mapper.c','platform.c','-o',name,'-m']
    subprocess.run(cmd,cwd=dest,env=env,check=True)
    fixed=(dest/(name+'.rom')).read_bytes();assert len(fixed)<=16384
    m=(dest/(name+'.map')).read_text();bss=int(re.search(r'__BSS_END_tail\s*=\s*\$([0-9A-Fa-f]+)',m)[1],16);assert bss<=0xcf00
    rom=fixed.ljust(16384,b'\0')+payload;(dest/(name+'.rom')).write_bytes(rom)
    shutil.copyfile(dest/(name+'.rom'),root/(name+'.rom'))
    records[variant]={'file':name+'.rom','size':len(rom),'sha256':hashlib.sha256(rom).hexdigest(),'payload_sha256':hashlib.sha256(payload).hexdigest(),'bss_end':hex(bss),'fixed_bytes':len(fixed)}
    print(variant,records[variant])
info=root/'roms.json';old=json.loads(info.read_text()) if info.exists() else {};old.update(records);info.write_text(json.dumps(old,indent=2)+'\n')
