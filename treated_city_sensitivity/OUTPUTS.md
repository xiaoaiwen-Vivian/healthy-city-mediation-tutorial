# Output definitions

`reference_results/treated_city_deletion_raw.csv` contains one row per candidate and sample: six full-sample rows and 60 deletion rows. All quantities are aggregate regression outputs.

| Column | Meaning |
| --- | --- |
| `Candidate` | Green, Road, SO2, Medical, PM25, or Social |
| `OmittedCity` | `Full` for the full common sample; `T01`–`T10` for treated-city deletions |
| `N`, `Respondents` | Retained person-wave observations and distinct respondents |
| `Cities`, `TreatedCities` | Retained city counts |
| `N_removed`, `Respondents_removed` | Counts removed relative to that candidate's full sample |
| `a`, `b`, `ab` | Policy coefficient in the candidate model; candidate coefficient in the outcome model; their product |
| `a_SE`, `b_SE` | Conventional city-clustered standard errors for the component paths |
| `a_p`, `b_p` | Conventional t-reference p values for the component coefficients |
| `df_a`, `df_b` | Residual reference degrees of freedom, equal to retained cities minus one |
| `a_CI_L`, `a_CI_U`, `b_CI_L`, `b_CI_U` | Unadjusted conventional 95% component-path confidence intervals |
| `SameSample` | One when Stata confirmed identical observations in the two paths |

No p value or confidence interval for `ab` is calculated by the deletion procedure. Path p values and intervals are not multiplicity-adjusted.

`deletion_summary.csv` contains the full-sample product and N; minimum and maximum deletion products with the corresponding city aliases; counts of positive, negative and sign-reversed products; largest absolute and relative product changes; and ranges of component coefficients and retained observations. `most_influential_city` identifies the deletion giving the largest absolute product change. It is a diagnostic label, not an exclusion rule. All ten deletions contribute to every summary.

Fresh runs additionally produce `results/Table_S4.csv`, with the manuscript's displayed rounding, and `results/treated_city_deletions.csv`, containing the 60 deletion rows. Full mode produces `results/treated_city_deletion_raw.csv` as well. `validation.json` records the checks that actually ran and whether they passed.
