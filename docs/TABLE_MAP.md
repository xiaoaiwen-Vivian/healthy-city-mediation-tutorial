# Manuscript-to-code map

The map follows Tables 1–11 and Supplementary Table S1 in the revised manuscript. The numeric checker reads the Word file without modifying it, includes inserted text, and excludes deleted text and table rows. Captions identify the tables, rather than their raw XML positions. It checks 288 displayed numeric entries in ten quantitative tables; Tables 1 and 6 provide definitions and are not numeric estimation checks.

| Manuscript item | Generated table / source | Program |
| --- | --- | --- |
| Table 1: candidate measurements | `MODELS_AND_VARIABLES.md`; source-to-analysis variable mapping | `case_core.py`, `case_stata.do` |
| Table 2: individual-cluster common-sample paths | `tables/Table_2_common_individual_paths.csv`; `python/component_paths.csv` and `stata/component_paths.csv` | `case_python.py`, `case_stata.do` |
| Table 3: candidate common samples | `tables/Table_3_common_samples.csv` | `case_python.py` |
| Table 4: common-sample city Sobel | `tables/Table_4_common_city_sobel.csv` | `case_python.py`, `case_stata.do` |
| Table 5: individual/city indirect intervals | `tables/Table_5_indirect_intervals.csv`; all `*_draws_<candidate>.csv` | `case_python.py`, `case_stata.do`, `recalculate_intervals.py` |
| Table 6: comparison-family definitions | Five testing families and two descriptive groups; six candidates each; `INFERENCE.md` | `fdr_python.py`, `fdr_stata.do` |
| Table 7: worked Sobel BH example | `tables/Table_7_sobel_BH.csv` | `fdr_python.py` |
| Table 8: individual path BH values | `tables/Table_8_individual_path_BH.csv` | `fdr_python.py` |
| Table 9: city bootstrap sign summaries, descriptive | `tables/Table_9_city_sign_summaries_descriptive.csv` | `fdr_python.py`, `fdr_stata.do` |
| Table 10: individual bootstrap sign summaries, descriptive | `tables/Table_10_individual_sign_summaries_descriptive.csv` | `fdr_python.py` |
| Table 11: fixed-effects policy sensitivity | `tables/Table_11_fixed_effects_sensitivity.csv` | `individual_fe_sensitivity.do` |
| Supplementary Table S1: unadjusted WCB coefficient tests | `tables/Table_S1_wild_cluster_tests.csv`; `wild/wild_cluster_9999.csv` | `wild_cluster.do`, `summarize_wild.py` |

Paths in this table are under a completed run's `results/`. The `reference_results/` tree contains the corresponding supplied aggregate inputs and draws. `code/export_tables.py` generates the tabular exports after estimation and adjustment.

`worked_examples.do` runs the Green and Social examples; `worked_fe_examples.do` runs the respondent/year policy example. Both are executed by the full entry point. The packaged Stata programs use `m_so2` for industrial sulfur dioxide emissions; the manuscript's Stata snippets use `m_SO2` for the same source field. Stata names are case-sensitive, so use each program's own consistent alias when executing it.

The WCB supplement is additional analysis and does not silently replace the main manuscript tables. Its all-path file includes the overall coefficient plus all twelve component tests. It is not a new set of indirect-product estimates.

For a supplied revised manuscript, run:

```bash
python code/check_manuscript_tables.py --docx "/path/to/manuscript.docx" --results "/path/to/completed-run/results" --output "/path/to/checks.csv"
```

The CSV records every checked value, its calculated counterpart and the tolerance at the displayed precision. A JSON summary is written beside it. A discrepancy causes a nonzero exit status. `<0.001` is checked as an inequality, not as an exact zero. The complete check can also be requested with `run.py full --manuscript ...` or `run.py check --manuscript ...`.
