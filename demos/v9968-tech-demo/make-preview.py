"""Encode actual emulator captures as a looping GIF. Python 3 + Pillow."""
from pathlib import Path
import argparse
from PIL import Image
parser=argparse.ArgumentParser()
parser.add_argument('screenshots',type=Path)
parser.add_argument('output',type=Path)
parser.add_argument('--scale',type=int,choices=(1,2,3),default=2)
args=parser.parse_args()
files=sorted(args.screenshots.glob('water-*.png'))
if len(files)!=16:raise SystemExit('Expected 16 water captures')
frames=[Image.open(f).convert('RGB') for f in files]
frames=[f.resize((f.width*args.scale,f.height*args.scale),Image.Resampling.NEAREST) for f in frames]
frames[0].save(args.output,save_all=True,append_images=frames[1:],duration=130,loop=0,disposal=2,optimize=False)
print(args.output)
