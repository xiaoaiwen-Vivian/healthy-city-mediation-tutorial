# Troubleshooting and direct execution

## Missing Python package

Install using the same Python executable used to run `run.py`: `python -m pip install -r requirements.txt`. The tested environment is Python 3.14.6, NumPy 2.4.6, pandas 3.0.3, SciPy 1.18.0 and openpyxl 3.1.5. Other versions may work but were not part of the full validation recorded here.

## Stata executable not found

Supply `--stata` with the executable, not the enclosing application folder. The package does not include Stata or its license. The tested macOS path is shown in the README. For manual use, first change to the package directory in Stata.

## Stata reports an error even though the shell exit status is zero

Inspect the run's `run_batch.log` and analytical logs. The runner requires `logs/stata_completed.ok`, so it will not report success just because the batch process returned zero. Fix the first Stata error, not subsequent missing-output messages.

## A Mata library is too new for the installed Stata

The provided libraries were tested with Stata 18. Recompiling boottest can be done from the package root with `do code/compile_boottest.do`. It creates a library inside the package's vendor directory and does not overwrite system packages. Then rerun in a fresh process. Do not silently substitute an old system boottest: older builds can misclassify newer reghdfe estimates as maximum-likelihood models.

If ftools needs compilation, first `do code/setup_stata.do`, then run `ftools, compile` in Stata. The supplied sources and helper commands are available in the vendor path. Recheck the dependency paths and numerical validation afterward. No result from an untested replacement is automatically treated as reproduced.

## Missing or different upstream inputs

`build-input` checks 56 exact source releases. Open `logs/upstream_inputs_verified.json` in that run to see which source is missing or different. Correct the input location or obtain the required release; changing the expected result or source checksum to suppress the error is not reproduction of the reported study. Upstream access conditions are in `DATA_ACCESS.md`.

## Sample sizes differ

Check source releases, urban/age eligibility, income and Social construction, outcome coding, missingness and city-year linkage. The sample rule is candidate-specific common observations. A six-candidate intersection is a different analysis. The program does not remove records to force the target counts.

## What to inspect after a successful run

`verification_report.json` records CSV comparisons, city-draw agreement between Stata and Python, exact resampling-schedule reproduction and BH checks. `results/tables/` contains manuscript-aligned numeric exports. `logs/` contains actual execution output. Floating-point comparisons use documented tolerances; statistical interpretation is a separate matter.

## Direct commands for experienced users

The wrapper creates isolated run folders. The equivalent sequence, executed from a separate working copy of the repository, is:

```bash
python code/case_python.py --data "/path/to/analysis_input.dta"
python code/fdr_python.py
python code/recalculate_intervals.py
```

Then in Stata:

```stata
do code/run_stata.do "/path/to/analysis_input.dta"
```

Then in Python:

```bash
python code/summarize_wild.py
python code/export_tables.py
python code/verify_results.py --reference reference_results --mode full-estimation
```

Direct scripts write their generated outputs under `results/`, so keep frozen comparisons in `reference_results/` and start with an empty results directory. The standard `run.py full` command does this automatically and is the recommended route.
