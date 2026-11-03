# Inference and resampling details

## Component paths and Sobel

Path coefficients are estimated with city and year fixed effects and the candidate-specific common sample. Conventional path tests use the relevant cluster covariance and cluster-count degrees of freedom. Individual and city clustering are reported separately.

For the city-cluster Sobel calculation, ab is the common-sample product and SE(ab)=sqrt(b² SE(a)² + a² SE(b)²). The reported Sobel statistic divides ab by this SE and uses the standard-normal reference distribution. This is the traditional Sobel calculation used in the tutorial; no cross-equation covariance term is added here. A joint delta-method estimator is not claimed or executed by the tutorial package.

## The 2,000-draw pairs bootstraps

The city bootstrap resamples cities with replacement, keeping all observations in a selected city together. City multiplicities are read from the supplied 2,000×94 schedule, generated from PCG64 with seed 2025. Cities use the same sorted order in the two implementations. Cities are not stratified by treatment status for this pairs bootstrap.

The respondent comparison uses multinomial resampling over sorted respondent IDs, seed 2025 reset separately for each candidate, with 2,000 draws. Every selected respondent contributes their complete retained history. City means are recalculated under each draw's respondent-frequency weights. Both path regressions are re-estimated before calculating ab.

Saved files contain draw number, a, b and ab for every candidate under each resampling unit. Stata and Python independently implement the city procedure; only Python implements the respondent procedure. A new dataset or altered city/respondent ordering requires its own compatible resampling plan.

Percentile limits are the 2.5th and 97.5th empirical quantiles with linear interpolation. BC uses z0=Phi_inverse(proportion of draws <= observed ab), with that proportion bounded to [0.0001,0.9999], and probabilities Phi(2z0+Phi_inverse(0.025)) and Phi(2z0+Phi_inverse(0.975)). These are **BC** limits; there is no acceleration term. All intervals are unadjusted for multiplicity.

## Hypothesis-testing families and descriptive calculation groups

Each family or group contains all six candidates: Green, Road, SO2, Medical, PM25 and Social. The first five rows below are hypothesis-testing families; the last two are descriptive calculation groups.

| Family | Input | Size |
| --- | --- | --- |
| Individual_Common_a | Individual-cluster a-path p values | 6 |
| Individual_Common_b | Individual-cluster b-path p values | 6 |
| City_Common_a | City-cluster a-path p values | 6 |
| City_Common_b | City-cluster b-path p values | 6 |
| City_common_Sobel | City-cluster Sobel p values | 6 |
| Individual_bootstrap_sign | Respondent-bootstrap sign-tail summaries | 6 |
| City_bootstrap_sign | City-bootstrap sign-tail summaries | 6 |

The sign-tail input is min(1, 2×(min(negative draws, positive draws)+1)/(2000+1)). It is not a null-imposed bootstrap test and has not been established as a calibrated p value. Its BH transformation is retained as a descriptive calculation and must not be compared with .05 to make significance decisions. It must not be relabeled as a validated FDR-controlled mediation test. The formal and descriptive outputs are written separately; the combined compatibility file includes a `Use` column identifying their roles.

BH sorts the six inputs, multiplies the i-th ordered input by 6/i, takes the reverse cumulative minimum, caps at one, and returns values to candidate order. Python's explicit implementation is checked against SciPy; Stata independently recalculates the adjustments. Separate families do not provide one joint correction across every analysis. Valid FDR claims require appropriate p-value calibration and dependence assumptions.

## Supplemental wild cluster bootstrap

The additional procedure tests the overall policy coefficient and each candidate's a and b coefficient under the null of zero. It uses **restricted / null-imposed wild cluster bootstrap-t**, Rademacher ±1 weights, city clustering and bootstrap clustering, 9,999 replications, seed 2025 and symmetric absolute-t comparisons. Both the observed city assignments and the ten treated cities remain fixed. It is not the pairs bootstrap above.

boottest 4.5.5 requires one absorbed FE set. Year effects are therefore written as explicit year indicators and city effects remain absorbed. The script verifies equality of e(sample), N, degrees of freedom, coefficients and conventional SEs before using the reexpression. Confidence sets invert the tests at 95%; all sets in this run are bounded single intervals. They are not BC or percentile product intervals. The confidence-search p tolerance is 0.0001.

All 13 results are supplied, including results above 0.05. WCB BH adjustments are two additional families of six a and six b tests; the overall coefficient is separate. A zero Monte Carlo p output means no exceedances among 9,999 draws, not a true probability of zero. Public summaries display <0.001 while preserving the command's raw output.

This procedure does not test the nonlinear product a×b. Few treated clusters can remain problematic, and no conclusion about causal mechanisms follows from computational agreement or a small coefficient-test p value.

## Methodological references

- [Benjamini and Hochberg (1995)](https://doi.org/10.1111/j.2517-6161.1995.tb02031.x), for the BH transformation.
- [Roodman et al. (2019)](https://doi.org/10.1177/1536867X19830877), for wild cluster bootstrap implementation and confidence-set inversion.
- [MacKinnon, Nielsen and Webb (2023)](https://doi.org/10.1016/j.jeconom.2022.04.001), for cluster inference and few-treated-cluster qualifications.
- [Official Stata bootstrap documentation](https://www.stata.com/manuals/rbootstrap.pdf), for interval terminology, including BC versus BCa.
