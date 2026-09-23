"""Compare verification dumps of old/new or ASM/C water implementations."""
import argparse,json
from pathlib import Path
p=argparse.ArgumentParser();p.add_argument('left');p.add_argument('right');a=p.parse_args()
left,right=Path(a.left),Path(a.right)
assert (left/'frames.tsv').read_bytes()==(right/'frames.tsv').read_bytes(), 'Sample sequence/page mismatch'
rows=(left/'frames.tsv').read_text().splitlines();assert len(rows)==385
for row in rows:
 i,pose,phase,page=map(int,row.split())
 l=(left/f'vram-{i:03}.bin').read_bytes();r=(right/f'vram-{i:03}.bin').read_bytes()
 assert len(l)==len(r)==131072
 assert l==r, f'VRAM mismatch: sample={i} pose={pose} phase={phase}'
print(json.dumps({'pass':True,'samples':385,'compared_bytes':385*131072,'mismatched_bytes':0}))
