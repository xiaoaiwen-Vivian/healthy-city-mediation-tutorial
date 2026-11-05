* Independent verification of S2 and S3; writes only new aggregate results.
version 18.0
clear all
set more off
args input_path package_path output_path
cd "`package_path'"
do code/setup_stata.do
cd "`output_path'"
capture log close _all
log using "independent_stata.log", text replace
use "`input_path'", clear
rename (ID iwy treat rgoingl) (person_id year treated outcome)
rename (GreenCoverageRateBD RoadSurAreaPerCap 工业二氧化硫排放量吨 hosper pm act_12) (m_green m_road m_so2 m_medical m_pm25 m_social)
replace city=strtrim(city)
drop if missing(person_id) | missing(wave) | missing(city) | missing(year)
keep if age>=45 & age<. & rural==0
replace did=treated*(year>=2017)
local controls gender marry log_real_inc_per rwork rural2 edu hchild retire adlab_c smoken drinkl srh age
local meds m_green m_road m_so2 m_medical m_pm25 m_social
local labels Green Road SO2 Medical PM25 Social
egen long city_id=group(city)
quietly reghdfe outcome did `controls', absorb(city_id year) vce(cluster city_id)
generate byte base=e(sample)
assert e(N)==16661
tempname d c
postfile `d' str32 Variable str20 Group double N double Mean double SD double Count_1 double Percent_1 double Eligible double Missing double Percent_missing using "stata_descriptives.dta", replace
foreach v in outcome did `controls' `meds' {
    forvalues g=0/2 {
        if `g'==0 {
            local group "All"
            local cond "1"
        }
        if `g'==1 {
            local group "Untreated cities"
            local cond "treated==0"
        }
        if `g'==2 {
            local group "Treated cities"
            local cond "treated==1"
        }
        quietly summarize `v' if base & (`cond')
        local n=r(N)
        local mean=r(mean)
        local sd=r(sd)
        quietly count if base & (`cond') & `v'==1
        local one=r(N)
        quietly count if (`cond')
        local eligible=r(N)
        quietly count if (`cond') & missing(`v')
        local missing=r(N)
        post `d' ("`v'") ("`group'") (`n') (`mean') (`sd') (`one') (100*`one'/`n') (`eligible') (`missing') (100*`missing'/`eligible')
    }
}
postclose `d'

postfile `c' str20 Candidate str1 Path str8 Model double N double Estimate double SE double CI_lower double CI_upper double Clusters double TreatedCities using "stata_coefficients.dta", replace
foreach model in Crude Adjusted {
    if "`model'"=="Crude" quietly regress outcome did if base, vce(cluster city_id)
    else quietly reghdfe outcome did `controls' if base, absorb(city_id year) vce(cluster city_id)
    scalar crit=invttail(e(df_r),.025)
    post `c' ("Overall policy") ("c") ("`model'") (e(N)) (_b[did]) (_se[did]) (_b[did]-crit*_se[did]) (_b[did]+crit*_se[did]) (e(N_clust)) (10)
}
local i=0
foreach m of local meds {
    local ++i
    local label: word `i' of `labels'
    quietly reghdfe outcome `m' did `controls' if base, absorb(city_id year) vce(cluster city_id)
    generate byte common_`i'=e(sample)
    quietly egen byte tag_`i'=tag(city_id) if common_`i'
    quietly count if tag_`i'==1 & treated==1
    local treated_count=r(N)
    foreach model in Crude Adjusted {
        if "`model'"=="Crude" quietly regress `m' did if common_`i', vce(cluster city_id)
        else quietly reghdfe `m' did `controls' if common_`i', absorb(city_id year) vce(cluster city_id)
        assert e(sample)==common_`i'
        scalar crit=invttail(e(df_r),.025)
        post `c' ("`label'") ("a") ("`model'") (e(N)) (_b[did]) (_se[did]) (_b[did]-crit*_se[did]) (_b[did]+crit*_se[did]) (e(N_clust)) (`treated_count')
        if "`model'"=="Crude" quietly regress outcome `m' did if common_`i', vce(cluster city_id)
        else quietly reghdfe outcome `m' did `controls' if common_`i', absorb(city_id year) vce(cluster city_id)
        assert e(sample)==common_`i'
        scalar crit=invttail(e(df_r),.025)
        post `c' ("`label'") ("b") ("`model'") (e(N)) (_b[`m']) (_se[`m']) (_b[`m']-crit*_se[`m']) (_b[`m']+crit*_se[`m']) (e(N_clust)) (`treated_count')
    }
}
postclose `c'
use "stata_descriptives.dta", clear
export delimited using "stata_descriptives.csv", replace
use "stata_coefficients.dta", clear
export delimited using "stata_coefficients.csv", replace
file open done using "independent_stata_completed.ok", write text replace
file write done "Independent S2 and S3 calculation completed." _n
file close done
log close
exit, clear
