* Policy-association sensitivity analysis using respondent and year effects.
* Run from the companion folder with the study data path as the argument.
version 18.0
clear all
set more off
set type double
set sortseed 2025
set linesize 140
args input_path
if `"`input_path'"'=="" {
    display as error "Supply the study analysis dataset as the first argument."
    exit 198
}
capture mkdir results
capture mkdir logs
capture log close felog
log using "logs/individual_fe_sensitivity.log", text replace name(felog)

use "`input_path'", clear
rename (ID iwy treat rgoingl) (person_id year treated outcome)
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

* Retain the policy model's complete observations before comparing fixed effects.
quietly reghdfe outcome did `controls', ///
    absorb(city_id year) vce(cluster city_id)
generate byte baseline=e(sample)
quietly count if baseline
local baselineN=r(N)
tempfile eligible summary
save `eligible'
tempname results
postfile `results' str24 Fixed_effects str12 Clustering ///
    long(N Respondents Cities Excluded_from_baseline) ///
    double(Coef SE P CI_L CI_U Residual_df) using `summary'

foreach fixed in City Individual {
    use `eligible', clear
    local absorbed city_id
    if "`fixed'"=="Individual" local absorbed respondent_id
    local sample_set 0
    foreach level in Individual City {
        local cluster respondent_id
        if "`level'"=="City" local cluster city_id
        display "FIXED EFFECTS: `fixed' and year; CLUSTERING: `level'"
        reghdfe outcome did `controls' if baseline, ///
            absorb(`absorbed' year) vce(cluster `cluster')
        if !`sample_set' {
            generate byte fixed_sample=e(sample)
            local sample_set 1
        }
        assert e(sample)==fixed_sample
        scalar coef=_b[did]
        scalar se=_se[did]
        scalar pvalue=2*ttail(e(df_r),abs(scalar(coef)/scalar(se)))
        scalar lower=scalar(coef)-invttail(e(df_r),.025)*scalar(se)
        scalar upper=scalar(coef)+invttail(e(df_r),.025)*scalar(se)
        local N=e(N)
        local df=e(df_r)
        tempvar person_tag city_tag
        egen byte `person_tag'=tag(respondent_id) if e(sample)
        quietly count if `person_tag'==1
        local persons=r(N)
        egen byte `city_tag'=tag(city_id) if e(sample)
        quietly count if `city_tag'==1
        local cities=r(N)
        local excluded=`baselineN'-`N'
        post `results' ("`fixed' + year") ("`level'") ///
            (`N') (`persons') (`cities') (`excluded') ///
            (scalar(coef)) (scalar(se)) (scalar(pvalue)) ///
            (scalar(lower)) (scalar(upper)) (`df')
    }
}
postclose `results'
use `summary', clear
format Coef SE P CI_L CI_U %12.8f
list, noobs abbreviate(25)
export delimited using "results/individual_fe_sensitivity.csv", replace
display "Completed: two fixed-effect specifications, each with individual and city clustering."
log close felog
