# Executed reproduction checks

The add-on's `check` and `full` entry points were executed on November 9, 2026. Both completed with `S4_REPRODUCTION_CHECK_PASSED`. The full execution used the authorized linked study input and the repository's vendored Stata dependencies. No respondent records are distributed.

## Results

- Full execution re-estimated 132 path regressions: two paths for each of six full common samples and 60 treated-city deletion samples.
- All 1,320 numeric fields in the 66 fitted-result rows matched the supplied detailed reference results within relative tolerance 1e-10 and absolute tolerance 1e-14.
- All 102 numeric fields in the six summary rows matched the reference summaries within the same tolerance.
- All 42 displayed numeric entries in both the packaged Word table and S4 of the revised manuscript matched the recomputed summaries at the displayed precision.
- The Stata program checked that a and b used identical observations in each fit. The Python checker confirmed the city counts, sample-count reconciliation, all ten deletion aliases for each candidate, and the coefficient products.

The tested setup was Python 3.12.10, Stata/MP 18, reghdfe 6.13.1 and ftools 2.50.0 on macOS. The saved JSON reports distinguish the summary-only check from the full re-estimation.

## Log and scope

`treated_city_deletion.log` is the actual Stata log from the executed full entry point. Machine-specific directory prefixes are replaced by `[RUN_DIRECTORY]`. No numerical output, commands, timestamps, or sample counts are altered. The private launch script, which supplies the local data location, is not distributed.

These checks establish numerical reproduction of the reported deletion analysis. They do not validate finite-sample inference with few treated cities or identify a causal mediation effect. The published deletion ranges remain influence diagnostics.
