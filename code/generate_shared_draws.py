"""Write the reproducible 2,000 x 94 city multiplicity schedule to a new file."""
import argparse
from pathlib import Path
import numpy as np
import pandas as pd
from case_core import weights
p=argparse.ArgumentParser();p.add_argument('--output',required=True);a=p.parse_args()
out=Path(a.output)
if out.exists():raise SystemExit('Choose a new output path; the existing schedule is not overwritten.')
w=weights(94,2000,2025,None).astype(int)
d=pd.DataFrame(w,columns=[f'g{k:03d}' for k in range(1,95)])
d.insert(0,'draw',np.arange(1,2001));d.to_csv(out,index=False)
print('Generated city counts: 2,000 draws; 94 columns; each row sums to 94; PCG64 seed 2025.')
