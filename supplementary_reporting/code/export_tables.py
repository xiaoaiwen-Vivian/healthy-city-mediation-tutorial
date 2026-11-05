"""Format S2/S3 and the numerical sample-reporting text from calculated aggregates."""
from pathlib import Path
import argparse
import pandas as pd

p=argparse.ArgumentParser(description=__doc__)
p.add_argument('--results',required=True,type=Path)
a=p.parse_args(); root=a.results
read=lambda name:pd.read_csv(root/(name+'.csv'))
desc=read('Table_S2_descriptives')
miss=read('Table_S2_missingness').set_index(['Variable','Group'])
groups=['All','Untreated cities','Treated cities']
binary={'gender','marry','rwork','rural2','retire','smoken','drinkl','did'}
integer=lambda n:f'{int(n):,}'
rows=[]
for v in dict.fromkeys(desc.Variable):
    q=desc[desc.Variable.eq(v)].set_index('Group')
    row={'Variable':q.iloc[0].Label}
    for g in groups:
        r=q.loc[g]
        decimals=0 if v=='m_so2' else 2
        row[g+' | complete sample']=f'{integer(r.Count_1)} ({r.Percent_1:.1f})' if v in binary else f'{r.Mean:,.{decimals}f} ({r.SD:,.{decimals}f})'
        m=miss.loc[(v,g)]
        row[g+' | eligible missing']=f'{integer(m.Missing)} ({m.Percent_missing:.1f})'
        row[g+' | available n']=integer(r.N)
    rows.append(row)
pd.DataFrame(rows).to_csv(root/'Table_S2_display.csv',index=False)
rows=[]
for _,r in read('Table_S3_crude_adjusted').iterrows():
    row={'Coefficient':f'{r.Candidate} ({r.Path})','N':integer(r.N)}
    fmt=(lambda x:f'{x:.3e}') if r.Candidate=='SO2' and r.Path=='b' else (lambda x:f'{x:,.6f}')
    for k in ['Crude','Adjusted']:
        row[k+' estimate [95% CI]']=f'{fmt(r[k+"_estimate"])} [{fmt(r[k+"_lower"])}, {fmt(r[k+"_upper"])}]'
    rows.append(row)
pd.DataFrame(rows).to_csv(root/'Table_S3_display.csv',index=False)

lines=['Sample selection (person-waves; unique respondents in parentheses). Treated cities are shown first, untreated cities second.']
flow=read('selection_by_group')
for _,r in flow.iterrows():
    lines.append(f'{r.Stage}: {integer(r.Treated_rows)} ({integer(r.Treated_people)}) and {integer(r.Untreated_rows)} ({integer(r.Untreated_people)}).')
before=flow.iloc[-2]; after=flow.iloc[-1]
lines.append(f'Complete-case selection excludes {integer(before.Treated_rows-after.Treated_rows)} treated and {integer(before.Untreated_rows-after.Untreated_rows)} untreated person-waves.')
lines+=['','Follow-up of respondents eligible in 2011. Interviewed counts refer to the nominal survey wave, including interviews outside the selected calendar years; eligibility and completeness are separate counts.']
for _,r in read('initial_cohort_followup_by_group').iterrows():
    lines.append(f'{int(r.Year)}: treated cohort {integer(r.Treated_cohort)}, interviewed {integer(r.Treated_interviewed)}, eligible {integer(r.Treated_eligible)}, complete {integer(r.Treated_complete)}; untreated cohort {integer(r.Untreated_cohort)}, interviewed {integer(r.Untreated_interviewed)}, eligible {integer(r.Untreated_eligible)}, complete {integer(r.Untreated_complete)}.')
lines+=['','Observed waves and span. Span is last minus first observed year, with zero for a respondent with one wave; it is not continuously observed person-time.']
for _,r in read('observed_waves_and_span_by_group').iterrows():
    lines.append(f'{r.Sample}, {r.Group}: {integer(r.People)} respondents; mean waves {r.Mean_waves:.2f}; mean span {r.Mean_span_years:.2f} years; one wave {integer(r.One_wave)}; all five waves {integer(r.All_five_waves)}.')
lines+=['','Complete-sample outcome by survey year and eventual policy group. These summaries combine within-person change with changes in sample composition.']
for _,r in read('outcome_by_wave').iterrows():
    if r.Group=='All':continue
    lines.append(f'{int(r.Year)}, {r.Group}: n={integer(r.N)}, mean (SD) {r.Mean:.3f} ({r.SD:.3f}).')
(root/'sample_reporting.txt').write_text('\n'.join(lines)+'\n')
print('Exported Table_S2_display.csv, Table_S3_display.csv and sample_reporting.txt.')
