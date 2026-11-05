"""Descriptive group counts only; no regression or bootstrap estimation."""
from pathlib import Path
import json, hashlib
import numpy as np
import pandas as pd

import argparse
import case_core as core
parser=argparse.ArgumentParser(description="Summarize selection and follow-up by policy group.")
parser.add_argument('--build-dir', required=True, type=Path)
parser.add_argument('--out', required=True, type=Path)
args=parser.parse_args()
run=args.build_dir.resolve()
OUT=args.out.resolve()
cfg={'input':str(run/'data/analysis_input.dta')}
source=Path(cfg['input'])
sha_before=hashlib.sha256(source.read_bytes()).hexdigest()
d,_=core.read_input(source)
base=core.common_sample(d,['outcome','did']+core.CONTROLS)
assert (len(d),len(base),base.person_id.nunique())==(34228,16661,7995)
assert not d.groupby('person_id').treated.nunique().gt(1).any()

p=pd.read_stata(run/'temp/panel_merged.dta',convert_categoricals=False,
                columns=['ID','wave','iwy','city','treat','rwork','rgoingl','age','rural'])
p=p[p.ID.notna() & p.ID.ne('') & p.wave.notna()].copy()
assert not p.groupby('ID').treat.nunique().gt(1).any()
assert set(p.treat.unique())=={0,1}
flow=[]
def add(label,q,idcol='ID',groupcol='treat'):
    row={'Stage':label,'All_rows':len(q),'All_people':q[idcol].nunique()}
    for flag,name in [(1,'Treated'),(0,'Untreated')]:
        s=q[q[groupcol].eq(flag)]
        row[name+'_rows']=len(s);row[name+'_people']=s[idcol].nunique()
    assert row['Treated_rows']+row['Untreated_rows']==row['All_rows']
    assert row['Treated_people']+row['Untreated_people']==row['All_people']
    flow.append(row)

add('Observed survey interviews in the assembled five-wave panel',p)
p=p[p.iwy.isin(core.YEARS)]
add('Interview year in the five selected study years',p)
p=p[p.city.notna() & p.city.ne('')]
add('City identifier available',p)
cy=pd.read_stata(run/'temp/city_yearbook_clean.dta',convert_categoricals=False,columns=['city','iwy'])
p=p.merge(cy,on=['city','iwy'],how='inner',validate='many_to_one')
add('City-year matched to the statistical yearbook',p)
p=p[p.rwork.notna()]
add('Work status observed',p)
p=p[~p.rgoingl.isin([997,999])]
add('Nonresponse outcome codes 997 and 999 excluded',p)
pm=pd.read_stata(run/'temp/pm25_city_year.dta',convert_categoricals=False,columns=['city','iwy'])
p=p.merge(pm,on=['city','iwy'],how='inner',validate='many_to_one')
add('City-year matched to the PM2.5 source',p)
p=p[p.age.ge(45) & p.age.notna()]
add('Age at least 45 years',p)
p=p[p.rural.eq(0)]
add('Urban residence: eligible observations',p)
assert set(zip(p.ID,p.iwy))==set(zip(d.person_id,d.year))
add('Outcome, policy and all controls observed: primary sample',base,'person_id','treated')
flow_df=pd.DataFrame(flow)
previous=pd.read_csv(OUT/'sample_selection_overall.csv')
assert list(flow_df.Stage)==list(previous.Stage)
assert list(flow_df.All_rows)==list(previous.Person_waves)
assert list(flow_df.All_people)==list(previous.Respondents)
flow_df.to_csv(OUT/'selection_by_group.csv',index=False)

allpanel=pd.read_stata(run/'data/charls.dta',convert_categoricals=False,columns=['ID','wave','iwy'])
cohort_map=d[d.year.eq(2011)].set_index('person_id').treated.to_dict()
assert len(cohort_map)==6060
cohorts={name:{k for k,v in cohort_map.items() if v==flag} for name,flag in [('Treated',1),('Untreated',0)]}
assert len(cohorts['Treated'])==709 and len(cohorts['Untreated'])==5351
follow=[]
for y in core.YEARS:
    interviews=set(allpanel.loc[allpanel.wave.eq(core.YEARS.index(y)+1),'ID'])
    eligible=set(d.loc[d.year.eq(y),'person_id'])
    complete=set(base.loc[base.year.eq(y),'person_id'])
    row={'Year':y}
    for name,ids in cohorts.items():
        row[name+'_cohort']=len(ids)
        row[name+'_interviewed']=len(interviews&ids)
        row[name+'_eligible']=len(eligible&ids)
        row[name+'_complete']=len(complete&ids)
    follow.append(row)
