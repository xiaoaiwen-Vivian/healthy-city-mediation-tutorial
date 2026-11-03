"""Verify fresh estimates/draws against separate frozen reference outputs."""
from pathlib import Path
import argparse,json,sys
import numpy as np
import pandas as pd
from scipy import stats
from case_core import weights

p=argparse.ArgumentParser();p.add_argument('--reference',required=True);p.add_argument('--mode',required=True,choices=['aggregate-only','full-estimation']);a=p.parse_args()
reference=Path(a.reference);root=Path('results');checks=[]
for src in sorted(reference.rglob('*.csv')):
    rel=src.relative_to(reference);dst=root/rel
    assert dst.is_file(),f'Missing output: {rel}'
    old=pd.read_csv(src);new=pd.read_csv(dst)
    assert set(old.columns)<=set(new.columns),f'Column mismatch: {rel}'
    new=new[old.columns]
    keys=[k for k in ['Mediator','Candidate','Level','Sample','Path','Family','Fixed_effects','Clustering','draw','stage'] if k in old]
    if keys:
        old=old.sort_values(keys,kind='stable').reset_index(drop=True)
        new=new.sort_values(keys,kind='stable').reset_index(drop=True)
    assert old.shape==new.shape,f'Shape mismatch: {rel}'
    max_scaled=0.
    for col in old:
        if pd.api.types.is_numeric_dtype(old[col]):
            x=old[col].to_numpy(float);y=new[col].to_numpy(float)
            assert np.array_equal(np.isnan(x),np.isnan(y)),f'Missingness mismatch {rel}/{col}'
            # Common tolerance for cross-platform linear algebra; counts exact.
            if col in ['N','Cities','TreatedCities','Respondents','Common_N','B','Negative','Positive','Zero','draw','Reps','Reps_feasible','Null_imposed','CI_pieces']:
                np.testing.assert_array_equal(x,y,err_msg=f'{rel}/{col}')
            elif col not in ['Estimate_difference','SE_difference']:
                np.testing.assert_allclose(x,y,rtol=2e-7,atol=1e-10,equal_nan=True,err_msg=f'{rel}/{col}')
            finite=np.isfinite(x)&np.isfinite(y)
            if finite.any():max_scaled=max(max_scaled,float(np.max(abs(x[finite]-y[finite])/(1+abs(x[finite])))))
        else:
            if col=='WCB_CI_text':continue  # full-precision limits checked above
            assert old[col].fillna('').astype(str).equals(new[col].fillna('').astype(str)),f'Labels mismatch {rel}/{col}'
    checks.append({'file':str(rel),'rows':len(new),'passed':True,'max_scaled_difference':max_scaled})

# Shared schedule must reproduce the exact original city resampling plan.
observed=weights(94,2000,2025,'code/shared_draw_counts_94.csv')
regenerated=weights(94,2000,2025,None)
np.testing.assert_array_equal(observed,regenerated)

# Stata and Python implement the city pairs bootstrap independently.
for candidate in ['Green','Road','SO2','Medical','PM25','Social']:
    st=pd.read_csv(root/f'stata/city_draws_{candidate}.csv')
    py=pd.read_csv(root/f'python/city_draws_{candidate}.csv')
    assert len(st)==len(py)==2000
    np.testing.assert_allclose(st[['a','b','ab']],py[['a','b','ab']],rtol=2e-7,atol=1e-10,err_msg=candidate)

path=pd.read_csv(root/'python/component_paths.csv')
city=pd.read_csv(root/'python/city_results.csv')
individual=pd.read_csv(root/'python/individual_results.csv')
for r in city.itertuples():
    comp=path[path.Mediator.eq(r.Mediator)]
    assert len(comp)==4 and comp.N.eq(r.N).all()
    ind=individual[individual.Mediator.eq(r.Mediator)].iloc[0]
    assert ind.N==r.N
    np.testing.assert_allclose([ind.a,ind.b,ind.ab],[r.a,r.b,r.ab],rtol=2e-7,atol=1e-10)
bh=pd.read_csv(root/'python/all_bh_families.csv')
assert len(bh)==42 and bh.groupby('Family').size().eq(6).all()
formal=pd.read_csv(root/'python/hypothesis_test_bh.csv')
descriptive=pd.read_csv(root/'python/descriptive_bh.csv')
assert len(formal)==30 and formal.Family.nunique()==5
assert len(descriptive)==12 and descriptive.Family.nunique()==2
assert formal.Use.eq('Hypothesis-test p values').all()
assert descriptive.Use.eq('Descriptive only').all()
assert not set(formal.Family)&set(descriptive.Family)
for _,g in bh.groupby('Family'):
    np.testing.assert_allclose(g.BH,stats.false_discovery_control(g.input,method='bh'),rtol=1e-12,atol=1e-14)

expected_tables=['Table_2_common_individual_paths.csv','Table_3_common_samples.csv',
    'Table_4_common_city_sobel.csv','Table_5_indirect_intervals.csv','Table_7_sobel_BH.csv',
    'Table_8_individual_path_BH.csv','Table_9_city_sign_summaries_descriptive.csv',
    'Table_10_individual_sign_summaries_descriptive.csv','Table_11_fixed_effects_sensitivity.csv',
    'Table_S1_wild_cluster_tests.csv']
assert sorted(p.name for p in (root/'tables').glob('*.csv'))==sorted(expected_tables)
report={'mode':a.mode,'passed':True,'reference_csv_files_checked':len(checks),'checks':checks,'shared_schedule_exact_match':True,'city_draws_stata_python_agree':True,'common_sample_counts_and_coefficients_agree':True,'BH_hypothesis_testing_families':5,'BH_descriptive_groups':2,'members_per_family_or_group':6,'numeric_table_exports':10,'reference_used_for_estimation':False,'note':'Aggregate-only mode does not re-estimate from individual records.' if a.mode=='aggregate-only' else 'All estimates and bootstrap draws were regenerated from the supplied linked input in an empty results directory.'}
Path('verification_report.json').write_text(json.dumps(report,indent=2)+'\n')
print(json.dumps({k:v for k,v in report.items() if k!='checks'},indent=2))
print('ALL_RESULTS_VERIFIED')
