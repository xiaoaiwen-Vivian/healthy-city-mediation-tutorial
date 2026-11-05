"""Read-only comparison of a Word manuscript with calculated study results.

Tables are identified by captions, including Supplementary Table S1.
The current revision view includes insertions and excludes deleted text/rows.
The manuscript is never changed or redistributed.
"""
from pathlib import Path
from zipfile import ZipFile
from xml.etree import ElementTree as E
import argparse
import copy
import json
import re
import pandas as pd

NS = {'w': 'http://schemas.openxmlformats.org/wordprocessingml/2006/main'}
W = '{' + NS['w'] + '}'


def current_view(root):
    """Apply revision visibility in memory, including whole-row deletions."""
    root = copy.deepcopy(root)
    for parent in list(root.iter()):
        for child in list(parent):
            if child.tag == W+'tr' and child.find('w:trPr/w:del', NS) is not None:
                parent.remove(child)
    changes = {W+x for x in ['del', 'moveFrom', 'rPrChange', 'pPrChange',
               'tblPrChange', 'trPrChange', 'tcPrChange', 'sectPrChange', 'tblGridChange']}
    for parent in list(root.iter()):
        for child in list(parent):
            if child.tag in changes:
                parent.remove(child)
    # A deleted paragraph mark merges paragraphs; surviving text is retained.
    for parent in reversed(list(root.iter())):
        for child in list(parent):
            if child.tag in {W+'ins', W+'moveTo'}:
                index = list(parent).index(child)
                parent.remove(child)
                for offset, grandchild in enumerate(list(child)):
                    parent.insert(index+offset, grandchild)
    return root


def visible_text(element):
    return ''.join(t.text or '' for t in element.iter(W+'t')).strip()


def extract_tables(docx):
    with ZipFile(docx) as archive:
        xml = current_view(E.fromstring(archive.read('word/document.xml')))
    tables = {}
    pending = None
    for element in xml.find('w:body', NS):
        if element.tag == W+'p':
            caption = re.match(r'^(?:Supplementary\s+)?Table\s+(S?\d+)\b', visible_text(element))
            if caption:
                pending = caption.group(1)
        elif element.tag == W+'tbl':
            rows = [[visible_text(cell) for cell in row.findall('w:tc', NS)]
                    for row in element.findall('w:tr', NS)]
            if not rows or not any(any(cell for cell in row) for row in rows):
                continue
            if pending is None:
                raise ValueError('An active table has no preceding numbered caption.')
            if pending in tables:
                raise ValueError(f'Duplicate active caption: Table {pending}')
            tables[pending] = rows
            pending = None
    return tables


def normalize(value):
    return value.replace('−', '-').replace('–', '-').replace('₂', '2').replace('PM2.5', 'PM25')


