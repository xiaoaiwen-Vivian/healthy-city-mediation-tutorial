* Candidate-specific common-sample regressions and treated-city deletion diagnostics.
* Run from the package root: do code/run_loto.do "authorized_linked_input.dta"
version 18.0
clear all
set more off
set type double
set sortseed 2025
set linesize 160
args input_path
if `"`input_path'"'=="" exit 198
capture log close _all
log using "logs/treated_city_deletion.log", text replace
display "Stata version: " c(stata_version)
which reghdfe
which ftools

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
quietly levelsof city_id if baseline & treated==1, local(treated_cities)
local n_treated: word count `treated_cities'
assert `n_treated'==10
tempfile eligible common results
save `eligible'
tempname result
postfile `result' str12 Candidate str8 OmittedCity long(N Respondents Cities TreatedCities N_removed Respondents_removed) ///
    double(a b ab a_SE b_SE a_p b_p df_a df_b a_CI_L a_CI_U b_CI_L b_CI_U) ///
    byte SameSample using `results'

capture program drop fit_paths
program define fit_paths
    syntax, MED(varname) CONTROLS(string) CANDIDATE(string) OMITTED(string) ///
        HANDLE(name) EXPECTEDN(integer) EXPECTEDG(integer) EXPECTEDT(integer) ///
        REMOVED(integer) PERSONSREMOVED(integer)
    tempvar sa sb tag tagperson
    tempname a b ase bse adf bdf ap bp alo ahi blo bhi
    quietly reghdfe `med' did `controls', absorb(city_id year) vce(cluster city_id)
    generate byte `sa'=e(sample)
    scalar `a'=_b[did]
    scalar `ase'=_se[did]
    scalar `adf'=e(df_r)
    assert `ase'>0 & `ase'<.
    assert e(N)==`expectedn'
    assert `sa'==1
    scalar `ap'=2*ttail(`adf',abs(`a'/`ase'))
    scalar `alo'=`a'-invttail(`adf',.025)*`ase'
    scalar `ahi'=`a'+invttail(`adf',.025)*`ase'
    quietly reghdfe outcome `med' did `controls', absorb(city_id year) vce(cluster city_id)
    generate byte `sb'=e(sample)
    scalar `b'=_b[`med']
    scalar `bse'=_se[`med']
    scalar `bdf'=e(df_r)
    assert `bse'>0 & `bse'<.
    assert e(N)==`expectedn'
    assert `sa'==`sb'
    scalar `bp'=2*ttail(`bdf',abs(`b'/`bse'))
    scalar `blo'=`b'-invttail(`bdf',.025)*`bse'
    scalar `bhi'=`b'+invttail(`bdf',.025)*`bse'
    egen byte `tag'=tag(city_id) if `sa'
    quietly count if `tag'==1
    local cities=r(N)
    quietly count if `tag'==1 & treated==1
    local treatedcities=r(N)
    egen byte `tagperson'=tag(respondent_id) if `sa'
    quietly count if `tagperson'==1
    local persons=r(N)
    assert `cities'==`expectedg'
    assert `treatedcities'==`expectedt'
    assert `adf'==`expectedg'-1
    assert `bdf'==`expectedg'-1
    post `handle' ("`candidate'") ("`omitted'") (`expectedn') (`persons') (`cities') (`treatedcities') ///
        (`removed') (`personsremoved') (`a') (`b') (`a'*`b') (`ase') (`bse') (`ap') (`bp') ///
        (`adf') (`bdf') (`alo') (`ahi') (`blo') (`bhi') (1)
    display "FIT `candidate' | omitted `omitted' | N=" `expectedn' " | cities=" `cities' " | treated=" `treatedcities' ///
        " | a=" %18.12g `a' " | b=" %18.12g `b' " | ab=" %18.12g (`a'*`b')
end

local labels Green Road SO2 Medical PM25 Social
local mediators m_green m_road m_so2 m_medical m_pm25 m_social
local expected_n 16661 16661 15430 11141 16661 16660
forvalues j=1/6 {
    use `eligible', clear
    local med: word `j' of `mediators'
    local label: word `j' of `labels'
    local n_expected: word `j' of `expected_n'
    quietly reghdfe outcome `med' did `controls' if baseline, absorb(city_id year) vce(cluster respondent_id)
    generate byte common=e(sample)
    keep if common
    assert _N==`n_expected'
    save `common', replace
    fit_paths, med(`med') controls("`controls'") candidate(`label') omitted(Full) handle(`result') ///
        expectedn(`n_expected') expectedg(94) expectedt(10) removed(0) personsremoved(0)
    forvalues k=1/10 {
        use `common', clear
        local omitted_city: word `k' of `treated_cities'
        local alias= "T" + string(`k',"%02.0f")
        quietly count if city_id==`omitted_city'
        local removed=r(N)
        assert `removed'>0
        tempvar person_tag
        egen byte `person_tag'=tag(respondent_id) if city_id==`omitted_city'
        quietly count if `person_tag'==1
        local persons_removed=r(N)
        drop if city_id==`omitted_city'
        local n_retained=_N
        assert `n_retained'==`n_expected'-`removed'
        fit_paths, med(`med') controls("`controls'") candidate(`label') omitted(`alias') handle(`result') ///
            expectedn(`n_retained') expectedg(93) expectedt(9) removed(`removed') personsremoved(`persons_removed')
    }
}
postclose `result'
use `results', clear
assert _N==66
bysort Candidate: assert _N==11
assert SameSample==1
format a b ab a_SE b_SE a_p b_p a_CI_L a_CI_U b_CI_L b_CI_U %21.15g
export delimited using "results/treated_city_deletion_raw.csv", replace
list Candidate OmittedCity N Cities TreatedCities a b ab, noobs sepby(Candidate)
display "RR2_LOTO_SUCCESS: all six full samples and 60 treated-city deletions completed; 132 path regressions."
display "Deletion ranges are influence diagnostics, not confidence intervals. No ab hypothesis test is computed by deletion."
log close
exit, clear
