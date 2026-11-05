"""Reproduce the additional STROBE reporting tables without changing analysis data.

Use --build-dir for a completed upstream build and --out for a new output
directory. Only aggregate results are written; input data are read only.
"""
from pathlib import Path
import json, sys, hashlib
import numpy as np
import pandas as pd
from scipy import stats

import argparse
parser = argparse.ArgumentParser(description="Calculate S2, S3 and longitudinal reporting summaries.")
parser.add_argument('--build-dir', required=True, type=Path)
parser.add_argument('--out', required=True, type=Path)
args = parser.parse_args()
run = args.build_dir.resolve()
OUT = args.out.resolve()
OUT.mkdir(parents=True, exist_ok=True)
cfg = {'input': str(run / 'data/analysis_input.dta')}
import case_core as core
d, _ = core.read_input(cfg['input'])
base = core.common_sample(d, ['outcome', 'did'] + core.CONTROLS)
assert (len(d), len(base), base.person_id.nunique()) == (34228, 16661, 7995)
assert (base.city.nunique(), int(base.groupby('city').treated.first().sum())) == (94, 10)

def save(name, rows):
    df = pd.DataFrame(rows)
    df.to_csv(OUT / f'{name}.csv', index=False, float_format='%.12g')
    return df

# Sequential respondent-record exclusions. City-only source records are never
# counted as survey participants.
p = pd.read_stata(run / 'temp/panel_merged.dta', convert_categoricals=False)
p = p[p.ID.notna() & p.ID.ne('') & p.wave.notna()].copy()
flow = []
def stage(label, q, idcol='ID'):
    previous = flow[-1]['Person_waves'] if flow else len(q)
    flow.append(dict(Stage=label, Person_waves=len(q), Respondents=q[idcol].nunique(),
                     Excluded_person_waves=previous-len(q)))
stage('Observed survey interviews in the assembled five-wave panel', p)
p = p[p.iwy.isin(core.YEARS)]
stage('Interview year in the five selected study years', p)
p = p[p.city.notna() & p.city.ne('')]
stage('City identifier available', p)
cy = pd.read_stata(run/'temp/city_yearbook_clean.dta', convert_categoricals=False)[['city','iwy']]
p = p.merge(cy, on=['city','iwy'], how='inner', validate='many_to_one')
stage('City-year matched to the statistical yearbook', p)
p = p[p.rwork.notna()]
stage('Work status observed', p)
p = p[~p.rgoingl.isin([997,999])]
stage('Nonresponse outcome codes 997 and 999 excluded', p)
pm = pd.read_stata(run/'temp/pm25_city_year.dta', convert_categoricals=False)[['city','iwy']]
p = p.merge(pm, on=['city','iwy'], how='inner', validate='many_to_one')
stage('City-year matched to the PM2.5 source', p)
p = p[p.age.ge(45) & p.age.notna()]
stage('Age at least 45 years', p)
p = p[p.rural.eq(0)]
stage('Urban residence: eligible observations', p)
assert len(p) == len(d)
assert set(zip(p.ID,p.iwy)) == set(zip(d.person_id,d.year))
stage('Outcome, policy and all controls observed: primary sample', base, 'person_id')
save('sample_selection_overall', flow)

groups = [('All', base), ('Untreated cities', base[base.treated.eq(0)]), ('Treated cities', base[base.treated.eq(1)])]
labels = {
 'outcome':'Reduced-activation item score (1–4)', 'age':'Age (years)',
 'gender':'Male', 'marry':'Married', 'log_real_inc_per':'Log real household income per person',
 'rwork':'Currently working', 'rural2':'Agricultural household registration',
 'edu':'Education score (1–4)', 'hchild':'Number of children', 'retire':'Retired',
 'adlab_c':'ADL difficulties (0–6)', 'smoken':'Currently smoking', 'drinkl':'Currently drinking',
 'srh':'Self-rated health (1–5)', 'm_green':'Green coverage (%)',
 'm_road':'Road area per person (m²)', 'm_so2':'Industrial SO2 emissions (tons)',
 'm_medical':'Hospitals and health centers per 10,000 residents',
 'm_pm25':'PM2.5 (μg/m³)', 'm_social':'Social participation (0–2)',
 'did':'Policy exposure (treated city × post-policy period)'}