def compare(docx, results):
    tables = extract_tables(docx)
    required = {str(i) for i in range(1, 12)} | {'S1'}
    missing = required - set(tables)
    unexpected = set(tables) - required - {'S2', 'S3'}
    if missing or unexpected:
        raise ValueError(f'Expected Tables 1-11 and S1, with optional S2/S3; '
                         f'missing {sorted(missing)}, unexpected {sorted(unexpected)}')
    root = Path(results)
    py = root/'python'
    paths = pd.read_csv(py/'component_adjusted.csv')
    city = pd.read_csv(py/'city_adjusted.csv').set_index('Mediator')
    individual = pd.read_csv(py/'individual_adjusted.csv').set_index('Mediator')
    sizes = pd.read_csv(py/'sample_sizes.csv').set_index('Mediator')
    sobel = pd.read_csv(py/'sobel_bh_worked.csv').set_index('Mediator')
    fe = pd.read_csv(root/'individual_fe_sensitivity.csv')
    wild = pd.read_csv(root/'wild/wild_cluster_adjusted.csv').set_index(['Candidate', 'Path'])
    checks = []

    def body(number, nrows, ncols):
        rows = tables[str(number)]
        if len(rows) != nrows+1 or any(len(r) != ncols for r in rows):
            raise ValueError(f'Table {number}: unexpected row or column count')
        return rows[1:]

    def check(table, row, column, text, value):
        raw = normalize(text).replace(',', '').replace(' ', '').rstrip('*')
        if raw.startswith('<'):
            limit = float(raw[1:])
            ok = 0 <= float(value) < limit
            tolerance = None
            rule = f'0 <= value < {limit}'
        else:
            shown = float(raw)
            mantissa, exponent = (raw.lower().split('e') if 'e' in raw.lower() else (raw, '0'))
            decimals = len(mantissa.split('.')[1]) if '.' in mantissa else 0
            tolerance = .500001 * 10**(int(exponent)-decimals)
            ok = abs(float(value)-shown) <= tolerance
            rule = 'Within half of the last displayed digit'
        checks.append(dict(Table=str(table), Row=row, Column=column, Reported=text,
                           Calculated=float(value), Rounding_tolerance=tolerance,
                           Matches_displayed_precision=bool(ok), Rule=rule))

    def interval(table, row, text, lo, hi):
        normalized = normalize(text).strip('[] ')
        # Comma-space separates S1 bounds, including thousands separators.
        if ', ' in normalized:
            tokens = [s.strip().replace(',', '') for s in normalized.split(', ')]
        else:
            tokens = re.findall(r'[+-]?(?:\d+(?:\.\d*)?|\.\d+)(?:[eE][+-]?\d+)?', normalized)
        if len(tokens) != 2:
            raise ValueError(f'Table {table}: cannot parse interval {text!r}')
        for field, s, value in zip(['CI_L', 'CI_U'], tokens, [lo, hi]):
            check(table, row, field, s, value)

    for row in body(2, 6, 5):
        m = normalize(row[0])
        g = paths[(paths.Mediator==m)&(paths.Level=='Individual')].set_index('Path')
        for col, s, v in zip(['a','a_p','b','b_p'], row[1:],
                            [g.loc['a','estimate'],g.loc['a','p'],g.loc['b','estimate'],g.loc['b','p']]):
            check(2,m,col,s,v)
    for row in body(3, 6, 4):
        m = normalize(row[0]); source = sizes.loc[m]
        check(3,m,'Observations',row[1],source.Common_N)
        check(3,m,'Respondents',row[2],source.Respondents)
    for row in body(4, 6, 4):
        m = normalize(row[0]); source = city.loc[m]
        for col,s in zip(['ab','Sobel_SE','Sobel_p'],row[1:]):
            check(4,m,col,s,source[col])
    for row in body(5, 12, 4):
        label = normalize(row[0]).replace(' ', '')
        level = 'Individual' if label.endswith('Individual') else 'City'
        m = label.removesuffix(level)
        source = (individual if level=='Individual' else city).loc[m]
        check(5,label,'ab',row[1],source.ab)
        interval(5,label+'_percentile',row[2],source.Pct_L,source.Pct_U)
        interval(5,label+'_BC',row[3],source.BC_L,source.BC_U)
    for row in body(7, 6, 5):
        m = normalize(row[0]); source = sobel.loc[m]
        for col,s in zip(['rank','input_value','six_times_value_over_rank','BH'],row[1:]):
            check(7,m,col,s,source[col])
    for row in body(8, 6, 5):
        m = normalize(row[0])
        g = paths[(paths.Mediator==m)&(paths.Level=='Individual')].set_index('Path')
        for col,s,v in zip(['a_p','a_BH','b_p','b_BH'],row[1:],
                          [g.loc['a','p'],g.loc['a','BH'],g.loc['b','p'],g.loc['b','BH']]):
            check(8,m,col,s,v)
    for number, source in [(9,city),(10,individual)]:
        if 'descriptive' not in ' '.join(tables[str(number)][0]).lower():
            raise ValueError(f'Table {number}: missing descriptive label')
        for row in body(number, 6, 3):
            m = normalize(row[0]); values = source.loc[m]
            for col,s in zip(['sign_tail','sign_tail_BH'],row[1:]):
                check(number,m,col,s,values[col])
    for row in body(11, 4, 7):
        fixed = row[0].replace(' and ', ' + ')
        g = fe[(fe.Fixed_effects==fixed)&(fe.Clustering==row[1])].iloc[0]
        name = row[0]+'/'+row[1]
        for col,s in zip(['N','Coef','SE','P'],row[2:6]):
            check(11,name,col,s,g[col])
        interval(11,name,row[6],g.CI_L,g.CI_U)
    for row in body('S1', 13, 6):
        label = normalize(row[0])
        match = re.fullmatch(r'(.+)\s+\(([abc])\)', label)
        if not match:
            raise ValueError(f'Unrecognized S1 coefficient label: {row[0]}')
        candidate,path = match.groups()
        if candidate=='Overall policy': candidate='Overall'
        g = wild.loc[(candidate,path)]
        for col,s in zip(['N','Estimate','City_p','WCB_p'],row[1:5]):
            check('S1',label,col,s,g[col])
        interval('S1',label,row[5],g.WCB_CI_L,g.WCB_CI_U)
    frame = pd.DataFrame(checks)
    summary = dict(passed=bool(frame.Matches_displayed_precision.all()),
                   manuscript_view='Current text: insertions included, deletions excluded',
                   active_tables=len(tables), numeric_tables_checked=10,
                   displayed_numeric_entries_checked=len(frame),
                   mismatches=int((~frame.Matches_displayed_precision).sum()),
                   table_order=list(tables),
                   supplemental_tables_checked_separately=sorted(set(tables) & {'S2', 'S3'}),
                   supplemental_checker='supplementary_reporting/run.py check --manuscript <manuscript.docx>',
                   scope='Numerical entries in Tables 2-5, 7-11 and S1. This is not a prose, citation, code-snippet or page-layout check.')
    return frame, summary


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--docx', required=True)
    parser.add_argument('--results', required=True)
    parser.add_argument('--output', required=True)
    args = parser.parse_args()
    frame, summary = compare(args.docx, args.results)
    output = Path(args.output)
    output.parent.mkdir(parents=True, exist_ok=True)
    frame.to_csv(output,index=False)
    output.with_suffix('.json').write_text(json.dumps(summary,indent=2)+'\n')
    print(json.dumps(summary,indent=2))
    if not summary['passed']:
        print(frame.loc[~frame.Matches_displayed_precision].to_string(index=False))
        raise SystemExit(1)
    print('MANUSCRIPT_TABLES_VERIFIED')


if __name__=='__main__':
    main()
