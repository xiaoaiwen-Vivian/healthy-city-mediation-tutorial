version 18.0
clear all
set more off
set type double

* BEGIN bh
capture program drop bh_adjust
program define bh_adjust
    syntax varname(numeric), Generate(name)
    tempvar original_order rank scaled
    generate long `original_order'=_n
    sort `varlist' `original_order'
    generate long `rank'=_n
    generate double `scaled'=`varlist'*_N/`rank'
    generate double `generate'=min(1,`scaled')
    local last=_N-1
    forvalues j=`last'(-1)1 {
        quietly replace `generate'= ///
            min(`generate',`generate'[_n+1]) in `j'
    }
    sort `original_order'
end
* END bh

* BEGIN product_bh
import delimited using results/stata/city_results.csv, ///
    clear case(preserve)
assert _N==6
bh_adjust Sobel_p, generate(Sobel_BH_6)
bh_adjust sign_tail, generate(sign_tail_BH)
display "City Sobel hypothesis-test p values: BH adjustment across six candidates."
list Mediator Sobel_p Sobel_BH_6, noobs
display "Descriptive bootstrap sign-tail calculations: do not use these values for significance decisions."
list Mediator sign_tail sign_tail_BH, noobs
export delimited using results/stata/city_adjusted.csv, replace
* END product_bh

* Recalculate five testing families and two descriptive groups, six candidates each.
import delimited using results/python/all_bh_families.csv, clear case(preserve)
rename BH expected_BH
levelsof Family, local(families)
tempfile input combined
save `input'
local first 1
foreach family of local families {
    use `input', clear
    keep if Family=="`family'"
    assert _N==6
    bh_adjust input, generate(BH)
    assert abs(BH-expected_BH)<1e-12
    if !`first' append using `combined'
    save `combined', replace
    local first 0
}
drop expected_BH
sort Family Mediator
export delimited using results/stata/all_bh_families.csv, replace
display "All 42 BH values agree across Stata and Python."
display "The two bootstrap-sign groups are descriptive calculations, not validated FDR-controlled tests."