binary = {'gender','marry','rwork','rural2','retire','smoken','drinkl','did'}
desc=[]
for v in ['outcome','did']+core.CONTROLS+core.M_COLUMNS:
 for g,q in groups:
    x=q[v].dropna()
    desc.append(dict(Variable=v, Label=labels[v], Group=g, N=len(x),
                     Mean=x.mean(), SD=x.std(ddof=1),
                     Count_1=int(x.eq(1).sum()) if v in binary else np.nan,
                     Percent_1=100*x.eq(1).mean() if v in binary else np.nan))
save('Table_S2_descriptives',desc)
save('sample_groups',[dict(Group=g, Person_waves=len(q), Respondents=q.person_id.nunique(),Cities=q.city.nunique()) for g,q in groups])

miss=[]
for v in ['outcome','did']+core.CONTROLS+core.M_COLUMNS:
 for g,q in [('All',d),('Untreated cities',d[d.treated.eq(0)]),('Treated cities',d[d.treated.eq(1)])]:
    miss.append(dict(Variable=v,Label=labels[v],Group=g,N=len(q),Missing=int(q[v].isna().sum()),Percent_missing=100*q[v].isna().mean()))
save('Table_S2_missingness',miss)

# Wave-specific counts distinguish observed interviews, eligibility, and inclusion.
allpanel=pd.read_stata(run/'data/charls.dta',convert_categoricals=False,columns=['ID','wave','iwy'])
cohort=set(d.loc[d.year.eq(2011),'person_id'])
wave=[]
for y in core.YEARS:
    q=d[d.year.eq(y)];b=base[base.year.eq(y)]
    # Use wave rather than calendar year for participation, so late interviews
    # remain observed survey contacts in this descriptive follow-up summary.
    original=allpanel[allpanel.wave.eq(core.YEARS.index(y)+1)]
    wave.append(dict(Year=y,Eligible_person_waves=len(q),Eligible_untreated=int(q.treated.eq(0).sum()),
                     Eligible_treated=int(q.treated.eq(1).sum()),Complete_person_waves=len(b),
                     Complete_untreated=int(b.treated.eq(0).sum()),Complete_treated=int(b.treated.eq(1).sum()),
                     Initial_2011_eligible_cohort=len(cohort),
                     Initial_cohort_interviewed=len(set(original.ID)&cohort),
                     Initial_cohort_eligible=len(set(q.person_id)&cohort),
                     Initial_cohort_complete=len(set(b.person_id)&cohort)))
save('cohort_followup_overall',wave)
counts=[]; spans=[]
for label,q in [('Eligible observations',d),('Primary complete sample',base)]:
    n=q.groupby('person_id').year.nunique()
    s=q.groupby('person_id').year.agg(lambda x:x.max()-x.min())
    for k in range(1,6): counts.append(dict(Sample=label,Waves=k,Respondents=int(n.eq(k).sum()),Percent=100*n.eq(k).mean()))
    spans.append(dict(Sample=label,Respondents=len(n),Mean_waves=n.mean(),Median_waves=n.median(),
                      Mean_span_years=s.mean(),Median_span_years=s.median(),Span_q1=s.quantile(.25),Span_q3=s.quantile(.75)))
save('observed_wave_counts',counts); save('observed_span_overall',spans)

