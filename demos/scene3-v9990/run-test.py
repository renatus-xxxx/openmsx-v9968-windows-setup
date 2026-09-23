"""Private, isolated emulator session. No settings or BIOS published."""
import argparse,json,os,re,shutil,subprocess,time,hashlib
from pathlib import Path
p=argparse.ArgumentParser();p.add_argument('--runtime',required=True);p.add_argument('--variant',default='a');p.add_argument('--script',required=True);p.add_argument('--output',required=True);p.add_argument('--display',action='store_true');p.add_argument('--timeout',type=int,default=480);p.add_argument('--without-target',action='store_true');p.add_argument('--fault',type=int,choices=[1,3],default=1);a=p.parse_args();assert a.timeout>0
root=Path(__file__).resolve().parent;runtime=Path(a.runtime).resolve();out=Path(a.output).resolve();out.mkdir(parents=True,exist_ok=False)
cfg=json.loads((runtime/'config.json').read_text(encoding='utf-8-sig'));assert hashlib.sha256((runtime/'emulator/openmsx.exe').read_bytes()).hexdigest().lower()==cfg['forkSha256'].lower();env=os.environ.copy();env.update(OPENMSX_HOME=str(out/'user'),OPENMSX_USER_DATA=str(out/'user/share'),OPENMSX_SYSTEM_DATA=str(runtime/'emulator/share'))
if cfg['mode']=='fsa1gt':
    bios=out/'user/share/systemroms';bios.mkdir(parents=True)
    for f in (runtime/'bios').glob('*.rom'):shutil.copyfile(f,bios/f.name)
name={'a':'SCENE3-V9990-A','b':'SCENE3-V9990-B','c':'SCENE3-V9990-C','reference':'SCENE3-V9968-REFERENCE','reference-packets':'SCENE3-V9968-PACKETS','reference-packets-c':'SCENE3-V9968-PACKETS-C'}[a.variant]
mapping=(root/'build'/a.variant/(name+'.map')).read_text()
script=Path(a.script).read_text(encoding='utf-8-sig')
# Only explicit watchdog placeholders are replaced; ordinary realtime callbacks stay intact.
script=script.replace('@TIMEOUT@',str(a.timeout))
for sym,val in re.findall(r'(?m)^(_\w+)\s*=\s*\$([0-9A-Fa-f]+)',mapping):script=script.replace('@'+sym+'@','0x'+val)
script=script.replace('@FAULT@',str(a.fault))
script=script.replace('@V9990@','0' if a.variant.startswith('reference') else '1')
if Path(a.script).name=='edge-fixture.tcl':
    pixels=[1+((x//7+y//5)%15) for y in range(192) for x in range(256)]
    (out/'fixture.bin').write_bytes(bytes((pixels[i]<<4)|pixels[i+1] for i in range(0,len(pixels),2)))
(out/'body.tcl').write_text(script,encoding='utf8')
(out/'test.tcl').write_text('if {[catch {source body.tcl} error opts]} {set f [open error.txt w];puts $f $error;puts $f $opts;close $f;exit 1}\n',encoding='utf8')
shutil.copyfile(root/(name+'.rom'),out/'demo.rom')
cmd=[str(runtime/'emulator/openmsx.exe'),*([] if a.display else ['-command','set renderer none']),'-machine',cfg['machine'] if a.variant.startswith('reference') and not a.without_target else cfg['standardMachine'],'-cart','demo.rom','-romtype','ASCII16']
if not a.variant.startswith('reference') and not a.without_target:cmd+=['-ext','gfx9000']
cmd+=['-script','test.tcl']
with (out/'stdout.log').open('w') as stdout,(out/'stderr.log').open('w') as stderr:
    res=subprocess.run(cmd,cwd=out,env=env,stdout=stdout,stderr=stderr,timeout=a.timeout+30,creationflags=0x08000000 if os.name=='nt' else 0)
print(out,res.returncode);print((out/'stderr.log').read_text(errors='replace')[-1200:]);assert res.returncode==0
