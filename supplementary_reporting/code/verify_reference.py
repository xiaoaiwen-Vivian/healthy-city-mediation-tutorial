"""Compare newly calculated aggregates with the frozen study results."""
from pathlib import Path
import argparse
import json
import numpy as np
import pandas as pd

p=argparse.ArgumentParser(description=__doc__)
p.add_argument('--results', required=True, type=Path)
p.add_argument('--reference', required=True, type=Path)
p.add_argument('--out', required=True, type=Path)
a=p.parse_args()
a.out.mkdir(parents=True,exist_ok=True)
checks=[]
for ref in sorted(a.reference.glob('*.csv')):
    x=pd.read_csv(ref); y=pd.read_csv(a.results/ref.name)
    if list(x.columns)!=list(y.columns) or x.shape!=y.shape:
        raise ValueError(f'Unexpected layout: {ref.name}')
    for col in x.columns:
        if pd.api.types.is_numeric_dtype(x[col]):
            passed=np.isclose(x[col],y[col],rtol=2e-10,atol=1e-13,equal_nan=True)
            for i,ok in enumerate(passed):
                checks.append(dict(File=ref.name,Row=i+1,Field=col,Matches=bool(ok)))
        elif not x[col].fillna('').equals(y[col].fillna('')):
            raise ValueError(f'Changed row labels: {ref.name}/{col}')
x=json.loads((a.reference/'summary.json').read_text())
y=json.loads((a.results/'summary.json').read_text())
for key,value in x.items():
    if key=='source_sha256': continue  # Stata serialization can change while values remain identical.
    checks.append(dict(File='summary.json',Row=1,Field=key,Matches=bool(np.isclose(value,y[key],rtol=2e-10,atol=1e-13))))
df=pd.DataFrame(checks)
df.to_csv(a.out/'reference_numeric_checks.csv',index=False)
result={'passed':bool(df.Matches.all()),'numeric_checks':len(df),'mismatches':int((~df.Matches).sum()),
        'relative_tolerance':2e-10,'absolute_tolerance':1e-13,'reference_csv_files':len(list(a.reference.glob('*.csv')))}
(a.out/'reference_summary.json').write_text(json.dumps(result,indent=2)+'\n')
print(json.dumps(result,indent=2))
if not result['passed']:
    print(df[~df.Matches].to_string(index=False))
    raise SystemExit(1)
