#!/usr/bin/env python3
"""Reproduce Supplementary Table S4 from saved estimates or authorized data."""
import argparse
import csv
from datetime import datetime, timezone
import json
import math
from pathlib import Path
import re
import shutil
import subprocess
import sys
import xml.etree.ElementTree as ET
from zipfile import ZipFile

ROOT = Path(__file__).resolve().parent
NAMES = ['Green', 'Road', 'SO2', 'Medical', 'PM25', 'Social']
COUNTS = [16661, 16661, 15430, 11141, 16661, 16660]
SUCCESS = 'RR2_LOTO_SUCCESS: all six full samples and 60 treated-city deletions completed; 132 path regressions.'


def require(condition, message):
    if not condition:
        raise ValueError(message)


def read_csv(path):
    with path.open(encoding='utf-8-sig', newline='') as f:
        return list(csv.DictReader(f))


def write_csv(path, rows):
    with path.open('w', encoding='utf-8', newline='') as f:
        writer = csv.DictWriter(f, fieldnames=list(rows[0]))
        writer.writeheader()
        writer.writerows(rows)


def summarize(rows):
    require(len(rows) == 66, 'Expected 66 fits: six full samples and 60 deletions.')
    require({r['Candidate'] for r in rows} == set(NAMES), 'Unexpected candidate family.')
    summaries = []
    for name, n in zip(NAMES, COUNTS):
        group = [r for r in rows if r['Candidate'] == name]
        aliases = [r['OmittedCity'] for r in group]
        require(len(group) == 11 and set(aliases) == {'Full', *[f'T{k:02d}' for k in range(1, 11)]},
                f'{name}: expected one full fit and ten unique deletions.')
        base = next(r for r in group if r['OmittedCity'] == 'Full')
        deletions = [r for r in group if r['OmittedCity'] != 'Full']
        require(int(base['N']) == n, f'{name}: wrong full-sample N.')
        for r in group:
            full = r['OmittedCity'] == 'Full'
            require(int(r['Cities']) == (94 if full else 93), f'{name}: wrong city count.')
            require(int(r['TreatedCities']) == (10 if full else 9), f'{name}: wrong treated-city count.')
            require(int(r['SameSample']) == 1, f'{name}: path samples differ.')
            require(int(r['N']) + int(r['N_removed']) == n, f'{name}: row counts do not reconcile.')
            require(int(r['Respondents']) + int(r['Respondents_removed']) == int(base['Respondents']),
                    f'{name}: respondent counts do not reconcile.')
            require(math.isclose(float(r['a']) * float(r['b']), float(r['ab']), rel_tol=1e-11, abs_tol=1e-14),
                    f'{name}: product differs from a*b.')
        value = float(base['ab'])
        require(value != 0, f'{name}: relative change undefined when full-sample product is zero.')
        low = min(deletions, key=lambda r: float(r['ab']))
        high = max(deletions, key=lambda r: float(r['ab']))
        influential = max(deletions, key=lambda r: abs(float(r['ab']) - value))
        change = abs(float(influential['ab']) - value)
        summaries.append(dict(
            Candidate=name, N_full=n, ab_full=value,
            ab_min=float(low['ab']), ab_min_city=low['OmittedCity'],
            ab_max=float(high['ab']), ab_max_city=high['OmittedCity'],
            negative_products=sum(float(r['ab']) < 0 for r in deletions),
            positive_products=sum(float(r['ab']) > 0 for r in deletions),
            sign_changes=sum(float(r['ab']) * value < 0 for r in deletions),
            max_abs_change=change, max_abs_change_percent=change / abs(value) * 100,
            most_influential_city=influential['OmittedCity'],
            ab_after_most_influential_deletion=float(influential['ab']),
            a_min=min(float(r['a']) for r in deletions), a_max=max(float(r['a']) for r in deletions),
            b_min=min(float(r['b']) for r in deletions), b_max=max(float(r['b']) for r in deletions),
            N_min=min(int(r['N']) for r in deletions), N_max=max(int(r['N']) for r in deletions), deletions=10))
    return summaries


