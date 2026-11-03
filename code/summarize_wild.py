"""Keep all 13 WCB results; BH families are six a and six b tests separately."""
from pathlib import Path
import numpy as np
import pandas as pd
from inference import bh_adjust
p=Path('results/wild')
d=pd.read_csv(p/'wild_cluster_9999.csv')
assert len(d)==13 and (d.Reps==9999).all() and (d.Reps_feasible==9999).all()
d['BH_family']='Separate overall-policy test'
d['WCB_BH_adjusted_p']=np.nan
for path in ['a','b']:
    m=d.Path.eq(path);assert m.sum()==6
    d.loc[m,'WCB_BH_adjusted_p']=bh_adjust(d.loc[m,'WCB_p'])
    d.loc[m,'BH_family']='Six '+path+' paths'
d['WCB_p_display']=d.WCB_p.map(lambda x:'<0.001 (zero exceedances)' if x==0 else f'{x:.6f}')
d.to_csv(p/'wild_cluster_adjusted.csv',index=False)
print(d[['Candidate','Path','N','Estimate','WCB_p','WCB_BH_adjusted_p']].to_string(index=False))
print('All 13 WCB tests retained. These are component/overall coefficient tests, not tests of a*b.')
