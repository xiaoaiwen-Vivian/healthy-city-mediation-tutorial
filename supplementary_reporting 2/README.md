# Supplementary tables and sample reporting

This add-on supplies the calculations for **Supplementary Tables S2 and S3** and the sample-selection, missingness, follow-up, observation-span, and wave-specific outcome summaries in *A practical tutorial on mediation analysis with clustered data in health psychology*.

Place the entire `supplementary_reporting` directory in the root of the [main reproducibility repository](https://github.com/xiaoaiwen-Vivian/healthy-city-mediation-tutorial), beside its existing `run.py`, `code`, and `reference_results` directories. The add-on has its own entry point and reference results. It does not replace the main repository's files.

## What this adds

| Manuscript material | Calculation | Main output |
| --- | --- | --- |
| Table S2: characteristics of the primary complete sample | Overall and by eventual city policy group; mean and sample SD or count and percentage | `Table_S2_descriptives.csv` |
| Table S2: variable-specific missingness | Eligible person-waves before complete-case selection, overall and by policy group | `Table_S2_missingness.csv` |
| Table S3: crude and adjusted coefficients | One overall policy coefficient and both component paths for each of six candidates, on identical observations within each comparison | `Table_S3_crude_adjusted.csv` |
| Step 1: sequential selection | Interviews, unique respondents, and subsequent exclusions by policy group | `selection_by_group.csv` |
| Step 1: follow-up | Interview participation, eligibility and complete observations among respondents eligible in 2011, by policy group | `initial_cohort_followup_by_group.csv` |
| Step 1: observation coverage | Mean observed waves, first-to-last observation span, and one-wave/five-wave counts, by policy group | `observed_waves_and_span_by_group.csv` |
| Step 1: outcome by survey year | Counts, means and SDs by policy group | `outcome_by_wave.csv` |

`code/export_tables.py` also creates formatted `Table_S2_display.csv`, `Table_S3_display.csv`, and `sample_reporting.txt`. CSV files are computational outputs, not additional supplementary tables to insert into the manuscript.

## Install

The add-on was tested with Python 3.12.10, NumPy 2.4.6, pandas 3.0.3 and SciPy 1.17.1 on macOS. Independent calculations use licensed Stata 18 and the Stata dependencies already included in the main repository. No participant data or proprietary source workbooks are distributed here.

From the main repository directory, preferably in a separate Python virtual environment:

```bash
python -m pip install -r supplementary_reporting/requirements.txt
```

The copied `code/case_core.py` retains the main repository's sample preparation and city/year model implementation. This add-on does not introduce new sample definitions, mediation models, bootstrap methods or multiple-testing families.

## Run without participant data

```bash
python supplementary_reporting/run.py check
```

This reads the supplied aggregate reference results and regenerates the two display tables and numerical reporting text. It **does not** reconstruct samples, refit regressions, or independently verify the reference estimates from participant data. An optional manuscript check compares its displayed S2/S3 numbers with those aggregate results:

```bash
python supplementary_reporting/run.py check --manuscript "/path/to/manuscript.docx"
```

The manuscript is read only. Tracked insertions are included and tracked deletions excluded when extracting tables. The check covers table values, denominators and available-n notes; it does not certify every prose statement, the references or page layout.

## Recalculate from authorized study data

First run the main repository's existing upstream preparation with the required CHARLS survey/harmonized data and city sources:

```bash
python run.py build-input --config "/path/to/config.upstream.local.do" --stata "/path/to/stata-mp"
```

Use the resulting `runs/build-input_...` directory below:

```bash
python supplementary_reporting/run.py full --build-dir "/path/to/repository/runs/build-input_..."
```

For the independent Stata calculation and a read-only manuscript check:

```bash
python supplementary_reporting/run.py full --build-dir "/path/to/repository/runs/build-input_..." --stata "/path/to/stata-mp" --manuscript "/path/to/manuscript.docx"
```

When this add-on is outside the main repository, add `--repo "/path/to/main/repository"` for the Stata dependencies. `full` calculates the new reporting outputs and S3 coefficient comparisons; it does not rerun the main manuscript's bootstrap analyses. Those remain available through the main `run.py full` entry point.

The required build outputs are:

```text
data/analysis_input.dta       Linked input used by the existing analysis
data/charls.dta               Five-wave survey panel used to count interview participation
temp/panel_merged.dta         Survey panel with policy/city information before sequential exclusions
temp/city_yearbook_clean.dta  City/year keys for the yearbook linkage
temp/pm25_city_year.dta       City/year keys for the PM2.5 linkage
```

A linked analysis input alone cannot recover all earlier screening stages or the full 2011 cohort's subsequent interviews. Retain these intermediate outputs from `build-input`. Obtain the upstream sources through the access conditions in the main repository's `docs/DATA_ACCESS.md`; access to CHARLS alone does not supply the city sources. Do not upload these participant-level inputs or private configuration files to GitHub.

## Samples and statistical definitions

- The eligible denominator is 34,228 person-waves: 4,438 from treated cities and 29,790 from untreated cities. This is the denominator for variable-specific missingness, not for the complete-sample descriptive columns.
- The primary complete sample is 16,661 person-waves from 7,995 respondents: 2,135 observations from 1,029 respondents in treated cities and 14,526 from 6,966 respondents in untreated cities. Descriptions are unweighted; repeated observations contribute repeatedly.
- S2 uses available candidate measurements within this primary sample. SO2, Medical and Social therefore have their own available denominators. Missingness can overlap across variables. The Social recoding is inherited from the main upstream preparation; this add-on does not alter it.
- Each candidate in S3 retains its existing common sample: Green 16,661; Road 16,661; SO2 15,430; Medical 11,141; PM25 16,661; Social 16,660. The crude and adjusted comparison uses exactly the same observations for the corresponding candidate. It is not one complete-case intersection across all six indicators.
- Crude models contain an intercept and policy exposure. The crude b-path model additionally includes the candidate. Adjusted models contain the same 13 controls and city and survey-year fixed effects as the main analysis. All displayed S3 intervals use city-clustered standard errors and a t critical value with 93 degrees of freedom. They are unadjusted for multiple comparisons and concern coefficients, not the product a×b.
- The initial follow-up cohort comprises urban respondents eligible in 2011, classified by eventual policy-group status. Interview participation uses the nominal survey wave, so a late calendar-year interview can count as an interview even when excluded by an analysis calendar-year rule. An absent wave is not automatically classified as death, refusal or permanent withdrawal.
- Observation span is last minus first observed year. It equals zero for one-wave respondents and is not continuously observed person-time. No new imputation or attrition weighting is introduced.

## Programs and results

`code/compute_tables.py` computes S2, S3 and overall reporting summaries. `code/compute_sample_flow.py` computes policy-group selection, initial-cohort follow-up and observation coverage. `code/tables_stata.do` independently calculates S2/S3 with Stata. `code/verify_stata.py` compares those calculations with Python. `code/check_manuscript.py` checks displayed S2/S3 values.

Every run creates a new `supplementary_reporting/runs/<mode>_<timestamp>` directory containing `results`, `logs`, and `verification`. `--out` can specify a different new directory. Neither inputs nor `reference_results` are overwritten. A full run succeeds only after the numeric checks pass; a successful Stata process exit without its completion marker is insufficient.

Success markers are `SUPPLEMENTARY_REPORTING_CHECK_PASSED` for aggregate-only checks and `SUPPLEMENTARY_REPORTING_FULL_PASSED` for recalculation from data. The optional Stata cross-check and manuscript check are recorded separately in `status.json`.

The `verification` directory shipped with this add-on records the executed validation and its scope. Reproduction of the calculations does not establish causal ordering or remove missing-data selection bias.
