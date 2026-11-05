# Executed supplementary reporting validation

Validation was completed on November 4, 2026, using the current manuscript and the authorized upstream build outputs from the main reproducibility workflow. Source data and the manuscript were not changed.

The add-on was executed with Python 3.12.10, NumPy 2.4.6, pandas 3.0.3 and SciPy 1.17.1 on macOS. Stata 18 independently calculated the S2 descriptions/missingness and the S3 crude/adjusted coefficient comparisons, using the main repository's bundled Stata dependencies.

| Check | Coverage | Outcome |
| --- | --- | --- |
| Fresh calculations against previously verified aggregate results | 1,195 numerical comparisons across 13 CSV files and the sample summary | All passed |
| Independent Stata versus Python calculations | 582 comparisons: 63 variable-by-group S2 summaries and 26 S3 models | All passed |
| Current manuscript Table S2 | 267 displayed values, including column denominators and available-n notes | All matched at displayed precision |
| Current manuscript Table S3 | 91 displayed sample sizes, coefficients and interval endpoints | All matched at displayed precision |
| Policy-group sample reporting | Selection stages, 2011 initial-cohort follow-up, observed waves/span, wave-specific outcomes | Recalculated; matched the verified summaries |
| Source integrity | The five input files and the checked manuscript | Unchanged |

Full-precision comparisons use relative tolerance `2e-10` and absolute tolerance `1e-13`; displayed table values use half a unit in the last reported decimal place. The source-data byte checksum is not used as a model-selection criterion. Different Stata file serialization can produce a different file checksum even when the data values are identical.

This run recalculated the added reporting material and coefficient comparisons from the existing upstream build outputs. It did not rebuild the official survey sources in this run and did not repeat the main manuscript's 2,000-draw mediation bootstraps or wild cluster bootstrap. Those remain in the main repository's existing workflow.

`execution_log.txt` contains the executed Python calculation/check output. `stata_S2_S3.log` contains the independent Stata calculation log. The public Stata log removes the local log-directory path and unwraps Stata's display-only continuation lines; coefficients and other numeric output are unchanged. Participant-level records and private configuration paths are not included.

The JSON summaries and CSV check lists provide the numerical verification detail. The reference files and formatted tables are aggregate outputs. They allow reconstruction without participant data; recalculation of sample selection, follow-up and models requires authorized access to the inputs listed in the README.

The archive was also extracted into a different directory. Both `check` and `full` were executed from an unrelated working directory; both passed, including the optional Stata and manuscript checks. The three formatted outputs matched the supplied tables and reporting text byte for byte.