def compare(actual, reference, keys, rtol=1e-10, atol=1e-14):
    def index(rows):
        result = {tuple(r[k] for k in keys): r for r in rows}
        require(len(result) == len(rows), 'Duplicate comparison keys.')
        return result
    current, expected = index(actual), index(reference)
    require(current.keys() == expected.keys(), 'Comparison row keys differ.')
    checked = 0
    for key, row in current.items():
        require(row.keys() == expected[key].keys(), f'{key}: comparison columns differ.')
        for column, value in row.items():
            target = expected[key][column]
            try:
                numeric, numeric_target = float(value), float(target)
            except (TypeError, ValueError):
                require(str(value) == str(target), f'{key}/{column}: text differs.')
            else:
                require(math.isfinite(numeric) and math.isclose(numeric, numeric_target, rel_tol=rtol, abs_tol=atol),
                        f'{key}/{column}: {value} differs from {target}.')
                checked += 1
    return checked


def display_rows(summary):
    return [dict(Candidate=r['Candidate'].replace('PM25', 'PM2.5'), N=f"{r['N_full']:,}",
                 ab=f"{r['ab_full']:.6f}", Minimum=f"{r['ab_min']:.6f}", Maximum=f"{r['ab_max']:.6f}",
                 Sign_changes=f"{r['sign_changes']}/10", Maximum_relative_change_percent=f"{r['max_abs_change_percent']:.1f}")
            for r in summary]


def check_word(path, displays):
    # Read current text: include insertions and exclude deletions/moved-from text.
    w = '{http://schemas.openxmlformats.org/wordprocessingml/2006/main}'
    with ZipFile(path) as z:
        root = ET.fromstring(z.read('word/document.xml'))
    for parent in list(root.iter()):
        for child in list(parent):
            if child.tag in {w+'del', w+'moveFrom'}:
                parent.remove(child)
    tables = []
    for table in root.iter(w+'tbl'):
        rows = [[ ''.join(t.text or '' for t in cell.iter(w+'t')) for cell in row.findall(w+'tc')]
                for row in table.findall(w+'tr')
                if row.find(w+'trPr/'+w+'del') is None]
        if rows and 'Maximum relative' in ' '.join(rows[0]) and 'Candidate' in rows[0]:
            tables.append(rows)
    require(len(tables) == 1, 'Expected one S4 table with the Maximum relative change column.')
    rows = tables[0][1:]
    require(len(rows) == 6, 'S4 must contain all six candidates.')
    checked = 0
    for actual, expected in zip(rows, displays):
        require(len(actual) == 6 and actual[0] == expected['Candidate'], 'S4 candidate order or columns differ.')
        expected_cells = [expected['N'], expected['ab'], expected['Minimum']+' to '+expected['Maximum'],
                          expected['Sign_changes'], expected['Maximum_relative_change_percent']]
        for cell, target in zip(actual[1:], expected_cells):
            def numbers(text):
                return re.findall(r'-?\d+(?:\.\d+)?', text.replace('−', '-').replace(',', ''))
            require(numbers(cell) == numbers(target), f"S4/{actual[0]}: {cell} differs from {target}.")
            checked += len(numbers(target))
    return checked


def stata_string(value):
    text = str(value).replace('\\', '/')
    require(not any(c in text for c in ['"', '`', '$', '\n', '\r']),
            'Stata paths must not contain quotes, macro markers, or line breaks.')
    return '"'+text+'"'


