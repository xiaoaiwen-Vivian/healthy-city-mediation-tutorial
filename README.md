# Mediation analysis with clustered data: Healthy City reproducibility materials

Companion to **A practical tutorial on mediation analysis with clustered data in health psychology**, by Xiaoai Wen and Chun-Chieh Hu. This repository contains the Stata and Python implementation, shared city resampling schedule, saved bootstrap estimates, and aggregate reference results used in the tutorial. The manuscript preprint DOI is [10.21203/rs.3.rs-11370584/v1](https://doi.org/10.21203/rs.3.rs-11370584/v1); this is not a DOI for the code release.

This update follows the revised manuscript's Tables 1–11 and Supplementary Table S1. Table 8 reports component-path BH adjustments; Tables 9 and 10 contain descriptive bootstrap calculations. See [the change record](CHANGELOG.md) and [executed validation](verification/REPRODUCTION_REPORT.md).

## Start here

| Your access | What you can run | Command |
| --- | --- | --- |
| Code and supplied aggregate outputs | Recalculate percentile and BC intervals, sign-tail summaries and BH adjustments; verify the shared resampling schedule | `python run.py check` |
| Authorized linked analysis input | Re-estimate all tutorial models and bootstrap draws in Python and Stata | `python run.py full --data "/path/to/analysis_input.dta" --stata "/path/to/stata-mp"` |
| Required upstream survey and city sources | Reconstruct the linked input, then run the full analysis | See **Build the input** below |

**The package does not contain respondent records or the restricted input dataset.** CHARLS access alone does not provide all the linked city workbooks. [Data access and source requirements](docs/DATA_ACCESS.md) describes what is supplied and what must be obtained separately. `check` is useful without access to individual data, but is not a re-estimation of the regressions.

## Install and run

Use Python 3.14 and licensed Stata 18 for the tested setup. From this repository's directory:

```bash
python -m pip install -r requirements.txt
python run.py check
```

For complete estimation:

```bash
python run.py full --data "/absolute/path/to/analysis_input.dta" --stata "/absolute/path/to/stata-mp"
```

Authors can add `--manuscript "/absolute/path/to/manuscript.docx"` to `full` or `check` to verify the manuscript's numeric tables after calculation. The checker reads the current text of tracked changes, including insertions and excluding deleted text and rows, without editing the Word file. It identifies Tables 1–11 and S1 by caption and checks 288 displayed numeric entries in the current manuscript. Tables 1 and 6 contain definitions, not estimated results. The checker does not certify prose, references, code snippets or page layout.

On macOS with the installation used for testing, the Stata executable is `/Applications/Stata/StataMP.app/Contents/MacOS/stata-mp`. Supply your own executable path if different. The runner includes a Windows batch-command branch, but the delivered release was tested on macOS, not on Windows or Linux.

Each invocation creates a new `runs/<mode>_<timestamp>/` directory. The input and `reference_results/` are never overwritten. New estimates go into that run's `results/`; execution logs go into `logs/`. Success requires **`REPRODUCTION_CHECK_PASSED`** and a passed verification report, not merely Stata's process exit code. Full estimation must also produce the Python and Stata completion markers.

The runner pins BLAS computational threads to one per process to keep small repeated fits efficient. This affects computational scheduling, not statistical weights or the model.

## The common-sample specification

The main models retain **city and survey-year fixed effects**, all 13 controls and no survey weights. For each candidate, the outcome regression containing the policy indicator, that candidate and the controls defines its common complete-observation sample. Its a path, b path, Sobel calculation, city bootstrap and respondent bootstrap then use those same observations. The respondent-bootstrap code explicitly receives that candidate's common rows. Stata checks that neither path drops any of the retained rows.

**This is one common sample per candidate, not the intersection of all six candidates.** Earlier available-sample pathway regressions are not used to produce the current tables.

| Candidate | Observations | Respondents | Cities | Treated cities |
| --- | --- | --- | --- | --- |
| Green | 16,661 | 7,995 | 94 | 10 |
| Road | 16,661 | 7,995 | 94 | 10 |
| SO2 | 15,430 | 7,673 | 94 | 10 |
| Medical | 11,141 | 6,353 | 94 | 10 |
| PM25 | 16,661 | 7,995 | 94 | 10 |
| Social | 16,660 | 7,995 | 94 | 10 |

Medical's usable years end in 2018. A separate **overall-policy** sensitivity model uses respondent and year fixed effects, with individual and city clustering; it has 13,579 observations after singleton removal. No respondent-fixed-effects mediation analysis is claimed. See [model and variable definitions](docs/MODELS_AND_VARIABLES.md).

## What is implemented

- Three regression steps and common-sample component paths, with individual and city clustering.
- City-cluster Sobel calculations for all six indirect products.
- 2,000 city pairs-bootstrap draws for each candidate, implemented independently in Stata/Mata and Python using the supplied shared draw-count matrix.
- 2,000 respondent pairs-bootstrap draws for each candidate, implemented in Python, with city means recomputed within each draw. There is no separately implemented Stata respondent bootstrap.
- Percentile and bias-corrected **BC**, not BCa, intervals; five six-candidate hypothesis-testing families and two six-candidate descriptive BH groups.
- City/year and respondent/year overall-policy models, each under both clustering choices.
- Supplemental restricted wild cluster bootstrap-t tests: 9,999 Rademacher draws for the overall coefficient and all six a and six b coefficients. These are separate from the 2,000-draw indirect-product bootstrap. They do not test a×b. All 13 outputs are retained under `reference_results/wild/`.

The two bootstrap-sign groups use sign-tail **summaries**, whose calibration as null-hypothesis p values has not been established. Their BH calculations are descriptive and must not be compared with .05 to make significance decisions. Outputs are separated into `hypothesis_test_bh.csv` (30 adjustments from five testing families) and `descriptive_bh.csv` (12 descriptive calculations). The combined `all_bh_families.csv` retains the previous file interface for reference comparisons and adds a `Use` column to distinguish them. The Sobel, component-path and WCB calculations are labeled separately. Percentile and BC intervals are not multiplicity-adjusted. [Inference definitions](docs/INFERENCE.md) documents every family and calculation.

## Shared resampling and expected outputs

`code/shared_draw_counts_94.csv` contains 2,000 rows and 94 city-frequency columns. Each row sums to 94. It uses NumPy PCG64, seed 2025, and the study's sorted city order, without stratifying treated and control cities. Both implementations read this same file. The verification program regenerates it and checks exact equality. `code/generate_shared_draws.py` can write the same schedule to a new file.

Individual resampling resets `numpy.random.default_rng(2025)` for each candidate, draws multinomial frequencies over sorted respondent IDs, and keeps each person's repeated observations together. Its complete implementation and resulting 2,000 coefficient/product rows per candidate are supplied; it does not use the city count matrix.

`reference_results/` contains unchanged frozen aggregate outputs and every saved bootstrap coefficient/product. `results/tables/` in a completed run contains ten exported numeric tables: Tables 2–5, 7–11 and S1. Tables 1 and 6 describe variables and test families. Table S1 contains all 13 unadjusted WCB coefficient tests. The additional WCB adjustment calculations remain in `results/wild/wild_cluster_adjusted.csv` and are not the p values displayed in S1. [Table map](docs/TABLE_MAP.md) identifies the input and script for each table.

For example, Green's common-sample a=0.378438, b=−0.007406 and ab=−0.002803; Social's a=0.062869, b=−0.041043 and ab=−0.002580. The overall city/year policy coefficient is −0.086679, with conventional city-cluster p=0.010184 and supplemental WCB p=0.020002. Verification uses full-precision results and explicit numerical tolerances; these displayed values are not used to fit models or select records.

## Build the input

1. Obtain all 56 external sources listed in [the source manifest](verification/INPUT_MANIFEST.json) and [data-access notes](docs/DATA_ACCESS.md).
2. Copy `config.upstream.example.do` to a private local configuration file. Enter the actual source locations. Keep it out of the public repository.
3. Run:

```bash
python run.py build-input --config "/path/to/config.upstream.local.do" --stata "/path/to/stata-mp"
```

4. Use the printed path to `runs/build-input_.../data/analysis_input.dta` as `--data` in the full command above.

The upstream script includes the survey preparation, harmonized-variable use and city linkage needed to build this analysis input. It does not rerun the unrelated empirical analyses from the separate Healthy City paper. Harmonized CHARLS releases are inputs obtained from their provider; this code does not reconstruct the provider's entire harmonization project.

## Verification and portability

The validation workflow reconstructs the input from the source files, re-estimates the models, and compares fresh estimates and every saved bootstrap draw with the frozen outputs. [Validation record](verification/REPRODUCTION_REPORT.md) records the executed checks, counts, tolerances and remaining access conditions, including comparison with the manuscript's displayed table values.

Stata dependencies are included under `vendor/` with original attribution: reghdfe 6.13.1, ftools 2.50.0, sreshape, and boottest 4.5.5. They are loaded from the run directory, not installed over system packages. boottest's Mata library was compiled under Stata 18. [Troubleshooting](docs/TROUBLESHOOTING.md) covers dependency compilation and common errors.

This is research code and a reproducible analysis workflow. Computational reproduction does not independently establish causal identification, mediator–outcome temporal ordering, or finite-cluster test calibration.

## Files and publication

```text
run.py                         Three entry points: check, full, build-input
code/                          Complete analysis and verification programs
code/upstream/                 Survey preparation and city linkage
reference_results/             Frozen aggregate results and bootstrap draws
verification/                  Source manifest and executed verification records
docs/                          Inputs, models, table map and GitHub instructions
vendor/                        Required third-party Stata commands
requirements.txt               Tested Python library versions
config.upstream.example.do     Template for authorized local input locations
tests/                         Tests of revision-aware manuscript table reading
```

See [GitHub upload instructions in Chinese](docs/GITHUB_UPLOAD_ZH.md). Create a tagged release matching the manuscript and cite its actual release URL or archival DOI. This review copy has not been uploaded by the packaging process, and no repository URL or code DOI has been invented.
