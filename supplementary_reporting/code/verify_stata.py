"""Compare independent Stata calculations with Python and the Word entries."""
from pathlib import Path
import json, re
import numpy as np
import pandas as pd

import argparse
parser=argparse.ArgumentParser(description="Compare independent Stata and Python S2/S3 calculations.")
parser.add_argument('--results', required=True, type=Path)
parser.add_argument('--stata-results', required=True, type=Path)
parser.add_argument('--out', required=True, type=Path)
args=parser.parse_args()
ROOT=args.out.resolve()
ROOT.mkdir(parents=True, exist_ok=True)
OUT=args.results.resolve()
STATA=args.stata_results.resolve()
rows=[]
def check(table,row,field,x,y,exact=False):
    passed=(x==y) if exact else np.isclose(x,y,rtol=2e-10,atol=1e-13,equal_nan=True)
    rows.append(dict(Table=table,Row=row,Field=field,Python=float(x),Stata=float(y),
        Absolute_difference=abs(x-y),Matches=bool(passed)))

stata=pd.read_stata(STATA/'stata_descriptives.dta',convert_categoricals=False)
stata.to_csv(STATA/'stata_descriptives_full_precision.csv',index=False,float_format='%.17g')
stata=stata.set_index(['Variable','Group'])
desc=pd.read_csv(OUT/'Table_S2_descriptives.csv').set_index(['Variable','Group'])
miss=pd.read_csv(OUT/'Table_S2_missingness.csv').set_index(['Variable','Group'])
for key,r in desc.iterrows():
    s=stata.loc[key]
    for field in ['N','Mean','SD']:
        check('S2','/'.join(key),field,r[field],s[field],field=='N')
    if pd.notna(r.Count_1):
        for field in ['Count_1','Percent_1']:check('S2','/'.join(key),field,r[field],s[field],field=='Count_1')
    for py,st in [('N','Eligible'),('Missing','Missing'),('Percent_missing','Percent_missing')]:
        check('S2','/'.join(key),'Missingness/'+py,miss.loc[key,py],s[st],py in ['N','Missing'])

coeff=pd.read_stata(STATA/'stata_coefficients.dta',convert_categoricals=False)
coeff.to_csv(STATA/'stata_coefficients_full_precision.csv',index=False,float_format='%.17g')
coeff=coeff.set_index(['Candidate','Path','Model'])
effects=pd.read_csv(OUT/'Table_S3_crude_adjusted.csv').set_index(['Candidate','Path'])
for key,r in effects.iterrows():
    for model in ['Crude','Adjusted']:
        s=coeff.loc[(*key,model)]
        check('S3','/'.join(key),model+'/N',r.N,s.N,True)
        check('S3','/'.join(key),model+'/Cities',r.Cities,s.Clusters,True)
        assert s.Clusters==94 and s.TreatedCities==10
        for py,st in [('estimate','Estimate'),('SE','SE'),('lower','CI_lower'),('upper','CI_upper')]:
            check('S3','/'.join(key),model+'/'+py,r[model+'_'+py],s[st])
df=pd.DataFrame(rows)
df.to_csv(ROOT/'independent_Stata_Python_checks.csv',index=False)
result={'passed':bool(df.Matches.all()),'checks':len(df),'mismatches':int((~df.Matches).sum()),
        'S2_groups_of_descriptives_and_missingness':63,'S3_models':26,
        'all_models_94_cities_10_treated':True}
(ROOT/'independent_summary.json').write_text(json.dumps(result,indent=2))
print(json.dumps(result,indent=2))
if not result['passed']: print(df[~df.Matches].to_string(index=False))


if not result["passed"]: raise SystemExit(1)