def full_run(args, run):
    require(args.data and args.stata, 'full requires --data and --stata.')
    data = Path(args.data).expanduser().resolve()
    require(data.is_file(), 'Linked input file not found.')
    exe = shutil.which(args.stata) or str(Path(args.stata).expanduser().resolve())
    require(Path(exe).is_file(), 'Stata executable not found.')
    vendor = ROOT.parent/'vendor'/'stata'
    require((vendor/'r/reghdfe.ado').is_file() and (vendor/'f/ftools.ado').is_file(),
            'Place treated_city_sensitivity beside the repository vendor folder.')
    shutil.copytree(vendor, run/'vendor/stata')
    (run/'code').mkdir()
    shutil.copy2(ROOT/'code/run_loto.do', run/'code/run_loto.do')
    launch = '\n'.join(['version 18.0', 'set more off'] +
                       [f'adopath ++ "vendor/stata/{name}"' for name in ['l', 'm', 'f', 'r']] +
                       ['do "code/run_loto.do" '+stata_string(data), ''])
    (run/'launch.do').write_text(launch, encoding='utf-8')
    command = [exe, '/e', 'do', 'launch.do'] if sys.platform == 'win32' else [exe, '-b', 'do', 'launch.do']
    with (run/'logs/stata_process.log').open('w') as log:
        process = subprocess.run(command, cwd=run, stdout=log, stderr=subprocess.STDOUT, check=False)
    logfile = run/'logs/treated_city_deletion.log'
    require(process.returncode == 0 and logfile.is_file(), 'Stata failed; inspect this run directory.')
    logtext = logfile.read_text(errors='replace')
    require(SUCCESS in logtext.splitlines(), 'Stata did not complete all fits; inspect the log.')
    return read_csv(run/'results/treated_city_deletion_raw.csv')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('mode', choices=['check', 'full'])
    parser.add_argument('--data', help='Authorized linked analysis_input.dta, not a raw CHARLS wave file')
    parser.add_argument('--stata', help='Licensed Stata 18 executable')
    parser.add_argument('--manuscript', help='Optionally check S4 in a DOCX manuscript')
    args = parser.parse_args()
    run = ROOT/'runs'/(args.mode+'_'+datetime.now(timezone.utc).strftime('%Y%m%dT%H%M%S_%fZ'))
    (run/'results').mkdir(parents=True)
    (run/'logs').mkdir()
    print('Output directory:', run, flush=True)
    report = {'status': 'failed', 'mode': args.mode, 'regressions_reestimated': args.mode == 'full'}
    try:
        reference = read_csv(ROOT/'reference_results/treated_city_deletion_raw.csv')
        rows = full_run(args, run) if args.mode == 'full' else reference
        report['raw_numeric_values_compared'] = compare(rows, reference, ['Candidate', 'OmittedCity'])
        summary = summarize(rows)
        report['summary_numeric_values_compared'] = compare(summary, read_csv(ROOT/'reference_results/deletion_summary.csv'), ['Candidate'])
        displays = display_rows(summary)
        write_csv(run/'results/deletion_summary.csv', summary)
        write_csv(run/'results/Table_S4.csv', displays)
        write_csv(run/'results/treated_city_deletions.csv', [r for r in rows if r['OmittedCity'] != 'Full'])
        report['packaged_word_numeric_entries_checked'] = check_word(ROOT/'tables/Supplementary_Table_S4_Treated_City_Deletion.docx', displays)
        if args.manuscript:
            report['manuscript_numeric_entries_checked'] = check_word(Path(args.manuscript).expanduser(), displays)
        report.update(status='passed', fits=66, deletions=60, candidates=6,
                      path_regressions_reestimated=132 if args.mode == 'full' else 0,
                      comparison_relative_tolerance=1e-10, comparison_absolute_tolerance=1e-14,
                      scope='Numeric reproduction of S4 and its underlying fits; not a test of the indirect association or a validation of causal identification.')
    except Exception as error:
        report['error'] = str(error)
        raise
    finally:
        (run/'validation.json').write_text(json.dumps(report, indent=2)+'\n', encoding='utf-8')
    print(json.dumps(report, indent=2))
    print('S4_REPRODUCTION_CHECK_PASSED')


if __name__ == '__main__':
    main()
