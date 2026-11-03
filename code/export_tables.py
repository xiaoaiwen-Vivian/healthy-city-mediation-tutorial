"""Generate manuscript-aligned numeric tables from calculated results."""
from pathlib import Path
import pandas as pd
out=Path('results/tables');out.mkdir(exist_ok=True)
py=Path('results/python')
paths=pd.read_csv(py/'component_adjusted.csv')
individual=paths[paths.Level.eq('Individual')].copy()
wide=individual.pivot(index='Mediator',columns='Path',values=['estimate','p','BH'])
wide.columns=['_'.join(c) for c in wide.columns]
order=['Green','Road','SO2','Medical','PM25','Social']
wide=wide.reindex(order)
wide[['estimate_a','p_a','estimate_b','p_b']].to_csv(out/'Table_2_common_individual_paths.csv')
pd.read_csv(py/'sample_sizes.csv').to_csv(out/'Table_3_common_samples.csv',index=False)
city=pd.read_csv(py/'city_adjusted.csv')
city[['Mediator','ab','Sobel_SE','Sobel_p']].to_csv(out/'Table_4_common_city_sobel.csv',index=False)
rows=[]
for level in ['individual','city']:
    d=pd.read_csv(py/f'{level}_results.csv');d['Resampling']=level
    rows.append(d[['Mediator','Resampling','ab','Pct_L','Pct_U','BC_L','BC_U','B']])
pd.concat(rows).to_csv(out/'Table_5_indirect_intervals.csv',index=False)
pd.read_csv(py/'sobel_bh_worked.csv').to_csv(out/'Table_7_sobel_BH.csv',index=False)
wide[['p_a','BH_a','p_b','BH_b']].to_csv(out/'Table_8_individual_path_BH.csv')
city[['Mediator','sign_tail','sign_tail_BH']].rename(columns={
    'sign_tail':'Sign_tail_summary',
    'sign_tail_BH':'BH_calculation_descriptive'
}).to_csv(out/'Table_9_city_sign_summaries_descriptive.csv',index=False)
pd.read_csv(py/'individual_adjusted.csv')[['Mediator','sign_tail','sign_tail_BH']].rename(columns={
    'sign_tail':'Sign_tail_summary',
    'sign_tail_BH':'BH_calculation_descriptive'
}).to_csv(out/'Table_10_individual_sign_summaries_descriptive.csv',index=False)
pd.read_csv('results/individual_fe_sensitivity.csv').to_csv(out/'Table_11_fixed_effects_sensitivity.csv',index=False)
pd.read_csv('results/wild/wild_cluster_adjusted.csv')[
    ['Candidate','Path','N','Estimate','City_p','WCB_p','WCB_p_display','WCB_CI_L','WCB_CI_U']
].to_csv(out/'Table_S1_wild_cluster_tests.csv',index=False)
print('Exported ten numeric tables: Tables 2-5, 7-11 and S1. Tables 1 and 6 are definitions/design maps.')
print('Tables 9 and 10 are descriptive calculations. Table S1 reports unadjusted coefficient tests, not a*b tests.')
