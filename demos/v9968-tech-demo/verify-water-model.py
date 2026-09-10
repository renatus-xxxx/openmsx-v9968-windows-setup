"""Check all precomputed bands against the reference, in MSX coordinates."""
from pathlib import Path
import json, math

root=Path(__file__).resolve().parent
layout=json.loads((root/'assets/bank-layout.json').read_text())
data=(root/'assets/megarom-data.bin').read_bytes()
entry=layout['WATER']
assert entry['bytes']==256*512
start=(entry['bank']-1)*16384
largest_error=0
clamped=0
for phase in range(256):
    for band in range(96):
        y=band*2
        offset=start+phase*512+band*4
        sx,dx,width,sy=data[offset:offset+4]
        assert (sx,dx,width) in ((0,0,0),(0,2,254),(2,0,254)), 'Horizontal excursion exceeds two pixels'
        # Equivalent downward-Y form, independent of the generator's bottom-Y form.
        reference=y+4*math.sin((y+1)*math.tau/64-phase*math.tau/256)
        clamped+=int(reference<0 or reference>190)
        reference=max(0,min(190,reference))
        error=abs(sy-reference)
        assert error<=0.5000001 and 0<=sy<=190
        largest_error=max(largest_error,error)
identity=(layout['IDENTITY']['bank']-1)*16384
assert data[identity:identity+384]==bytes(c for y in range(0,192,2) for c in (0,0,0,y))
print(json.dumps({'bands_checked':256*96,'horizontal_amplitude_pixels':2,
                  'max_sampling_error_pixels':largest_error,'clamped_bands':clamped,
                  'radians_per_second_at_60Hz':522*60*math.tau/65536,'pass':True},indent=2))