outcome=[]
for y in core.YEARS:
 for g,q in [('All',base),('Untreated cities',base[base.treated.eq(0)]),('Treated cities',base[base.treated.eq(1)])]:
    x=q.loc[q.year.eq(y),'outcome']
    row=dict(Year=y,Group=g,N=len(x),Mean=x.mean(),SD=x.std(ddof=1))
    for k in range(1,5): row[f'Score_{k}_n']=int(x.eq(k).sum());row[f'Score_{k}_pct']=100*x.eq(k).mean()
    outcome.append(row)
save('outcome_by_wave',outcome)

# Crude OLS comparisons use exactly the same common sample as the adjusted model.
# CR1 standard errors cluster by city; no covariates or fixed effects enter crude models.
def crude_fit(q,y,columns):
    x=np.column_stack([np.ones(len(q)),q[columns].to_numpy(float)])
    target=q[y].to_numpy(float); codes=pd.factorize(q.city,sort=True)[0]
    scale=np.sqrt((x*x).sum(0));z=x/scale
    coef=np.linalg.lstsq(z,target,rcond=None)[0]
    residual=target-z@coef;bread=np.linalg.inv(z.T@z);g=int(codes.max()+1);n,k=z.shape
    scores=np.zeros((g,k));np.add.at(scores,codes,z*residual[:,None])
    inf=(scores@bread)/scale
    cov=g/(g-1)*(n-1)/(n-k)*(inf.T@inf)
    return coef/scale,cov

comparisons=[]
def effect(label,path,q,crude,adjusted,pos_crude,pos_adj):
    row=dict(Candidate=label,Path=path,N=len(q),Cities=q.city.nunique())
    for key,fit,i in [('Crude',crude,pos_crude),('Adjusted',adjusted,pos_adj)]:
        b,c=fit;est=b[i];se=np.sqrt(c[i,i]);crit=stats.t.ppf(.975,q.city.nunique()-1)
        row.update({f'{key}_estimate':est,f'{key}_SE':se,f'{key}_lower':est-crit*se,f'{key}_upper':est+crit*se})
    comparisons.append(row)
fits=[]
for m,v in zip(core.MEDIATORS,core.M_COLUMNS):
    q=core.common_sample(d,['outcome','did']+core.CONTROLS+[v])
    a,b,t,res,_=core.fit_paths(q,v);res['Candidate']=m;fits.append(res)
    if m=='Green':
        assert abs(res['c']-(-.086679))<1e-6
        effect('Overall policy','c',q,crude_fit(q,'outcome',['did']),(t['beta'],t['cov']),1,0)
    effect(m,'a',q,crude_fit(q,v,['did']),(a['beta'],a['cov']),1,0)
    effect(m,'b',q,crude_fit(q,'outcome',[v,'did']),(b['beta'],b['cov']),1,0)
save('Table_S3_crude_adjusted',comparisons);save('candidate_models',fits)

summary=dict(eligible_rows=len(d),eligible_people=d.person_id.nunique(),
             baseline_rows=len(base),baseline_people=base.person_id.nunique(),
             age_mean=base.age.mean(),age_sd=base.age.std(),male_percent=100*base.gender.mean(),
             outcome_mean=base.outcome.mean(),outcome_sd=base.outcome.std(),
             baseline_treated_rows=int(base.treated.eq(1).sum()),baseline_untreated_rows=int(base.treated.eq(0).sum()),
             baseline_treated_people=base[base.treated.eq(1)].person_id.nunique(),
             baseline_untreated_people=base[base.treated.eq(0)].person_id.nunique(),
             source_sha256=hashlib.sha256(Path(cfg['input']).read_bytes()).hexdigest(),
             rows_removed_complete=len(d)-len(base))
(OUT/'summary.json').write_text(json.dumps(summary,indent=2))
print(json.dumps(summary,indent=2))
print(pd.DataFrame(spans).to_string(index=False))
print(pd.DataFrame(wave).to_string(index=False))
print(pd.DataFrame(comparisons).to_string(index=False))
print('Existing model estimates reproduced; original data were not modified.')
