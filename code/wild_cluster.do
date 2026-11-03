* Run from this supplement's root directory.
* Syntax: do code/run_wild_cluster.do "authorized linked dataset.dta" [9999]
* Existing variables, eligibility, controls and candidate-specific common samples
* reproduce the companion v3. No source data are changed or exported.
version 18.0
clear all
set more off
set type double
set sortseed 2025
args input_path repetitions
if `"`input_path'"'=="" exit 198
if "`repetitions'"=="" local repetitions 9999
capture log close wcb_log
log using "logs/wild_cluster_`repetitions'.log", text replace name(wcb_log)
adopath ++ "vendor/boottest"
mata: mata mlib index
which reghdfe
which boottest
display "Stata version: " c(stata_version)
display "Restricted wild cluster bootstrap-t: Rademacher, city clustering"
display "Seed: 2025; requested replications: `repetitions'; confidence level: 95%"

use "`input_path'", clear
rename (ID iwy treat rgoingl) (person_id year treated outcome)
rename (GreenCoverageRateBD RoadSurAreaPerCap act_12) (m_green m_road m_social)
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
local controls gender marry log_real_inc_per rwork rural2 edu hchild retire adlab_c smoken drinkl srh age
assert inlist(treated,0,1)
bysort city_id: assert treated==treated[1]
bysort respondent_id: assert city_id==city_id[1]

reghdfe outcome did `controls', absorb(city_id year) vce(cluster respondent_id)
generate byte baseline=e(sample)
assert e(N)==16661
assert reldif(_b[did],-.0866794779116242)<1e-8
tempfile eligible summary
save `eligible'
tempname result
postfile `result' str12 Candidate str1 Path long(N Respondents Cities TreatedCities) ///
    double(Estimate City_SE City_df City_p City_CI_L City_CI_U ///
    WCB_p WCB_CI_L WCB_CI_U Reps Reps_feasible Null_imposed ///
    Estimate_difference SE_difference) int CI_pieces str200 WCB_CI_text using `summary'

capture program drop fit_wild
program define fit_wild
    syntax, DEP(varname) RHS(string) TARGET(name) CANDIDATE(string) PATH(string) ///
        HANDLE(name) REPS(integer)
    tempvar sample tag tagperson
    tempname estimate se df n p lo hi ci wp feasible imposed diff sediff dist
    reghdfe `dep' `rhs', absorb(city_id year) vce(cluster city_id)
    generate byte `sample'=e(sample)
    scalar `estimate'=_b[`target']
    scalar `se'=_se[`target']
    scalar `df'=e(df_r)
    scalar `n'=e(N)
    scalar `p'=2*ttail(`df',abs(`estimate'/`se'))
    scalar `lo'=`estimate'-invttail(`df',.025)*`se'
    scalar `hi'=`estimate'+invttail(`df',.025)*`se'
    egen byte `tag'=tag(city_id) if `sample'
    quietly count if `tag'==1
    local cities=r(N)
    quietly count if `tag'==1 & treated==1
    local treatedcities=r(N)
    egen byte `tagperson'=tag(respondent_id) if `sample'
    quietly count if `tagperson'==1
    local persons=r(N)
    assert `cities'==94
    assert `treatedcities'==10

    * The same city + year FE model, with year indicators written explicitly:
    * boottest supports one absorbed FE set. Compare sample, coefficient and SE.
    reghdfe `dep' `rhs' i.year if `sample', absorb(city_id) vce(cluster city_id)
    assert e(sample)==`sample'
    assert e(N)==`n'
    assert e(df_r)==`df'
    assert reldif(_b[`target'],`estimate')<1e-8
    assert reldif(_se[`target'],`se')<1e-8
    scalar `diff'=_b[`target']-`estimate'
    scalar `sediff'=_se[`target']-`se'
    display "CHECK: `candidate', path `path', same sample, city + year FE and coefficients verified."
    boottest `target', cluster(city_id) bootcluster(city_id) reps(`reps') ///
        seed(2025) weight(rademacher) boottype(wild) statistic(t) ///
        ptype(symmetric) level(95) nograph format(%14.9g) ptolerance(.0001) svmat
    return list
    scalar `wp'=r(p)
    matrix `dist'=r(dist)
    mata: st_numscalar("`feasible'",sum(st_matrix("`dist'"):<.))
    scalar `imposed'=r(null)
    matrix `ci'=r(CI)
    local cis `"`r(CIstr)'"'
    local pieces=rowsof(`ci')
    assert r(reps)==`reps'
    assert `feasible'==`reps'
    assert `imposed'==1
    matrix list `ci', format(%20.12g)
    post `handle' ("`candidate'") ("`path'") (`n') (`persons') (`cities') (`treatedcities') ///
        (`estimate') (`se') (`df') (`p') (`lo') (`hi') ///
        (`wp') (`ci'[1,1]) (`ci'[1,2]) (`reps') (`feasible') (`imposed') ///
        (`diff') (`sediff') (`pieces') (`"`cis'"')
    display "COMPLETED: `candidate', path `path'; WCB p = " %12.8f `wp'
end

keep if baseline
fit_wild, dep(outcome) rhs("did `controls'") target(did) candidate(Overall) ///
    path(c) handle(`result') reps(`repetitions')

local labels Green Road SO2 Medical PM25 Social
local mediators m_green m_road m_so2 m_medical m_pm25 m_social
local expected_n 16661 16661 15430 11141 16661 16660
forvalues j=1/6 {
    use `eligible', clear
    local med : word `j' of `mediators'
    local label : word `j' of `labels'
    local n_expected : word `j' of `expected_n'
    quietly reghdfe outcome `med' did `controls' if baseline, ///
        absorb(city_id year) vce(cluster respondent_id)
    generate byte common=e(sample)
    keep if common
    assert _N==`n_expected'
    fit_wild, dep(`med') rhs("did `controls'") target(did) candidate(`label') ///
        path(a) handle(`result') reps(`repetitions')
    fit_wild, dep(outcome) rhs("`med' did `controls'") target(`med') candidate(`label') ///
        path(b) handle(`result') reps(`repetitions')
}
postclose `result'
use `summary', clear
format Estimate City_SE City_p WCB_p WCB_CI_L WCB_CI_U %14.9g
export delimited using "results/wild/wild_cluster_`repetitions'.csv", replace
list Candidate Path N Estimate City_p WCB_p WCB_CI_L WCB_CI_U, clean noobs
display "ALL 13 TESTS COMPLETED. No nonlinear a*b test was performed."
log close wcb_log
