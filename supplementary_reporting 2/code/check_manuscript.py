"""Read-only, cell-by-cell checks of the current manuscript's S2 and S3."""
from pathlib import Path
import json, re
import numpy as np
import pandas as pd
from manuscript_reader import extract_tables

import argparse
parser=argparse.ArgumentParser(description="Check displayed S2/S3 values without editing the manuscript.")
parser.add_argument('--docx', required=True, type=Path)
parser.add_argument('--results', required=True, type=Path)
parser.add_argument('--out', required=True, type=Path)
args=parser.parse_args()
ROOT=args.out.resolve()
ROOT.mkdir(parents=True, exist_ok=True)
DOCX=args.docx.resolve()
DATA=args.results.resolve()
TABLES=extract_tables(DOCX)
checks = []

def number(table, row, column, shown, actual, exact=False):
    raw = str(shown).replace('−','-').replace('–','-').replace(',','').strip()
    value = float(raw)
    mantissa, exp = raw.lower().split('e') if 'e' in raw.lower() else (raw, '0')
    decimals = len(mantissa.split('.')[1]) if '.' in mantissa else 0
    tolerance = 0 if exact else .500001*10**(int(exp)-decimals)
    ok = abs(value-float(actual)) <= tolerance
    checks.append(dict(Table=table,Row=row,Column=column,Reported=shown,
        Calculated=float(actual),Tolerance=tolerance,Matches=bool(ok)))

desc = pd.read_csv(DATA/'Table_S2_descriptives.csv').set_index(['Variable','Group'])
miss = pd.read_csv(DATA/'Table_S2_missingness.csv').set_index(['Variable','Group'])
groups = ['All','Untreated cities','Treated cities']
variables = list(dict.fromkeys(desc.index.get_level_values('Variable')))
binary = {'gender','marry','rwork','rural2','retire','smoken','drinkl','did'}
rows = TABLES['S2'][2:]
assert len(rows)==len(variables)==21 and all(len(r)==7 for r in rows)
for row,v in zip(rows,variables):
    # Descriptions and missing counts have different sample denominators.
    for j,g in enumerate(groups):
        s=desc.loc[(v,g)]
        tokens=re.fullmatch(r'([\d,.−-]+)\s*\(([\d,.−-]+)\)',row[j+1]).groups()
        fields=['Count_1','Percent_1'] if v in binary else ['Mean','SD']
        for field,token in zip(fields,tokens):
            number('S2',row[0],g+'/'+field,token,s[field],field=='Count_1')
        s=miss.loc[(v,g)]
        tokens=re.fullmatch(r'([\d,.]+)\s*\(([\d,.]+)\)',row[j+4]).groups()
        for field,token in zip(['Missing','Percent_missing'],tokens):
            number('S2',row[0],g+'/'+field,token,s[field],field=='Missing')
for j,g in enumerate(groups):
    for idx,source,col in [(j+1,desc,'Descriptive denominator'),(j+4,miss,'Missingness denominator')]:
        token=re.search(r'[nN]=([\d,]+)',TABLES['S2'][1][idx]).group(1)
        number('S2','Header',g+'/'+col,token,source.loc[('outcome',g),'N'],True)

# Available n is part of the S2 notes, not a full-column denominator.
from zipfile import ZipFile
from xml.etree import ElementTree as E
from manuscript_reader import visible_text, current_view, NS
with ZipFile(DOCX) as z:
    root=current_view(E.fromstring(z.read('word/document.xml')))
paragraphs=[visible_text(x) for x in root.findall('.//w:p',NS)]
note=next(p for p in paragraphs if p.startswith('All denominators are person-wave observations.'))
for label,v in [('SO2','m_so2'),('Medical','m_medical'),('Social','m_social')]:
    tokens=re.search(re.escape(label)+r', ([\d,]+) / ([\d,]+) / ([\d,]+)',note).groups()
    for token,g in zip(tokens,groups):number('S2','Available n: '+label,g,token,desc.loc[(v,g),'N'],True)

effects=pd.read_csv(DATA/'Table_S3_crude_adjusted.csv').set_index(['Candidate','Path'])
assert len(TABLES['S3'])==14
for row in TABLES['S3'][1:]:
    candidate,path=re.fullmatch(r'(.+) \(([abc])\)',row[0]).groups()
    values=effects.loc[(candidate,path)]
    number('S3',row[0],'N',row[1],values.N,True)
    for cell,kind in zip(row[2:],['Crude','Adjusted']):
        # Thousands separators are removed; comma+space separates interval bounds.
        match=re.fullmatch(r'(.+?)\s*\[([^\]]+), ([^\]]+)\]',cell)
        assert match,cell
        for field,token in zip(['estimate','lower','upper'],match.groups()):
            number('S3',row[0],kind+'/'+field,token,values[kind+'_'+field])

extra=pd.DataFrame(checks)
extra.to_csv(ROOT/'S2_S3_numeric_checks.csv',index=False)
summary=dict(passed=bool(extra.Matches.all()),numeric_entries=len(extra),
    S2_entries=int((extra.Table=='S2').sum()),S3_entries=int((extra.Table=='S3').sum()),
    mismatches=int((~extra.Matches).sum()))
(ROOT/'S2_S3_summary.json').write_text(json.dumps(summary,indent=2))
print(json.dumps(summary,indent=2))
if not summary['passed']:print(extra[~extra.Matches].to_string(index=False))


if not summary["passed"]: raise SystemExit(1)
