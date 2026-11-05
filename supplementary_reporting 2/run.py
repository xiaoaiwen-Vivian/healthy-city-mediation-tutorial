"""Reproduce Supplementary Tables S2/S3 and the sample-reporting summaries."""
from pathlib import Path
import argparse
import datetime
import hashlib
import json
import os
import shutil
import subprocess
import sys

ROOT = Path(__file__).resolve().parent
BUILD_INPUTS = ['data/analysis_input.dta', 'data/charls.dta',
                'temp/panel_merged.dta', 'temp/city_yearbook_clean.dta',
                'temp/pm25_city_year.dta']

def digest(path):
    h = hashlib.sha256()
    with path.open('rb') as f:
        for block in iter(lambda: f.read(1024*1024), b''): h.update(block)
    return h.hexdigest()

def execute(command, cwd, logfile):
    env = dict(os.environ, OPENBLAS_NUM_THREADS='1', MKL_NUM_THREADS='1',
               OMP_NUM_THREADS='1', VECLIB_MAXIMUM_THREADS='1')
    with logfile.open('w', encoding='utf-8') as log:
        result = subprocess.run(command, cwd=cwd, stdout=log, stderr=subprocess.STDOUT, env=env)
    if result.returncode:
        raise RuntimeError(f'Calculation failed; inspect {logfile}')

def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('mode', choices=['check', 'full'])
    p.add_argument('--build-dir', type=Path, help='Completed runs/build-input_* directory from the main repository')
    p.add_argument('--stata', type=Path, help='Optional licensed Stata executable for independent S2/S3 calculation')
    p.add_argument('--repo', type=Path, default=ROOT.parent, help='Main repository containing code/setup_stata.do and vendor/')
    p.add_argument('--manuscript', type=Path, help='Optional DOCX for read-only checks of S2/S3')
    p.add_argument('--out', type=Path, help='New output directory; must not already exist')
    a = p.parse_args()
    if a.mode == 'full' and not a.build_dir: p.error('full requires --build-dir')
    if a.mode == 'check' and (a.build_dir or a.stata): p.error('Use full for input data or Stata estimation')
    build = a.build_dir.expanduser().resolve() if a.build_dir else None
    if build:
        for name in BUILD_INPUTS:
            if not (build/name).is_file(): raise FileNotFoundError(f'Missing build output: {name}')
    repo = a.repo.expanduser().resolve()
    if a.stata and not (repo/'code/setup_stata.do').is_file():
        raise FileNotFoundError('Set --repo to the main repository containing code/setup_stata.do and vendor/')
    stamp = datetime.datetime.now().strftime('%Y%m%d_%H%M%S_%f')
    out = (a.out.expanduser() if a.out else ROOT/'runs'/f'{a.mode}_{stamp}').resolve()
    out.mkdir(parents=True, exist_ok=False)
    for name in ['results', 'logs', 'verification', 'stata']: (out/name).mkdir()
    status = {'mode': a.mode, 'completed': False, 'input_data_reestimated': a.mode == 'full',
              'independent_stata_requested': bool(a.stata), 'python': sys.version.split()[0]}
    (out/'status.json').write_text(json.dumps(status, indent=2)+'\n')
    initial = {name: digest(build/name) for name in BUILD_INPUTS} if build else {}
    def py(script, *args):
        print('Running '+script, flush=True)
        execute([sys.executable, str(ROOT/'code'/script), *map(str,args)], out, out/'logs'/(script+'.log'))
    if a.mode == 'full':
        py('compute_tables.py', '--build-dir', build, '--out', out/'results')
        py('compute_sample_flow.py', '--build-dir', build, '--out', out/'results')
        py('verify_reference.py', '--results', out/'results', '--reference', ROOT/'reference_results', '--out', out/'verification')
    else:
        shutil.copytree(ROOT/'reference_results', out/'results', dirs_exist_ok=True)
    py('export_tables.py', '--results', out/'results')
    for name in ['Table_S2_display.csv', 'Table_S3_display.csv', 'sample_reporting.txt']:
        if (out/'results'/name).read_bytes() != (ROOT/'tables'/name).read_bytes():
            raise RuntimeError(f'Formatted output differs from the supplied result: {name}')
    status['formatted_outputs_verified'] = True
    if a.stata:
        stata = a.stata.expanduser().resolve()
        if not stata.is_file(): raise FileNotFoundError(stata)
        paths = [ROOT/'code/tables_stata.do', build/'data/analysis_input.dta', repo, out/'stata']
        if any(any(c in str(path) for c in ['"', '`', '$', '\n']) for path in paths):
            raise ValueError('Stata paths must not contain quotes, backticks, dollar signs or line breaks')
        command = 'do ' + ' '.join('"'+path.as_posix()+'"' for path in paths)
        driver = out/'stata/run_tables.do'
        driver.write_text(command+'\nexit, clear\n')
        print('Running independent Stata calculations', flush=True)
        execute([str(stata), '/e' if os.name == 'nt' else '-b', 'do', driver.name], out/'stata', out/'logs/stata_console.log')
        if not (out/'stata/independent_stata_completed.ok').is_file():
            raise RuntimeError('Stata did not reach its completion marker; inspect the Stata logs')
        py('verify_stata.py', '--results', out/'results', '--stata-results', out/'stata', '--out', out/'verification')
        status['independent_stata_verified'] = True
    if a.manuscript:
        manuscript = a.manuscript.expanduser().resolve()
        before = digest(manuscript)
        py('check_manuscript.py', '--docx', manuscript, '--results', out/'results', '--out', out/'verification')
        if digest(manuscript) != before: raise RuntimeError('Manuscript changed during checking')
        status['manuscript_S2_S3_verified'] = True
    if build:
        if initial != {name: digest(build/name) for name in BUILD_INPUTS}:
            raise RuntimeError('A source file changed during calculation')
        status['inputs_unchanged'] = True
    status['completed'] = True
    (out/'status.json').write_text(json.dumps(status, indent=2)+'\n')
    print('SUPPLEMENTARY_REPORTING_CHECK_PASSED' if a.mode == 'check' else 'SUPPLEMENTARY_REPORTING_FULL_PASSED')
    print('Output directory:', out)
    if a.mode == 'check': print('Aggregate-only check: no regressions, sample selection or follow-up were recalculated from participant records.')

if __name__ == '__main__': main()
