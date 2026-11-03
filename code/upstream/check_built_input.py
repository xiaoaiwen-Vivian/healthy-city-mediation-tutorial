"""Validate the newly built input using the tutorial's sample rules and fits."""
from pathlib import Path
import sys,json
sys.path.insert(0,str(Path(__file__).resolve().parents[1]))
from case_core import read_input,common_sample,fit_paths,CONTROLS,MEDIATORS,M_COLUMNS
import pandas as pd
import numpy as np
d,flow=read_input(sys.argv[1])
required=['outcome','did','year','treated']+CONTROLS
base=common_sample(d,required)
expected=[16661,16661,15430,11141,16661,16660]
assert len(base)==16661
rows=[]
for name,med,n in zip(MEDIATORS,M_COLUMNS,expected):
    s=common_sample(base,required+[med]);assert len(s)==n
    a,b,t,result,_=fit_paths(s,med)
    assert result['Cities']==94 and result['TreatedCities']==10
    rows.append(dict(Mediator=name,**result))
pd.DataFrame(rows).to_csv('logs/rebuilt_input_paths.csv',index=False)
print('UPSTREAM_INPUT_VALIDATED: baseline and six candidate common samples verified.')
