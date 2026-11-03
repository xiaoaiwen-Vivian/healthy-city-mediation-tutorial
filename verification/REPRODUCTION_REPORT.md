# Executed reproduction report

Validation date: 2026-11-03. This report records completed executions of the updated package. The original manuscript, source data and earlier package were not modified.

## Results of the executed checks

| Check | Result |
| --- | --- |
| Required source releases | All 56 files were present and matched the input manifest |
| Input construction | Rebuilt successfully from the locally available survey, harmonized and city sources |
| Full re-estimation | Python and Stata completed in a new run directory using that newly built input |
| Frozen reference comparisons | All 36 CSV files reproduced; no numerical differences at the loaded CSV precision |
| City pairs bootstrap | Six candidates × 2,000 draws reproduced independently in Stata and Python |
| Respondent pairs bootstrap | Six candidates × 2,000 draws reproduced in Python |
| Shared city schedule | Exact agreement: 2,000 rows × 94 city counts; each row sums to 94 |
| Common samples | Candidate-specific counts and path coefficients/products agree across implementations and resampling units |
| Candidate observation periods | All six reported Table 3 periods agree with the reconstructed input; Medical ends in 2018 |
| BH calculations | Five hypothesis-testing families and two descriptive groups, six candidates each; all 42 calculations verified against SciPy and Stata |
| Overall-policy fixed-effect sensitivity | Both specifications and both clustering choices reproduced |
| Wild cluster bootstrap | All 13 coefficient tests reproduced; 9,999 feasible replications per test |
| Current manuscript tables | 288 displayed numeric entries across Tables 2–5, 7–11 and S1; zero discrepancies |
| Aggregate-only entry point | `python run.py check --manuscript ...` completed successfully without participant data |
| Word revision handling | Four unit tests passed; tracked and accepted views return identical tables; a deliberately altered number was detected |
| Original analysis specifications | Estimation programs and all 36 frozen reference CSV files remain byte-identical to the earlier package |

The current Word manuscript contains eleven main tables plus S1. A deleted old table remains in its revision XML and is excluded by the checker. Tables 1 and 6 contain definitions; their presence is checked, but they are not counted among the ten numeric tables. Numeric verification does not certify manuscript prose, references, code snippets or page layout.

## Calculation and comparison boundaries

Full re-estimation started with an empty results directory. Frozen result files were read for comparison after estimation, not used as coefficient targets. The shared city resampling schedule is an intentional input to both bootstrap implementations. Candidate-specific common samples, all six candidates, fixed effects, controls, seeds and replication counts were retained.

Reference comparisons use relative tolerance 2×10^-7 and absolute tolerance 10^-10 for floating-point columns, with exact checks for counts and labels. Expected missing-value locations must agree. Stata/Python city draws use the same tolerance. Manuscript entries are compared at half the last displayed digit; the S1 `<0.001` display is checked as an inequality. Different platforms may produce small numerical differences within these tolerances.

WCB `Estimate_difference` and `SE_difference` are reparameterization diagnostics, not manuscript estimates; the Stata code checks their substantive equality. Confidence-limit display strings are not compared character by character, because their numeric endpoints are checked directly. The Social b-path WCB output has zero exceedances and is displayed as `<0.001`, not a population probability of zero.

The two bootstrap sign-tail groups remain descriptive. They are not interpreted by comparing their BH calculations with .05. The WCB supplement contains unadjusted coefficient tests; it does not test the nonlinear product a×b.

## Evidence files

- `full_reproduction.json`: fresh full-estimation comparisons.
- `aggregate_only_check.json`: no-participant-data recalculation checks.
- `manuscript_numeric_checks.csv` and `.json`: all 288 manuscript comparisons and summary.
- `sample_period_checks.csv`: observed survey years and Table 3 periods.
- `upstream_inputs_checked.json`: status of all 56 source inputs.
- `unchanged_analysis.json`: preservation of estimation programs and frozen results.
- `checker_tests.json`: revision-reader tests and the intentional-error check.
- `environment_and_scope.json`: software versions and scope.
- `manuscript_tables/`: all ten newly generated numeric table exports.
- `logs/`: fresh estimation and verification output. Public log copies replace the local home-directory prefix with `<LOCAL_HOME>`; statistical output is preserved.

## Access and applicability

The complete run used source releases already available locally; this was not a fresh download from the providers. CHARLS, harmonized files and the exact linked city sources are required for full re-estimation and are not redistributed. The available materials do not establish a public download or redistribution route for every compiled city input. `docs/DATA_ACCESS.md` identifies those conditions. The package alone supports aggregate recalculation, while complete regression re-estimation requires authorized inputs.

Computation was tested on macOS with Python 3.14 and Stata 18 MP. Windows/Linux operation, causal identification, mediator–outcome temporal ordering and exact small-treated-cluster inference are not established by reproduction. No public repository or code DOI was created by this update.
