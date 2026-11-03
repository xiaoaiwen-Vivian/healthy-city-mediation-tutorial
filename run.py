"""Portable entry point. Never writes to input data or reference_results.

python run.py check
python run.py full --data /path/to/analysis_input.dta --stata /path/to/stata-mp
python run.py build-input --config /path/to/config.local.do --stata /path/to/stata-mp
"""
from pathlib import Path
import argparse
import datetime
import json
import os
import shutil
import subprocess
import sys
import time

ROOT = Path(__file__).resolve().parent

def run_command(command, cwd, logfile):
    print("Running:", Path(command[1]).name if len(command)>1 else command[0], flush=True)
    start = time.monotonic()
    last_update = start
    env = dict(os.environ, OPENBLAS_NUM_THREADS="1", MKL_NUM_THREADS="1", OMP_NUM_THREADS="1", VECLIB_MAXIMUM_THREADS="1")
    with logfile.open("w", encoding="utf-8") as stream:
        proc = subprocess.Popen(command, cwd=cwd, stdout=stream, stderr=subprocess.STDOUT, env=env)
        while proc.poll() is None:
            time.sleep(5)
            if time.monotonic()-last_update >= 30:
                print(f"  Still running ({int(time.monotonic()-start)} seconds); log: {logfile.name}", flush=True)
                last_update = time.monotonic()
    if proc.returncode:
        raise RuntimeError(f"Command failed with exit code {proc.returncode}; inspect {logfile}")

def stata_executable(value):
    if value:
        p = Path(value).expanduser().resolve()
        if not p.is_file(): raise FileNotFoundError(p)
        return str(p)
    for name in ["stata-mp", "stata-se", "stata", "StataMP-64.exe", "StataSE-64.exe"]:
        p = shutil.which(name)
        if p: return p
    raise RuntimeError("Supply --stata with the executable path. Stata is licensed software and is not included.")

def stata_batch(executable, dofile):
    return [executable, "/e" if os.name == "nt" else "-b", "do", dofile]

def main():
    p = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    p.add_argument("mode", choices=["check", "full", "build-input"])
    p.add_argument("--data")
    p.add_argument("--stata")
    p.add_argument("--config")
    p.add_argument("--manuscript", help="Optional Word manuscript: verify Tables 2-5, 7-11 and S1 without changing it")
    a = p.parse_args()
    if a.mode=="full" and not a.data: p.error("full requires --data")
    if a.mode=="build-input" and not a.config: p.error("build-input requires --config")
    if a.mode=="build-input" and a.manuscript: p.error("Use --manuscript with check or full, after estimation")
    stamp = datetime.datetime.now().strftime("%Y%m%d_%H%M%S_%f")
    run = ROOT / "runs" / (a.mode+"_"+stamp)
    run.mkdir(parents=True, exist_ok=False)
    for name in ["code", "vendor", "verification"]:
        shutil.copytree(ROOT/name, run/name)
    for name in ["logs", "results", "results/stata", "results/python", "results/wild"]:
        (run/name).mkdir(parents=True, exist_ok=True)
    config = {"mode":a.mode,"started":datetime.datetime.now().isoformat(),"python":sys.version,"completed":False}
    (run/"run_status.json").write_text(json.dumps(config,indent=2))
    print("Run directory:",run,flush=True)
    if a.mode == "check":
        shutil.copytree(ROOT/"reference_results",run/"results",dirs_exist_ok=True)
        for script in ["recalculate_intervals.py", "fdr_python.py", "summarize_wild.py", "export_tables.py"]:
            run_command([sys.executable,"code/"+script],run,run/"logs"/(script+".log"))
        run_command([sys.executable,"code/verify_results.py","--reference",str(ROOT/"reference_results"),"--mode","aggregate-only"],run,run/"logs/verification.log")
    elif a.mode == "full":
        data = Path(a.data).expanduser().resolve()
        if not data.is_file(): raise FileNotFoundError(data)
        stata = stata_executable(a.stata)
        run_command([sys.executable,"code/case_python.py","--data",str(data)],run,run/"logs/python_estimation.log")
        if "PYTHON_ESTIMATION_COMPLETED" not in (run/"logs/python_estimation.log").read_text():
            raise RuntimeError("Python did not reach its completion marker")
        for script in ["fdr_python.py","recalculate_intervals.py"]:
            run_command([sys.executable,"code/"+script],run,run/"logs"/(script+".log"))
        if '"' in str(data): raise ValueError('The Stata input path must not contain a double quote')
        (run/"run_batch.do").write_text(f'do code/run_stata.do "{data.as_posix()}"\nexit, clear\n')
        run_command(stata_batch(stata,"run_batch.do"),run,run/"logs/stata_console.log")
        if not (run/"logs/stata_completed.ok").is_file():
            raise RuntimeError(f"Stata did not complete; inspect {run/'run_batch.log'}")
        for script in ["summarize_wild.py","export_tables.py"]:
            run_command([sys.executable,"code/"+script],run,run/"logs"/(script+".log"))
        run_command([sys.executable,"code/verify_results.py","--reference",str(ROOT/"reference_results"),"--mode","full-estimation"],run,run/"logs/verification.log")
    else:
        cfg = Path(a.config).expanduser().resolve()
        if not cfg.is_file(): raise FileNotFoundError(cfg)
        stata = stata_executable(a.stata)
        shutil.copyfile(cfg, run/"config.local.do")
        py = Path(sys.executable).as_posix()
        (run/"run_batch.do").write_text(f'do code/upstream/driver.do "{py}"\nexit, clear\n')
        run_command(stata_batch(stata,"run_batch.do"),run,run/"logs/stata_console.log")
        if not (run/"logs/input_build_completed.ok").is_file():
            raise RuntimeError(f"Input construction did not complete; inspect {run/'run_batch.log'}")
        run_command([sys.executable,"code/upstream/check_built_input.py",str(run/"data/analysis_input.dta")],run,run/"logs/input_validation.log")
    if a.manuscript:
        manuscript = Path(a.manuscript).expanduser().resolve()
        if not manuscript.is_file(): raise FileNotFoundError(manuscript)
        run_command([sys.executable,"code/check_manuscript_tables.py", "--docx",str(manuscript),
                     "--results",str(run/"results"),"--output",str(run/"manuscript_numeric_checks.csv")],
                    run,run/"logs/manuscript_verification.log")
        config["manuscript_tables_verified"] = True
    config["completed"] = True
    config["finished"] = datetime.datetime.now().isoformat()
    (run/"run_status.json").write_text(json.dumps(config,indent=2)+"\n")
    print("REPRODUCTION_CHECK_PASSED", flush=True)
    print("Run directory:",run,flush=True)
    if a.mode=="build-input": print("Linked input:",run/"data/analysis_input.dta",flush=True)

if __name__=="__main__": main()
