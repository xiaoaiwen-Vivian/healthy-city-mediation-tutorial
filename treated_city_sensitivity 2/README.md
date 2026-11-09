# Sensitivity to individual treated cities: Supplementary Table S4

Companion to **A practical tutorial on mediation analysis with clustered data in health psychology**, by Xiaoai Wen and Chun-Chieh Hu.

This add-on reproduces Supplementary Table S4. It fits each candidate's a and b paths on its full common sample, then repeats both regressions after omitting each of the ten treated cities in turn. The six full-sample fits and 60 deletion fits produce 132 path regressions. All six candidates and all ten deletions are retained.

Place this directory at the repository root, beside `code`, `vendor`, and `supplementary_reporting`. It has a separate entry point and README; the existing root `run.py` and the S2/S3 add-on remain unchanged.

## Run from the repository root

Python 3.10 or later is sufficient for this add-on; its Python program uses only the standard library. The tested execution used Python 3.12.10 and Stata/MP 18 on macOS. Full estimation loads reghdfe 6.13.1 and ftools 2.50.0 from the repository's existing `vendor/stata` directory. A Windows launch branch is included but has not been tested.

**Without individual data:** recalculate the S4 summary from the supplied aggregate estimates and check the editable Word table.

```bash
python treated_city_sensitivity/run.py check
```

This checks the saved results; it does not re-estimate regressions. An optional manuscript comparison checks S4's 42 displayed numeric entries, including the ten-deletion denominators:

```bash
python treated_city_sensitivity/run.py check --manuscript "/path/to/revised_manuscript.docx"
```

**With authorized linked data and licensed Stata:** re-estimate the regressions, compare all numeric fields with the supplied reference results, and rebuild S4's summary.

```bash
python treated_city_sensitivity/run.py full --data "/path/to/analysis_input.dta" --stata "/path/to/stata-mp"
```

The optional `--manuscript` argument also works with `full`. On macOS, an example executable location is `/Applications/Stata/StataMP.app/Contents/MacOS/stata-mp`; use the location of your installation.

Each invocation creates a new `treated_city_sensitivity/runs/<mode>_<timestamp>/` directory. Successful execution prints `S4_REPRODUCTION_CHECK_PASSED` and writes `validation.json`. Full mode also writes the Stata log and the newly estimated CSV. The supplied reference results and input dataset are not overwritten. The Word comparison checks table numbers, not the manuscript's prose or layout.

## Required input and sample

The input is the **linked analysis dataset** produced by the main repository's `build-input` procedure. It is not a newly downloaded CHARLS wave file. Follow the root README and [data-access instructions](../docs/DATA_ACCESS.md) to obtain the authorized survey and city sources and construct `analysis_input.dta`. This add-on does not repeat the upstream preparation and does not redistribute respondent records.

The analysis uses urban respondents aged at least 45 and the same policy indicator, outcome and 13 controls as the main analysis. The policy indicator is `treat * (iwy >= 2017)`. The outcome is `rgoingl`, the reduced-activation item score. For each candidate, its full-sample outcome regression defines the common complete-case observations used for both paths. A deletion removes all observations in one treated city from this fixed common sample. This is a common sample **within each candidate**, not a pooled complete-case sample across all six candidates.

| Candidate | Input variable | Full-sample observations |
| --- | --- | ---: |
| Green | `GreenCoverageRateBD` | 16,661 |
| Road | `RoadSurAreaPerCap` | 16,661 |
| SO2 | `工业二氧化硫排放量吨` (industrial sulfur dioxide emissions in metric tons) | 15,430 |
| Medical | `hosper` | 11,141 |
| PM2.5 | `pm` | 16,661 |
| Social | `act_12` | 16,660 |

Medical's observations cover 2011–2018; the other candidates cover the available waves in 2011–2020. The controls are `gender marry log_real_inc_per rwork rural2 edu hchild retire adlab_c smoken drinkl srh age`. Both path regressions are unweighted, absorb city and survey-year fixed effects, and use city-clustered standard errors. Individual clustering is used in the initial sample-defining regressions to preserve the main analysis specification; the deletion fits themselves use city clustering.

Full samples contain 94 cities: ten treated and 84 untreated. Each deletion contains 93 cities: nine treated and the same 84 untreated cities. `T01`–`T10` are consistent aliases based on the original sorted city order; their city-name crosswalk is not distributed. Assertions check the published samples and successful estimation; they do not alter observations or coefficients to obtain a target result.

## What S4 reports

For each candidate, `ab` is the product of the fitted a and b coefficients. The deletion range contains the smallest and largest of the ten deletion products. A sign change is counted when a deletion product has the opposite sign to its full-sample product. The maximum relative change is

```text
100 * max(abs(ab_without_city - ab_full)) / abs(ab_full)
```

Calculations use unrounded estimates. Products are displayed to six decimal places and relative changes to one decimal place. Relative changes can exceed 100%, particularly when the full-sample product is close to zero. They are undefined if that product is exactly zero; the program reports an error in that case rather than substituting a value.

The deletion range measures sensitivity to individual treated cities. It is **not a confidence interval or a test of the indirect association**. Stable signs do not establish the validity of inference with few treated cities. The conventional component-path p values in the detailed output are not wild-bootstrap or product-test p values. This add-on does not rerun bootstrap or BH calculations; those remain in the main analysis.

## Files

| File | Purpose |
| --- | --- |
| `code/run_loto.do` | Stata sample preparation and all 132 path regressions |
| `run.py` | Run Stata, calculate S4 summaries, compare outputs and check Word table numbers |
| `reference_results/treated_city_deletion_raw.csv` | Six full-sample and 60 deletion estimates, counts and conventional path statistics |
| `reference_results/deletion_summary.csv` | Unrounded summaries for all six candidates |
| `tables/Supplementary_Table_S4_Treated_City_Deletion.docx` | Editable S4 table and notes |
| `verification/treated_city_deletion.log` | Executed Stata log; machine-specific directory prefixes are replaced as documented |
| `verification/check_validation.json` | Executed check-mode results |
| `verification/full_validation.json` | Executed full-estimation and manuscript comparison results |
| `verification/RUN_REPORT.md` | Scope and outcome of the package checks |

Detailed output columns are defined in [OUTPUTS.md](OUTPUTS.md). The `runs/` directory is generated locally and excluded from the upload package. Its launch files may contain private local input paths; do not upload it.

## Methodological reference

MacKinnon JG, Nielsen MØ, Webb MD. Cluster-robust inference: A guide to empirical practice. *J Econom.* 2023;232(2):272–299. doi:10.1016/j.jeconom.2022.04.001. Section 3.4 discusses cluster leverage and influence. The present code estimates the deletion regressions directly with `reghdfe`.
