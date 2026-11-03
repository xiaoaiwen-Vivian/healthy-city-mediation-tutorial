* Healthy City case. Run from the companion folder with an authorized input.
version 18.0
clear all
set more off
set type double
set sortseed 2025
args input_path
if `"`input_path'"'=="" {
    display as error "Supply the authorized linked dataset as the first argument."
    exit 198
}
capture mkdir results
capture mkdir results/stata
do code/city_core.mata
do code/city_bootstrap.mata
import delimited using code/shared_draw_counts_94.csv, clear
ds g*
local frequency_columns `r(varlist)'
mata: city_counts=st_data(.,tokens(st_local("frequency_columns")))

* BEGIN preparation
use "`input_path'", clear
rename (ID iwy treat rgoingl) (person_id year treated outcome)
rename (GreenCoverageRateBD RoadSurAreaPerCap act_12) ///
       (m_green m_road m_social)
rename 工业二氧化硫排放量吨 m_so2
rename (hosper pm) (m_medical m_pm25)
replace city=strtrim(city)
drop if missing(person_id) | missing(city) | missing(year)
drop if missing(wave)
keep if age>=45 & age<. & rural==0
capture drop did
generate double did=treated*(year>=2017)
egen long city_id=group(city)
egen long respondent_id=group(person_id)
local controls gender marry log_real_inc_per rwork rural2 edu ///
    hchild retire adlab_c smoken drinkl srh age
local labels Green Road SO2 Medical PM25 Social
local mediators m_green m_road m_so2 m_medical m_pm25 m_social
* END preparation

* BEGIN baseline
reghdfe outcome did `controls', ///
    absorb(city_id year) vce(cluster respondent_id)
generate byte baseline=e(sample)
display "Policy coefficient = " _b[did] ", SE = " _se[did]
* END baseline
tempfile eligible component_common summary
save `eligible'
tempname common result
postfile `common' str12 Mediator str10 Level str1 Path ///
    long N double(estimate se p) using `component_common'
postfile `result' str12 Mediator long(N Cities TreatedCities) ///
    double(a b ab SE_a SE_b Sobel_SE Sobel_p Sobel_CI_L Sobel_CI_U ///
    B Pct_L Pct_U BC_L BC_U z0 BC_prob_L BC_prob_U ///
    Negative Positive Zero sign_tail) using `summary'



forvalues j=1/6 {
    use `eligible', clear
    local med : word `j' of `mediators'
    local label : word `j' of `labels'
    * BEGIN common_sample
    quietly reghdfe outcome `med' did `controls' if baseline, ///
        absorb(city_id year) vce(cluster respondent_id)
    generate byte common=e(sample)
    keep if common
    * END common_sample
    foreach level in Individual City {
        local cluster respondent_id
        if "`level'"=="City" local cluster city_id
        * BEGIN stored_paths
        quietly reghdfe outcome `med' did `controls', ///
            absorb(city_id year) vce(cluster `cluster')
        assert e(sample)==1
        scalar b=_b[`med']
        scalar se_b=_se[`med']
        post `common' ("`label'") ("`level'") ("b") (e(N)) ///
            (scalar(b)) (scalar(se_b)) (2*ttail(e(df_r),abs(scalar(b)/scalar(se_b))))
        quietly reghdfe `med' did `controls', ///
            absorb(city_id year) vce(cluster `cluster')
        assert e(sample)==1
        scalar a=_b[did]
        scalar se_a=_se[did]
        scalar indirect=scalar(a)*scalar(b)
        * END stored_paths
        post `common' ("`label'") ("`level'") ("a") (e(N)) ///
            (scalar(a)) (scalar(se_a)) (2*ttail(e(df_r),abs(scalar(a)/scalar(se_a))))
    }
    * BEGIN sobel
    scalar sobel_se=sqrt(scalar(b)^2*scalar(se_a)^2 ///
        + scalar(a)^2*scalar(se_b)^2)
    scalar sobel_z=scalar(indirect)/scalar(sobel_se)
    scalar sobel_p=2*normal(-abs(scalar(sobel_z)))
    scalar sobel_lower=scalar(indirect)-invnormal(.975)*scalar(sobel_se)
    scalar sobel_upper=scalar(indirect)+invnormal(.975)*scalar(sobel_se)
    * END sobel
    local N=_N
    local G=e(N_clust)
    egen byte city_tag=tag(city_id)
    quietly count if city_tag & treated==1
    local treatedN=r(N)
    quietly tabulate year, generate(wave_indicator)
    drop wave_indicator1
    ds wave_indicator*
    local years `r(varlist)'
    sort city_id person_id year
    mata: city_products("`med'","did `controls' `years'", ///
        "results/stata/city_draws_`label'.csv",city_counts)
    import delimited using "results/stata/city_draws_`label'.csv", clear
    * BEGIN intervals
    quietly count
    scalar B=r(N)
    quietly count if ab<=scalar(indirect)
    scalar fraction=r(N)/B
    scalar z0=invnormal(max(.0001,min(.9999,fraction)))
    scalar prob_lower=normal(2*z0+invnormal(.025))
    scalar prob_upper=normal(2*z0+invnormal(.975))
    mata: v=st_data(.,"ab")
    mata: st_numscalar("pct_lower",hc_q(v,.025))
    mata: st_numscalar("pct_upper",hc_q(v,.975))
    mata: st_numscalar("bc_lower",hc_q(v,st_numscalar("prob_lower")))
    mata: st_numscalar("bc_upper",hc_q(v,st_numscalar("prob_upper")))
    * END intervals
    quietly count if ab<0
    scalar negative=r(N)
    quietly count if ab>0
    scalar positive=r(N)
    quietly count if ab==0
    scalar zero=r(N)
    scalar tail=min(1,2*(min(negative,positive)+1)/(B+1))
    post `result' ("`label'") (`N') (`G') (`treatedN') ///
        (scalar(a)) (scalar(b)) (scalar(indirect)) (scalar(se_a)) (scalar(se_b)) ///
        (scalar(sobel_se)) (scalar(sobel_p)) (scalar(sobel_lower)) (scalar(sobel_upper)) ///
        (scalar(B)) (scalar(pct_lower)) (scalar(pct_upper)) (scalar(bc_lower)) (scalar(bc_upper)) ///
        (scalar(z0)) (scalar(prob_lower)) (scalar(prob_upper)) (scalar(negative)) (scalar(positive)) (scalar(zero)) (scalar(tail))
    display "`label': 2000 city products and both intervals complete"
}
postclose `result'
postclose `common'
use `summary', clear
export delimited using results/stata/city_results.csv, replace
use `component_common', clear
generate str9 Sample="Common"
export delimited using results/stata/component_paths.csv, replace
display "Estimation finished. Step 7 is code/fdr_stata.do."
