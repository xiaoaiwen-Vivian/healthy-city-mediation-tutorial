* Named Stata example used in Step 8; run from this companion folder.
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
capture mkdir logs
capture log close feexample
log using "logs/worked_fe_examples.log", text replace name(feexample)
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

* BEGIN respondent_fe_example
reghdfe outcome did `controls' if baseline, ///
    absorb(respondent_id year) vce(cluster respondent_id)
generate byte respondent_fe_sample=e(sample)
estimates store policy_fe_individual
display "p value = " 2*ttail(e(df_r),abs(_b[did]/_se[did]))

reghdfe outcome did `controls' if baseline, ///
    absorb(respondent_id year) vce(cluster city_id)
assert e(sample)==respondent_fe_sample
estimates store policy_fe_city
display "p value = " 2*ttail(e(df_r),abs(_b[did]/_se[did]))
* END respondent_fe_example

estimates table policy_fe_individual policy_fe_city, ///
    keep(did) b(%9.6f) se(%9.6f) stats(N)
display "Completed: both named individual fixed-effects examples."
log close feexample
