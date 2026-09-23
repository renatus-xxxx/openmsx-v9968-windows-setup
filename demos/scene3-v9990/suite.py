"""Execute an isolated matrix and retain raw measurements. No hosted publication."""
import argparse,concurrent.futures,json,subprocess,sys,statistics,hashlib
from pathlib import Path
p=argparse.ArgumentParser();p.add_argument('--runtimes',required=True);p.add_argument('--output',required=True);p.add_argument('--kind',choices=['verify','measure'],required=True);p.add_argument('--variants',nargs='+',choices=['a','b','c','reference','reference-packets','reference-packets-c'],default=['a','b','reference']);p.add_argument('--sequence-only',action='store_true');p.add_argument('--timeout',type=int,default=480);a=p.parse_args()
root=Path(__file__).resolve().parent;out=Path(a.output).resolve();out.mkdir(parents=True,exist_ok=True)
jobs=[(v,c,m,n) for v in a.variants for c in ['cbios','fsa1gt'] for m in (([1] if a.sequence_only else [0,1]) if a.kind=='measure' else [0]) for n in (range(3) if a.kind=='measure' else [0])]
def run(job):
 v,c,m,n=job;name=f'{a.kind}-{v}-{c}-{m}-{n}';dest=out/name
 script=root/('verify.tcl' if a.kind=='verify' else 'measure.tcl')
 if a.kind=='measure':
  script=out/(name+'.tcl');script.write_text((root/'measure.tcl').read_text().replace('@MODE@',str(m)))
 cmd=[sys.executable,str(root/'run-test.py'),'--runtime',str(Path(a.runtimes)/c),'--variant',v,'--script',str(script),'--output',str(dest),'--timeout',str(a.timeout)]
 res=subprocess.run(cmd,capture_output=True,text=True);(out/(name+'.log')).write_text(res.stdout+res.stderr)
 if res.returncode:raise RuntimeError(name+' failed; see log')
 if a.kind=='verify':
  res=subprocess.run([sys.executable,str(root/'verify.py'),str(dest),'--variant',v],capture_output=True,text=True)
  (out/(name+'.log')).write_text(res.stdout+res.stderr)
  if res.returncode:raise RuntimeError(name+' pixels failed')
  record={'variant':v,'cpu':c,'pass':True,'frames':385}
 else:
  rows=[[float(x) for x in line.split()] for line in (dest/'timings.tsv').read_text().splitlines()]
  assert len(rows)>5
  if m==1:assert len(rows)==256 and all(int(r[3])==i%128 and int(r[4])==i for i,r in enumerate(rows))
  durations=[1000*(x[2]-x[0]) for x in rows];draw=[1000*(x[1]-x[0]) for x in rows];sync=[1000*(x[2]-x[1]) for x in rows]
  elapsed=rows[-1][2]-rows[0][0]
  record={'variant':v,'cpu':c,'mode':'animated' if m==0 else 'sequence','repeat':n,'frames':len(rows),'elapsed_seconds':elapsed,'fps':len(rows)/elapsed,'fps_excluding_request_gaps':len(rows)/(sum(durations)/1000),'frame_median_ms':statistics.median(durations),'frame_p95_ms':sorted(durations)[int(.95*(len(rows)-1))],'draw_mean_ms':statistics.mean(draw),'sync_mean_ms':statistics.mean(sync)}
 print(name,'PASS',flush=True);return record
records=[]
with concurrent.futures.ThreadPoolExecutor(max_workers=2) as pool:
 for item in pool.map(run,jobs):records.append(item);(out/(a.kind+'-results.json')).write_text(json.dumps(records,indent=2)+'\n')
