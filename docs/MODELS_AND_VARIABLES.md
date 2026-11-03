# Models, variables and samples

## Input schema

| Source field | Analysis alias | Role |
| --- | --- | --- |
| ID | person_id; respondent_id in Stata | Respondent identifier, retained as string when read |
| city | city; city_id in Stata | City identifier |
| iwy | year | Survey calendar year: 2011, 2013, 2015, 2018, 2020 |
| wave | wave | Survey-record identifier; unmatched city-only rows have no wave |
| treat | treated | Policy-city indicator, constant within city |
| rgoingl | outcome | CES-D “I felt that I could not get going” single item, 1–4 |
| rural | rural | Urban sample indicator: rural==0 |
| GreenCoverageRateBD | m_green | Green coverage of built-up urban area, percent |
| RoadSurAreaPerCap | m_road | Road surface area per capita, m²/person |
| 工业二氧化硫排放量吨 | m_so2 | Annual industrial SO2 emissions, tons |
| hosper | m_medical | Hospitals/health centers per 10,000 registered residents |
| pm | m_pm25 | Annual city PM2.5 concentration, μg/m³ |
| act_12 | m_social | Sum of two specified social-activity indicators, 0–2 |

All identifiers required for construction remain in local data only. The outcome is used by the manuscript as a theoretically informed, non-validated anergia-based proxy for suicide-related vulnerability. It is not a direct measurement of suicidal ideation, behavior or a diagnosis; the regression operates on the observed 1–4 score.

Stata names are case sensitive: the executed alias is **m_so2**, with lowercase letters, and the source variable is the Chinese field above. “Tons of SO2 emissions” is an English explanation, not the literal source column name.

Controls, in model order: `gender marry log_real_inc_per rwork rural2 edu hchild retire adlab_c smoken drinkl srh age`. `rural2` is a household-registration covariate distinct from the `rural==0` eligibility condition. `log_real_inc_per` is the log of CPI-adjusted income per household member as built by the upstream program. The upstream code preserves the wave-specific definitions and missing-value handling.

Policy exposure is `did = treated * (year >= 2017)`. The first observed post-policy wave is 2018. Respondents are urban residents aged at least 45, with valid person, city, year and wave identifiers. Model-specific complete observations are then selected. No survey weights are applied.

## Main equations

- Overall policy association: outcome on did, all controls, city and year fixed effects.
- a path for candidate j: M_j on did, all controls, city and year fixed effects.
- b path: outcome on M_j, did, all controls, city and year fixed effects.

For each candidate j, define one complete sample from the b-path model within the baseline sample and use it for both path regressions and both resampling procedures. Clustering changes covariance estimation, not these rows or the fixed effects. The product is a×b on that common sample. Paths estimated on different available samples are not substituted into it.

The supplied samples contain 94 cities and ten treated cities. There are no respondent moves across cities in this input. The city bootstrap resamples whole cities, while the respondent bootstrap resamples whole respondent histories. Both retain city and year fixed effects and refit their paths within each draw.

## Separate fixed-effects sensitivity

The policy model is also fitted with respondent and year fixed effects, under individual and city clustering. It uses 13,579 observations and 4,913 respondents after 3,082 singleton exclusions. It is a sensitivity analysis for the overall policy coefficient; the main mediation paths remain city/year FE models.

## Candidate-specific sample sizes

Green, Road and PM25: 16,661 observations and 7,995 respondents. SO2: 15,430 and 7,673. Medical: 11,141 and 6,353, covering 2011–2018. Social: 16,660 and 7,995. These are verification targets after applying the rules, not instructions to select records until a desired number is reached.