follow_df=pd.DataFrame(follow)
previous=pd.read_csv(OUT/'cohort_followup_overall.csv')
for suffix,oldcol in [('interviewed','Initial_cohort_interviewed'),('eligible','Initial_cohort_eligible'),('complete','Initial_cohort_complete')]:
    assert list(follow_df['Treated_'+suffix]+follow_df['Untreated_'+suffix])==list(previous[oldcol])
follow_df.to_csv(OUT/'initial_cohort_followup_by_group.csv',index=False)

spans=[]
for label,q in [('Eligible observations',d),('Primary complete sample',base)]:
    for name,flag in [('Treated',1),('Untreated',0)]:
        s=q[q.treated.eq(flag)]
        person=s.groupby('person_id').year.agg(['nunique','min','max'])
        span=person['max']-person['min']
        assert person['nunique'].sum()==len(s)
        spans.append(dict(Sample=label,Group=name,People=len(person),Person_waves=len(s),
                          Mean_waves=person['nunique'].mean(),Mean_span_years=span.mean(),
                          Total_span_years=span.sum(),One_wave=int(person['nunique'].eq(1).sum()),
                          All_five_waves=int(person['nunique'].eq(5).sum())))
spans_df=pd.DataFrame(spans)
spans_df.to_csv(OUT/'observed_waves_and_span_by_group.csv',index=False,float_format='%.12g')
primary=spans_df[spans_df.Sample.eq('Primary complete sample')]
assert primary.One_wave.sum()==3082 and primary.All_five_waves.sum()==276
assert primary.People.sum()==7995
assert abs(primary.Total_span_years.sum()/7995-3.35759849906)<1e-10

# Independent cross-tab checks of the final sample and first-wave cohort.
raw=pd.read_stata(source,convert_categoricals=False)
raw=raw[raw.ID.notna() & raw.ID.ne('') & raw.wave.notna() & raw.city.notna() & raw.city.ne('') & raw.iwy.notna()]
raw=raw[raw.age.ge(45) & raw.age.notna() & raw.rural.eq(0)]
assert len(raw)==34228
raw_base=raw.dropna(subset=['rgoingl','did']+core.CONTROLS)
assert set(zip(raw_base.ID,raw_base.iwy))==set(zip(base.person_id,base.year))
assert len(raw_base)==16661
for name,flag in [('Treated',1),('Untreated',0)]:
    assert len(raw_base[raw_base.treat.eq(flag)])==int(primary.loc[primary.Group.eq(name),'Person_waves'].iloc[0])
    assert set(raw.loc[raw.iwy.eq(2011)&raw.treat.eq(flag),'ID'])==cohorts[name]

assert hashlib.sha256(source.read_bytes()).hexdigest()==sha_before
report={'regressions_run':0,'bootstrap_runs':0,'source_unchanged':True,
        'source_sha256':sha_before,'all_group_counts_sum_to_previous_totals':True,
        'eligible_and_complete_record_sets_match_original_analysis':True,
        'treatment_group_constant_within_person':True,
        'initial_cohort_definition':'Eligible respondents in 2011, classified by eventual city policy status',
        'interview_count_definition':'Presence in the nominal survey wave, including late interview years',
        'span_definition':'Last minus first complete-observation year; zero for one-wave respondents; not continuously observed person-time',
        'missing_visit_reasons':'Not inferred from absence'}
(OUT/'sample_validation.json').write_text(json.dumps(report,indent=2))
print(flow_df.to_string(index=False))
print('\nINITIAL 2011 COHORT\n'+follow_df.to_string(index=False))
print('\nWAVES AND OBSERVED SPAN\n'+spans_df.to_string(index=False))
print('\n'+json.dumps(report,indent=2))
