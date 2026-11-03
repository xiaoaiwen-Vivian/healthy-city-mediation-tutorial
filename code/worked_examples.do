* Worked examples in the order shown in the manuscript.
version 18.0
clear all
set more off
set type double
args input_path
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
* BEGIN total
reghdfe outcome did `controls', ///
    absorb(city_id year) vce(cluster respondent_id)
generate byte baseline=e(sample)
* END total
* BEGIN green_paths
generate byte green_sample=baseline & !missing(m_green)
reghdfe m_green did `controls' if green_sample, ///
    absorb(city_id year) vce(cluster respondent_id)
scalar green_a=_b[did]
scalar green_se_individual=_se[did]
reghdfe outcome m_green did `controls' if green_sample, ///
    absorb(city_id year) vce(cluster respondent_id)
scalar green_b=_b[m_green]
* END green_paths
* BEGIN green_common
scalar green_ab=scalar(green_a)*scalar(green_b)
display scalar(green_a) " " scalar(green_b) " " scalar(green_ab)
* END green_common
* BEGIN green_city
reghdfe m_green did `controls' if green_sample, ///
    absorb(city_id year) vce(cluster city_id)
display "a = " _b[did]
display "Individual SE = " scalar(green_se_individual)
display "City SE = " _se[did]
* END green_city
* BEGIN social_paths
reghdfe outcome m_social did `controls' if baseline, ///
    absorb(city_id year) vce(cluster city_id)
generate byte social_sample=e(sample)
scalar path_b=_b[m_social]
scalar path_sb=_se[m_social]
reghdfe m_social did `controls' if social_sample, ///
    absorb(city_id year) vce(cluster city_id)
scalar path_a=_b[did]
scalar path_sa=_se[did]
* END social_paths
* BEGIN sobel
scalar path_ab=scalar(path_a)*scalar(path_b)
scalar path_se=sqrt(scalar(path_b)^2*scalar(path_sa)^2 ///
    + scalar(path_a)^2*scalar(path_sb)^2)
scalar path_z=scalar(path_ab)/scalar(path_se)
scalar path_p=2*normal(-abs(scalar(path_z)))
scalar path_lower=scalar(path_ab)-invnormal(.975)*scalar(path_se)
scalar path_upper=scalar(path_ab)+invnormal(.975)*scalar(path_se)
display scalar(path_ab) " " scalar(path_se) " " scalar(path_p)
display scalar(path_lower) " " scalar(path_upper)
* END sobel
