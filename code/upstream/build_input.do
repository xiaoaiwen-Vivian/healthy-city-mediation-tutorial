version 18.0
clear all
set more off
set maxvar 30000
set type double
set rng mt64
set seed 2025
set sortseed 2025
args mode
if !inlist("`mode'","","build","models") {
    display as error "Supported modes: default, build, models"
    exit 198
}
* Xiaoai: 2015 education uses Harmonized C; 2020 income includes each component once.
* 16,661 is a validation result, never a sample-selection target.
* The anergia item is a proxy; no model here measures suicide directly.
* Constructs the linked analysis input; estimation is run separately.
* Invoked with build by code/upstream/driver.do.
* Paths are initialized by code/upstream/driver.do.
if "$package_root"=="" | "$project"=="" {
    display as error "Run the build-input command from this reproduction package."
    exit 198
}
* Harmonized C is required for the 2015 education definition.
foreach folder in data temp output logs {
    capture mkdir "$project/`folder'"
}
capture log close _all
log using "$project/logs/pipeline_`mode'.log", text replace
foreach cmd in sreshape {
    capture which `cmd'
    if _rc {
        display as error "Missing required command: `cmd'"
        exit 199
    }
}
if "`mode'" != "models" {
confirm file "$harmonized/H_CHARLS_D_Data 2.dta"
confirm file "$harmonizedC/H_CHARLS_C_Data.dta"
* Distinct PSU filenames prevent case-insensitive filesystem collisions.
foreach yy in 2011 2013 {
    if `yy'==2011 use "$raw2011/psu.dta", clear
    else use "$raw2013/PSU.dta", clear
    ds, has(type string)
    foreach vv in `r(varlist)' {
        replace `vv'=ustrfrom(`vv',"gb18030",1) if ustrinvalidcnt(`vv')>0
        assert ustrinvalidcnt(`vv')==0
    }
    save "$temp_data/psu_`yy'_utf8.dta", replace
}
clear
global psu2011 "$temp_data/psu_2011_utf8.dta"
global psu2013 "$temp_data/psu_2013_utf8.dta"
tempname flowpost
tempfile sampleflow
postfile `flowpost' str100 Stage long N using `sampleflow', replace

* ==================== RAW CLEANING ====================
******************************** 2011年数据清洗 ********************************
use "$raw2013/Demographic_Background.dta",clear   //导入数据
keep ID bd001_w2_1 bd001_w2_2 bd001_w2_3
rename (bd001_w2_1 bd001_w2_2 bd001_w2_3) (r2bd001_w2_1 r2bd001_w2_2 r2bd001_w2_3)  //更改名称,避免后续合并造成变量重复
save "$temp_data/2013_Demographic_Background.dta", replace   //保存数据

***合并2011年的原始数据集
use "$raw2011/Demographic_Background.dta",clear    //导入数据
merge 1:1 ID using "$raw2011/health_status_and_functioning.dta",nogen
merge 1:1 ID using "$raw2011/health_care_and_insurance.dta",nogen
merge 1:1 ID using "$raw2011/biomarkers.dta",nogen
* 作者说明：未使用血样指标，本句注释
*merge 1:1 ID using "$raw2011/Blood_20140429.dta",nogen
merge 1:1 ID using "$raw2011/family_transfer.dta",nogen
merge 1:1 ID using "$raw2011/individual_income.dta",nogen
merge 1:1 ID using "$raw2011/interviewer_observation.dta",nogen
merge 1:1 ID using "$raw2011/work_retirement_and_pension.dta",nogen
merge m:1 householdID using "$raw2011/household_income.dta",nogen
merge m:1 householdID using "$raw2011/family_information.dta",nogen
merge m:1 householdID using "$raw2011/household_roster.dta",nogen
merge m:1 householdID using "$raw2011/housing_characteristics.dta",nogen

***残疾
gen r1disability=.
replace r1disability=1 if da005_1_==1 | da005_2_==1 | da005_3_==1 | da005_4_==1 | da005_5_==1 
replace r1disability=0 if da005_1_==2 & da005_2_==2 & da005_3_==2 & da005_4_==2 & da005_5_==2 

***认知能力=心智状况+情景记忆能力(此处的量表得分0-21分)
***心智状况=日期认知+计算+画图能力(11分)
***情景记忆能力=词组回忆(即时回忆+延时回忆)(10分)
***日期认知得分
*月
gen r1mo = .m 
replace r1mo = .d if db032 == .d | dc001s2 == .d
replace r1mo = .r if db032 == .r | dc001s2 == .r
replace r1mo = .p if db032 == 4 | proxy == 1
replace r1mo = 0 if !mi(dc001s1) | !mi(dc001s3) | !mi(dc002)
replace r1mo = 1 if dc001s2 == 2

*日
gen r1dy = .m
replace r1dy = .d if db032 == .d | dc001s3 == .d
replace r1dy = .r if db032 == .r | dc001s3 == .r
replace r1dy = .p if db032 == 4 | proxy == 1
replace r1dy = 0 if !mi(dc001s1) | !mi(dc001s2) | !mi(dc002)
replace r1dy = 1 if dc001s3 == 3 

*年
gen r1yr =.m 
replace r1yr = .d if db032 == .d | dc001s1 == .d
replace r1yr = .r if db032 == .r | dc001s1 == .r
replace r1yr = .p if db032 == 4 | proxy == 1
replace r1yr = 0 if !mi(dc001s2) | !mi(dc001s3) | !mi(dc002)
replace r1yr = 1 if dc001s1 == 1 

*周
gen r1dw =.m
replace r1dw = .d if db032 == .d | dc002 == .d
replace r1dw = .r if db032 == .r | dc002 == .r
replace r1dw = .p if db032 == 4 | proxy == 1
replace r1dw = 0 if dc002 == 2 | (!mi(dc001s1) | !mi(dc001s2) | !mi(dc001s3))
replace r1dw = 1 if dc002 == 1 

*季节
gen r1ds =.m
replace r1ds = .d if db032 == .d | dc003 == .d
replace r1ds = .r if db032 == .r | dc003 == .r
replace r1ds = .p if db032 == 4 | proxy == 1
replace r1ds = 0 if dc003 == 2 | (!mi(dc001s1) | !mi(dc001s2) | !mi(dc001s3))
replace r1ds = 1 if dc003 == 1 

*计算日期认知得分
egen r1date_cognition = rowtotal(r1mo r1dy r1yr r1dw r1ds), m
replace r1date_cognition = .m if (r1mo == .m | r1dy == .m | r1yr == .m | r1dw == .m | r1ds == .m) & mi(r1date_cognition)
replace r1date_cognition = .d if (r1mo == .d | r1dy == .d | r1yr == .d | r1dw == .d | r1ds == .d) & mi(r1date_cognition)
replace r1date_cognition = .r if (r1mo == .r | r1dy == .r | r1yr == .r | r1dw == .r | r1ds == .r) & mi(r1date_cognition)
replace r1date_cognition = .p if (r1mo == .p | r1dy == .p | r1yr == .p | r1dw == .p | r1ds == .p) & mi(r1date_cognition)


***社交活动
recode da056s1-da056s11 (1/11=1) (.e=0)
replace da056s6=1 if da056s7==1
rename (da056s1 da056s2 da056s3 da056s4 da056s5 da056s6 da056s8 da056s11) ///
  (r1act_1 r1act_2 r1act_3 r1act_4 r1act_5 r1act_6 r1act_7 r1act_8)

***各种医保类型
recode ea001s1 ea001s2 ea001s3 ea001s4 ea001s5 ea001s6 ea001s7 ea001s8 ///
  ea001s9 (.e=0) (1/9=1)

rename (ea001s1 ea001s2 ea001s3 ea001s4 ea001s5 ea001s6 ea001s7 ea001s8 ///
  ea001s9) (r1ea001s1 r1ea001s3 r1ea001s4 r1ea001s2 r1ea001s5 r1ea001s6 ///
  r1ea001s7 r1ea001s8 r1ea001s11)   //保持每年的医保名字相同
 
***修改ID 和 householdID
drop if mi(ID)
rename (ID householdID) (id_w1 hhid_w1)
gen householdID = hhid_w1 + "0"
gen ID = householdID + substr(id_w1,-2,2)  //由于2011年ID和2013年不一样

***2013年部分用户声称2011年错误，因此需要修改
merge 1:1 ID using "$temp_data/2013_Demographic_Background.dta" 
drop if _merge==2
replace bd001 = r2bd001_w2_3 if r2bd001_w2_1==2 | (r2bd001_w2_1==1 & r2bd001_w2_2==1)  //上次学历错误或者包含成人教育
rename bd001 r1educ_c

keep ID r1date_cognition r1educ_c r1act_1 r1act_2 r1act_3 r1act_4 r1act_5 r1act_6 ///
  r1act_7 r1act_8 r1ea001s1 r1ea001s2 r1ea001s3 r1ea001s4 r1ea001s5 r1ea001s6 ///
  r1ea001s7 r1ea001s8 r1ea001s11 r1disability
 
save "$temp_data/charls11.dta",replace //保存数据


* =============================================================================
* 第 2 段 / 共 6 段：2013 波清洗 → charls13.dta
*   原文件 no.2_charls_13.do
* =============================================================================

******************************** 2013年数据清理 ********************************
use "$raw2013/Demographic_Background.dta",clear  //导入数据
merge 1:1 ID using "$raw2013/Health_Status_and_Functioning.dta", nogen
merge 1:1 ID using "$raw2013/Health_Care_and_Insurance.dta",nogen
merge 1:1 ID using "$raw2013/Biomarker.dta",nogen
merge 1:1 ID using "$raw2013/Individual_Income.dta",nogen
merge 1:1 ID using "$raw2013/Work_Retirement_and_Pension.dta",nogen
merge m:1 householdID using "$raw2013/Household_Income.dta",nogen
merge m:1 householdID using "$raw2013/Family_Information.dta",nogen
merge m:1 householdID using "$raw2013/Family_Transfer.dta",nogen
merge m:1 householdID using "$raw2013/Housing_Characteristics.dta",nogen

***教育程度
replace zbd001= bd001 if !mi(bd001) & mi(zbd001)  //将新受访者和回访者合并   
replace zbd001 = bd001_w2_3 if bd001_w2_1==2 | (bd001_w2_1==1 & bd001_w2_2==1)   //上次学历错误或者包含成人教育
gen r2educ_c=zbd001                                        
replace r2educ_c=bd001_w2_4 if bd001_w2_4<12               //学历发生改变  

***残疾
gen r2disability=.
replace r2disability=1 if da005_1_==1 | da005_2_==1 | da005_3_==1 | da005_4_==1 | da005_5_==1 
replace r2disability=0 if da005_1_==2 & da005_2_==2 & da005_3_==2 & da005_4_==2 & da005_5_==2 

***日期认知得分
*月
gen r2mo = .m 
replace r2mo = .d if db032 == .d | dc001s2 == .d
replace r2mo = .r if db032 == .r | dc001s2 == .r
replace r2mo = .p if db032 == 4 
replace r2mo = 0 if !mi(dc001s1) | !mi(dc001s3) | !mi(dc002)
replace r2mo = 1 if dc001s2 == 2

*日
gen r2dy = .m
replace r2dy = .d if db032 == .d | dc001s3 == .d
replace r2dy = .r if db032 == .r | dc001s3 == .r
replace r2dy = .p if db032 == 4 
replace r2dy = 0 if !mi(dc001s1) | !mi(dc001s2) | !mi(dc002)
replace r2dy = 1 if dc001s3 == 3 

*年
gen r2yr =.m 
replace r2yr = .d if db032 == .d | dc001s1 == .d
replace r2yr = .r if db032 == .r | dc001s1 == .r
replace r2yr = .p if db032 == 4 
replace r2yr = 0 if !mi(dc001s2) | !mi(dc001s3) | !mi(dc002)
replace r2yr = 1 if dc001s1 == 1 

*周
gen r2dw =.m
replace r2dw = .d if db032 == .d | dc002 == .d
replace r2dw = .r if db032 == .r | dc002 == .r
replace r2dw = .p if db032 == 4 
replace r2dw = 0 if dc002 == 2 | (!mi(dc001s1) | !mi(dc001s2) | !mi(dc001s3))
replace r2dw = 1 if dc002 == 1 

*季节
gen r2ds =.m
replace r2ds = .d if db032 == .d | dc003 == .d
replace r2ds = .r if db032 == .r | dc003 == .r
replace r2ds = .p if db032 == 4 
replace r2ds = 0 if dc003 == 2 | (!mi(dc001s1) | !mi(dc001s2) | !mi(dc001s3))
replace r2ds = 1 if dc003 == 1 

*计算日期认知得分
egen r2date_cognition = rowtotal(r2mo r2dy r2yr r2dw r2ds), m
replace r2date_cognition = .m if (r2mo == .m | r2dy == .m | r2yr == .m | r2dw == .m | r2ds == .m) & mi(r2date_cognition)
replace r2date_cognition = .d if (r2mo == .d | r2dy == .d | r2yr == .d | r2dw == .d | r2ds == .d) & mi(r2date_cognition)
replace r2date_cognition = .r if (r2mo == .r | r2dy == .r | r2yr == .r | r2dw == .r | r2ds == .r) & mi(r2date_cognition)
replace r2date_cognition = .p if (r2mo == .p | r2dy == .p | r2yr == .p | r2dw == .p | r2ds == .p) & mi(r2date_cognition)


***社交活动
recode da056s* (1/11=1) (.=0)
replace da056s6=1 if da056s7==1
rename (da056s1 da056s2 da056s3 da056s4 da056s5 da056s6 da056s8 da056s11) ///
 (r2act_1 r2act_2 r2act_3 r2act_4 r2act_5 r2act_6 r2act_7 r2act_8)

***各种医保类型
recode ea001s1 ea001s2 ea001s3 ea001s4 ea001s5 ea001s6 ea001s7 ea001s8 ///
 ea001s9 ea001s10 (.=0) (1/10=1)
rename (ea001s1 ea001s2 ea001s3 ea001s4 ea001s5 ea001s6 ea001s7 ea001s8 ///
 ea001s9 ea001s10) (r2ea001s1 r2ea001s3 r2ea001s4 r2ea001s2 r2ea001s5 r2ea001s6 ///
 r2ea001s7 r2ea001s8 r2ea001s9 r2ea001s11)


***保留所需变量
keep ID r2educ_c r2date_cognition r2act_1 r2act_2 r2act_3 r2act_4 r2act_5 r2act_6 ///
  r2act_7 r2act_8 r2ea001s1 r2ea001s3 r2ea001s4 r2ea001s2 r2ea001s5 r2ea001s6 ///
  r2ea001s7 r2ea001s8 r2ea001s9 r2ea001s11 r2disability
  
save "$temp_data/charls13.dta",replace	 //保存数据


* =============================================================================
* 第 3 段 / 共 6 段：2015 波清洗 → charls15.dta
*   原文件 no.3_charls_15.do
* =============================================================================

******************************** 2015年数据清理 ********************************
***教育程度
*使用H_CHARLS_C_Data.dta识别
use "$harmonizedC/H_CHARLS_C_Data.dta", clear
merge 1:1 ID using "$raw2015/Health_Status_and_Functioning.dta", nogen	
merge 1:1 ID using "$raw2015/Health_Care_and_Insurance.dta", nogen	
merge 1:1 ID using "$raw2015/Biomarker.dta", nogen	
* 作者说明：未使用血样指标，本句注释
*merge 1:1 ID using "$raw2015/Blood.dta", nogen	
merge 1:1 ID using "$raw2015/Demographic_Background.dta", nogen	
merge 1:1 ID using "$raw2015/Individual_Income.dta", nogen	
merge m:1 householdID using "$raw2015/Household_Income.dta",nogen	
merge m:1 householdID using "$raw2015/Family_Information.dta", nogen	
merge m:1 householdID using "$raw2015/Family_Transfer.dta", nogen	
merge m:1 householdID using "$raw2015/Household_Income.dta", nogen	
merge m:1 householdID using "$raw2015/Housing_Characteristics.dta", nogen	


***教育
gen r3educ_c=raeduc_c
keep if inw4==1 // C version: inw4 denotes the 2015 interview.

***残疾
forvalues i=1/5 {
  replace da005_`i'_=zda005_`i'_ if mi(da005_`i'_) & !mi(zda005_`i'_)
}

gen r3disability=.
replace r3disability=1 if da005_1_==1 | da005_2_==1 | da005_3_==1 | da005_4_==1 | da005_5_==1 
replace r3disability=0 if da005_1_==2 & da005_2_==2 & da005_3_==2 & da005_4_==2 & da005_5_==2 		
				
***日期认知得分
*月
gen r3mo = .m 
replace r3mo = .d if db032 == .d | dc001s2 == .d
replace r3mo = .r if db032 == .r | dc001s2 == .r
replace r3mo = .p if db032 == 4 | proxy == 1
replace r3mo = 0 if !mi(dc001s1) | !mi(dc001s3) | !mi(dc002)
replace r3mo = 1 if dc001s2 == 2

*日
gen r3dy = .m
replace r3dy = .d if db032 == .d | dc001s3 == .d
replace r3dy = .r if db032 == .r | dc001s3 == .r
replace r3dy = .p if db032 == 4 | proxy == 1
replace r3dy = 0 if !mi(dc001s1) | !mi(dc001s2) | !mi(dc002)
replace r3dy = 1 if dc001s3 == 3 

*年
gen r3yr =.m 
replace r3yr = .d if db032 == .d | dc001s1 == .d
replace r3yr = .r if db032 == .r | dc001s1 == .r
replace r3yr = .p if db032 == 4 | proxy == 1
replace r3yr = 0 if !mi(dc001s2) | !mi(dc001s3) | !mi(dc002)
replace r3yr = 1 if dc001s1 == 1 

*周
gen r3dw =.m
replace r3dw = .d if db032 == .d | dc002 == .d
replace r3dw = .r if db032 == .r | dc002 == .r
replace r3dw = .p if db032 == 4 | proxy == 1
replace r3dw = 0 if dc002 == 2 | (!mi(dc001s1) | !mi(dc001s2) | !mi(dc001s3))
replace r3dw = 1 if dc002 == 1 

*季节
gen r3ds =.m
replace r3ds = .d if db032 == .d | dc003 == .d
replace r3ds = .r if db032 == .r | dc003 == .r
replace r3ds = .p if db032 == 4 | proxy == 1
replace r3ds = 0 if dc003 == 2 | (!mi(dc001s1) | !mi(dc001s2) | !mi(dc001s3))
replace r3ds = 1 if dc003 == 1 

*计算日期认知得分
egen r3date_cognition = rowtotal(r3mo r3dy r3yr r3dw r3ds), m
replace r3date_cognition = .m if (r3mo == .m | r3dy == .m | r3yr == .m | r3dw == .m | r3ds == .m) & mi(r3date_cognition)
replace r3date_cognition = .d if (r3mo == .d | r3dy == .d | r3yr == .d | r3dw == .d | r3ds == .d) & mi(r3date_cognition)
replace r3date_cognition = .r if (r3mo == .r | r3dy == .r | r3yr == .r | r3dw == .r | r3ds == .r) & mi(r3date_cognition)
replace r3date_cognition = .p if (r3mo == .p | r3dy == .p | r3yr == .p | r3dw == .p | r3ds == .p) & mi(r3date_cognition)


***社交活动
recode da056s* (1/11=1) (.=0)
replace da056s6=1 if da056s7==1
rename (da056s1 da056s2 da056s3 da056s4 da056s5 da056s6 da056s8 da056s11) ///
 (r3act_1 r3act_2 r3act_3 r3act_4 r3act_5 r3act_6 r3act_7 r3act_8)

***各种医保类型
forvalue i=1/10{
 gen r3ins`i'=. 
 replace r3ins`i'=0 if !mi(ea001_w3_1_`i'_) | !mi(ea001_w3_2_`i'_ ) | !mi(ea001_w3_3_`i'_)
 replace r3ins`i'=1 if ea001_w3_2_`i'_==1 | ea001_w3_3_`i'_==1
 replace r3ins`i'=. if mi(ea001_w3_2_`i'_) & mi(ea001_w3_3_`i'_)
}
rename (r3ins1 r3ins2 r3ins3 r3ins4 r3ins5 r3ins6 r3ins7 r3ins8 r3ins9 r3ins10) ///
(r3ea001s1 r3ea001s3 r3ea001s4 r3ea001s2 r3ea001s5 r3ea001s6 r3ea001s7 r3ea001s8 ///
r3ea001s9 r3ea001s11)

  
***保存所需变量  
keep ID r3educ_c r3date_cognition r3act_1 r3act_2 r3act_3 r3act_4 r3act_5 r3act_6 ///
  r3act_7 r3act_8 r3ea001s1 r3ea001s2 r3ea001s3 r3ea001s4 r3ea001s5 r3ea001s6 ///
  r3ea001s7 r3ea001s8 r3ea001s9 r3ea001s11 r3disability

save "$temp_data/charls15.dta",replace	 //保存数据


* =============================================================================
* 第 4 段 / 共 6 段：2018 波清洗 → charls18.dta
*   原文件 no.4_charls_18.do
* =============================================================================

******************************** 2018年数据清理 ********************************
use "$raw2018/Cognition.dta", clear
merge 1:1 ID using "$raw2018/Health_Status_and_Functioning.dta",nogen
merge 1:1 ID using "$raw2018/Demographic_Background.dta",nogen
merge 1:1 ID using "$raw2018/Health_Care_and_Insurance.dta",nogen
merge 1:1 ID using "$raw2018/Individual_Income.dta",nogen
merge 1:1 ID using "$raw2018/Pension.dta",nogen
merge 1:1 ID using "$raw2018/Work_Retirement.dta",nogen
merge m:1 householdID using "$raw2018/Household_Income.dta",nogen
merge m:1 householdID using "$raw2018/Family_Transfer.dta",nogen
merge m:1 householdID using "$raw2018/Household_Income.dta",nogen

***残疾
forvalues i=1/5 {
  replace da005_`i'_=zdisability_`i'_ if mi(da005_`i'_) & !mi(zdisability_`i'_)
}
gen r4disability=.
replace r4disability=1 if da005_1_==1 | da005_2_==1 | da005_3_==1 | da005_4_==1 | da005_5_==1 
replace r4disability=0 if da005_1_==2 & da005_2_==2 & da005_3_==2 & da005_4_==2 & da005_5_==2 


***日期认知得分
*月
gen r4mo = .m 
replace r4mo = .n if dc006_w4 == 97
replace r4mo = .p if db032 == 4
replace r4mo = 0 if dc006_w4 == 5
replace r4mo = 1 if dc006_w4 == 1

*日
gen r4dy = .m 
replace r4dy = .n if dc003_w4 == 97
replace r4dy = .p if db032 == 4
replace r4dy = 0 if dc003_w4 == 5
replace r4dy = 1 if dc003_w4 == 1

*年
gen r4yr = .m 
replace r4yr = .n if dc001_w4 == 97
replace r4yr = .p if db032 == 4
replace r4yr = 0 if dc001_w4 == 5
replace r4yr = 1 if dc001_w4 == 1

*星期
gen r4dw = .m 
replace r4dw = .n if dc005_w4 == 97
replace r4dw = .p if db032 == 4
replace r4dw = 0 if dc005_w4 == 5
replace r4dw = 1 if dc005_w4 == 1

*季节
gen r4ds = .m 
replace r4ds = .n if dc002_w4 == 97
replace r4ds = .p if db032 == 4
replace r4ds = 0 if dc002_w4 == 5
replace r4ds = 1 if dc002_w4 == 1


*计算日期认知得分
egen r4date_cognition = rowtotal(r4mo r4dy r4yr r4dw r4ds), m
replace r4date_cognition = .m if (r4mo == .m | r4dy == .m | r4yr == .m | r4dw == .m | r4ds == .m ) & mi(r4date_cognition)
replace r4date_cognition = .n if (r4mo == .n | r4dy == .n | r4yr == .n | r4dw == .n | r4ds == .n ) & mi(r4date_cognition)
replace r4date_cognition = .p if (r4mo == .p | r4dy == .p | r4yr == .p | r4dw == .p | r4ds == .p ) & mi(r4date_cognition)

***社交活动
recode da056_s* (1/11=1) 
replace da056_s6=1 if da056_s7==1
rename (da056_s1 da056_s2 da056_s3 da056_s4 da056_s5 da056_s6 da056_s8 da056_s11) ///
 (r4act_1 r4act_2 r4act_3 r4act_4 r4act_5 r4act_6 r4act_7 r4act_8)


***民族
recode bg001_w4 (1=1) (2/11=0) (else=.),gen (nation)

***各种医保类型
recode ea001_w4_s* (1/11=1)
rename (ea001_w4_s1 ea001_w4_s2 ea001_w4_s3 ea001_w4_s4 ea001_w4_s5 ///
 ea001_w4_s6 ea001_w4_s7 ea001_w4_s8 ea001_w4_s9 ea001_w4_s10 ea001_w4_s11) ///
 (r4ea001s1 r4ea001s2 r4ea001s3 r4ea001s4 r4ea001s5 r4ea001s6 r4ea001s7 ///
 r4ea001s8 r4ea001s9 r4ea001s10 r4ea001s11)

 
***保存所需变量  
keep ID r4date_cognition r4act_1 r4act_2 r4act_3 r4act_4 r4act_5 r4act_6 r4act_7 ///
 r4act_8 nation r4ea001s1 r4ea001s2 r4ea001s3 r4ea001s4 r4ea001s5 r4ea001s6 r4ea001s7 ///
 r4ea001s8 r4ea001s9 r4ea001s10 r4ea001s11 r4disability
  
save "$temp_data/charls18.dta",replace	 //保存数据


* =============================================================================
* 第 5 段 / 共 6 段：2020 波清洗 → charls2020.dta
*   原文件 no.5_charls_20.do
* =============================================================================

****************************************************************************
use "$raw2020/Demographic_Background.dta",clear 
*merge 1:1 ID using "$raw2020/Exit_Module.dta",nogen
merge 1:1 ID using "$raw2020/Health_Status_and_Functioning.dta",nogen
merge 1:1 ID using "$raw2020/Individual_Income.dta",nogen
merge 1:1 ID using "$raw2020/Sample_Infor.dta",nogen
merge 1:1 ID using "$raw2020/Weights.dta",nogen
merge 1:1 ID using "$raw2020/Work_Retirement.dta",nogen
merge m:1 householdID using "$raw2020/Family_Information.dta",nogen
merge m:1 householdID using "$raw2020/Household_Income.dta",nogen
merge m:1 communityID using "$psu2011",keep(match) nogen   //已转 UTF-8 的副本

***居住地
recode urban_nbs (0=1) (1=0),gen(h5rural)

***是否参与第五次调查
gen inw5=0
replace inw5=1 if !mi(ba001)  //未回答视为未参与本次调查

***家庭人口数
gen pnc=substr(ID,10,2) 
destring pnc, gen(pn)
bysort householdID: egen h5hhresp=count(pn) if inw5==1

* 如果cb001或cb002是"99"或空白，将其设为缺失值
replace cb001 = "" if cb001 == "99"
replace cb002 = "" if cb002 == "99"

* 使用split命令将cb001和cb002分割成多个变量
split cb001, generate(cb001_split) parse("~")
split cb002, generate(cb002_split) parse("~")

* 将分割后的字符串变量转换为数值变量
foreach var of varlist cb001_split* cb002_split* {
    destring `var', replace
}

* 计算cb001和cb002中的人数
egen count_cb001 = rownonmiss(cb001_split*)
egen count_cb002 = rownonmiss(cb002_split*)

* 计算总人数
egen h5hhres= rowtotal(count_cb001 count_cb002 h5hhresp),mi
replace h5hhres=. if mi(count_cb001) | mi(count_cb002) | mi(h5hhresp)

***年龄
replace zrbirthyear=ba003_1 if zrbirthyear==.

***性别
* 修正：2020 波性别改用 CHARLS 自带的跨波校正变量 xrgender。
* 原写法 rename ba001 r5gender 取的是本波原始作答；现有 charls.dta 里的
* gender 实际与 xrgender 逐行一致（96,628 行零差异），ba001 会差 29 行 / 9 人。
rename xrgender r5gender
capture rename ba001 ba001_raw2020   //本波原始作答，仅 inw5 判定用过，不再保留

***教育背景
replace zredu=ba010 if mi(zredu) & !mi(ba010)
rename zredu r5educ_c

***婚姻状况
gen r5mstath=.
replace r5mstath=1 if ba011==1
replace r5mstath=2 if ba011==2
replace r5mstath=4 if ba011==3
replace r5mstath=5 if ba011==4
replace r5mstath=7 if ba011==5
replace r5mstath=8 if ba011==6
replace r5mstath=3 if ba012==1

***户口
recode ba009 (1=1) (2/3=0) (else=.),gen(r5rural2)

***自评健康
recode da001 (997=.),gen(r5shlta)

***曾经是否吸烟
replace da046= zsmoke if !mi(zsmoke) & mi(da046)
recode da046 (1=1) (2=0),gen(r5smokev)

***现在是否吸烟
recode da047 (1=1) (2/3=0),gen(r5smoken) 
replace r5smoken=0 if da046==2

***现在饮酒
recode da051 (1/2=1) (3=0),gen(r5drinkl)

***锻炼
gen r5vgact_c =.
replace r5vgact_c = 1 if da032_1_==1
replace r5vgact_c = 0 if da032_1_==2

gen r5mdact_c =.
replace r5mdact_c = 1 if da032_2_==1
replace r5mdact_c = 0 if da032_2_==2

gen r5ltact_c =.
replace r5ltact_c = 1 if da032_3_==1
replace r5ltact_c = 0 if da032_3_==2 

***社交活动
recode da038_s1-da038_s8 (1/8=1)

forvalues i=1/8 {
  rename da038_s`i' r5act_`i'
}

***认知能力=心智状况+情景记忆能力(此处适用于经济学)
*心智状况(认知完整性)=日期认知+计算+画图能力
*情景记忆能力=词组回忆(即时回忆+延时回忆)
*词组即时回忆
recode dc012_s1 dc012_s2 dc012_s3 dc012_s4 dc012_s5 dc012_s6 dc012_s7 ///
  dc012_s8 dc012_s9 dc012_s10 (1/10=1)
egen r5imrc = rowtotal(dc012_s1 dc012_s2 dc012_s3 dc012_s4 dc012_s5 ///
  dc012_s6 dc012_s7 dc012_s8 dc012_s9 dc012_s10) 
replace r5imrc = .m if mi(dc012_s1) & mi(dc012_s2) & mi(dc012_s3) & ///
  mi(dc012_s4) & mi(dc012_s5) & mi(dc012_s6) & mi(dc012_s7) & mi(dc012_s8) & mi(dc012_s9) & mi(dc012_s10) 
  
replace r5imrc = .d if (db045 == .d | dc012_s1 == .d | dc012_s2 == .d | dc012_s3 == .d | dc012_s4 == .d | ///
                           dc012_s5 == .d | dc012_s6 == .d | dc012_s7 == .d | dc012_s8 == .d | ///
                           dc012_s9 == .d | dc012_s10 == .d) & mi(r5imrc)
replace r5imrc = .r if (db045 == .r | dc012_s1 == .r | dc012_s2 == .r | dc012_s3 == .r | dc012_s4 == .r | ///
                           dc012_s5 == .r | dc012_s6 == .r | dc012_s7 == .r | dc012_s8 == .r | ///
                           dc012_s9 == .r | dc012_s10 == .r) & mi(r5imrc)
replace r5imrc = .p if (db045 == 4 | proxy_5 == 1) & mi(r5imrc)

*词组延迟回忆
recode dc028_s1 dc028_s2 dc028_s3 dc028_s4 dc028_s5 dc028_s6 dc028_s7 ///
  dc028_s8 dc028_s9 dc028_s10 (1/10=1) 
egen r5dlrc = rowtotal(dc028_s1 dc028_s2 dc028_s3 dc028_s4 dc028_s5 ///
  dc028_s6 dc028_s7 dc028_s8 dc028_s9 dc028_s10) 
replace r5dlrc = .m if mi(dc028_s1) & mi(dc028_s2) & mi(dc028_s3) & /// 
  mi(dc028_s4) & mi(dc028_s5) & mi(dc028_s6) & mi(dc028_s7) & mi(dc028_s8) & mi(dc028_s9) & mi(dc028_s10)
replace r5dlrc = .d if (db045 == .d | dc028_s1 == .d | dc028_s2 == .d | dc028_s3 == .d | dc028_s4 == .d | ///
                           dc028_s5 == .d | dc028_s6 == .d | dc028_s7 == .d | dc028_s8 == .d | ///
                           dc028_s9 == .d | dc028_s10 == .d) & mi(r5dlrc)
replace r5dlrc = .r if (db045 == .r | dc028_s1 == .r | dc028_s2 == .r | dc028_s3 == .r | dc028_s4 == .r | ///
                           dc028_s5 == .r | dc028_s6 == .r | dc028_s7 == .r | dc028_s8 == .r | ///
						   dc028_s9 == .r | dc028_s10 == .r) & mi(r5dlrc)
                        
***计算词组回忆得分=(词组即时回忆+词组延迟回忆)/2   
gen r5memeory =.
replace r5memeory = .m if r5imrc == .m | r5dlrc == .m
replace r5memeory = .d if r5imrc == .d | r5dlrc == .d
replace r5memeory = .r if r5imrc == .r | r5dlrc == .r
replace r5memeory = .p if r5imrc == .p | r5dlrc == .p
replace r5memeory = (r5imrc + r5dlrc)/2 if !mi(r5imrc) & !mi(r5dlrc)

***日期认知得分
recode dc001-dc005 (997=.d) (999=.r)

*月
gen r5mo = .m 
replace r5mo = .d if dc005 == .d
replace r5mo = .r if dc005 == .r
replace r5mo = .p if db045 == 4 | proxy_5 == 1
replace r5mo = 0 if dc005 == 2 | (!mi(dc001) | !mi(dc002) | !mi(dc003) | !mi(dc004))
replace r5mo = 1 if dc005 == 1

*日
gen r5dy = .m 
replace r5dy = .d if dc003 == .d
replace r5dy = .r if dc003 == .r
replace r5dy = .p if db045 == 4 | proxy_5 == 1
replace r5dy = 0 if dc003 == 2 | (!mi(dc001) | !mi(dc002) | !mi(dc004) | !mi(dc005))
replace r5dy = 1 if dc003 == 1

*年份
gen r5yr = .m 
replace r5yr = .d if dc001 == .d
replace r5yr = .r if dc001 == .r
replace r5yr = .p if db045 == 4 | proxy_5 == 1
replace r5yr = 0 if dc001 == 2 | (!mi(dc002) | !mi(dc003) | !mi(dc004) | !mi(dc005))
replace r5yr = 1 if dc001 == 1

*星期
gen r5dw = .m 
replace r5dw = .d if dc002 == .d
replace r5dw = .r if dc002 == .r
replace r5dw = .p if db045 == 4 | proxy_5 == 1
replace r5dw = 0 if dc004 == 2 | (!mi(dc001) | !mi(dc002) | !mi(dc003) | !mi(dc005))
replace r5dw = 1 if dc004 == 1 

*季节
gen r5ds = .m 
replace r5ds = .d if dc002 == .d
replace r5ds = .r if dc002 == .r
replace r5ds = .p if db045 == 4 | proxy_5 == 1
replace r5ds = 0 if dc002 == 2 | (!mi(dc001) | !mi(dc003) | !mi(dc004) | !mi(dc005))
replace r5ds = 1 if dc002 == 1

***日期认知能力得分
egen r5date_cognition = rowtotal(r5mo r5dy r5yr r5dw r5ds), m
replace r5date_cognition = .m if (r5mo == .m | r5dy == .m | r5yr == .m | r5dw == .m | r5ds == .m) & mi(r5date_cognition)
replace r5date_cognition = .d if (r5mo == .d | r5dy == .d | r5yr == .d | r5dw == .d | r5ds == .d) & mi(r5date_cognition)
replace r5date_cognition = .r if (r5mo == .r | r5dy == .r | r5yr == .r | r5dw == .r | r5ds == .r) & mi(r5date_cognition)
replace r5date_cognition = .p if (r5mo == .p | r5dy == .p | r5yr == .p | r5dw == .p | r5ds == .p) & mi(r5date_cognition)


*画图能力得分
recode dc009 (997=.d) (999=.r)
gen r5draw = .m 
replace r5draw = .d if dc009 == .d
replace r5draw = .r if dc009 == .r
replace r5draw = .p if db045 == 4 | proxy_5 == 1
replace r5draw = 0 if dc009 == 2
replace r5draw = 1 if dc009 == 1


*数学题得分
recode dc007_1 dc007_2 dc007_3 dc007_4 dc007_5 (997=.d) (999=.r)
gen r5ser7 =.m
replace r5ser7 =.d if dc007_1==.d | dc007_2==.d | dc007_3==.d | dc007_4==.d | dc007_5==.d  
replace r5ser7 =.d if dc007_1_1==.d | dc007_2_1==.d | dc007_3_1==.d | dc007_4_1==.d | dc007_5_1==.d  
replace r5ser7 =.r if dc007_1==.r | dc007_2==.r | dc007_3==.r | dc007_4==.r | dc007_5==.r  
replace r5ser7 =.r if dc007_1_1==.r| dc007_2_1==.r | dc007_3_1==.r | dc007_4_1==.r | dc007_5_1==.r  
replace r5ser7 =.p if db045 == 4 | proxy_5 == 1
replace r5ser7 = 0 if !mi(dc007_1_1) | !mi(dc007_2_1) | !mi(dc007_3_1) | !mi(dc007_4_1) | !mi(dc007_5_1)
replace r5ser7 = r5ser7 + 1 if dc007_1_1 == 93
replace r5ser7 = r5ser7 + 1 if dc007_2_1 == (dc007_1_1 - 7) & !mi(dc007_1_1) & !mi(dc007_2_1)
replace r5ser7 = r5ser7 + 1 if dc007_3_1 == (dc007_2_1 - 7) & !mi(dc007_2_1) & !mi(dc007_3_1)
replace r5ser7 = r5ser7 + 1 if dc007_4_1 == (dc007_3_1 - 7) & !mi(dc007_3_1) & !mi(dc007_4_1)
replace r5ser7 = r5ser7 + 1 if dc007_5_1 == (dc007_4_1 - 7) & !mi(dc007_4_1) & !mi(dc007_5_1) 

*计算心智状况
egen r5executive=rowtotal(r5ser7 r5date_cognition r5draw),mi  //日期、绘画和减法
replace r5executive=.m if mi(r5date_cognition) | mi(r5ser7) | mi(r5draw)  
replace r5executive=.d if r5date_cognition==.d | r5ser7==.d | r5draw==.d
replace r5executive=.r if r5date_cognition==.r | r5ser7==.r | r5draw==.r  
replace r5executive=.p if r5date_cognition==.p | r5ser7==.p | r5draw==.p    

*计算认知能力总得分
egen r5total_cognition=rowtotal(r5memeory r5executive),mi //认知能力=情景记忆+心智状况
replace r5total_cognition=.m if mi(r5executive) | mi(r5memeory)
replace r5total_cognition=.d if r5executive==.d | r5memeory==.d
replace r5total_cognition=.r if r5executive==.r | r5memeory==.r
replace r5total_cognition=.p if r5executive==.p | r5memeory==.p 

***抑郁
recode dc020 dc023 (1=4) (2=3) (3=2) (4=1)  //反向编码
recode dc016-dc025 (1=0) (2=1) (3=2) (4=3) (else=.) 
egen r5cesd10=rowtotal(dc016 dc017 dc018 dc019 dc020 dc021 dc022 dc023 dc024 dc025),mi
replace r5cesd10=. if dc016==. | dc017==. | dc018==. | dc019==. | dc020==. | ///
  dc021==. | dc022==. | dc023==. | dc024==. | dc025==.

***慢性病
forvalues i=1/15 {
  replace da003_`i'_= zdisease_`i'_ if da003_`i'_==.
  recode da003_`i'_ (1=1) (2=0)
}

replace da003_12_=1 if da003_13_==1
rename (da003_1_ da003_2_ da003_3_ da003_4_ da003_5_ da003_6_ da003_7_ da003_8_ ///
 da003_9_ da003_10_ da003_11_ da003_12_ da003_14_ da003_15_) (r5hibpe r5dyslipe ///
 r5diabe r5cancre r5lunge r5livere r5hearte r5stroke r5kidneye r5digeste r5psyche ///
 r5memrye r5arthre r5asthmae)
 
***家庭总消费
*周消费
gen hh5cbfood=.
replace gf006=gf006 + gf008 if gf007==1 & !mi(gf008) & !mi(gf006)  //增加自家生产
replace hh5cbfood = gf006 if inrange(gf006,0,200000)

gen hh5codinn=.
replace hh5codinn = gf009 if inrange(gf009,0,200000)

gen hh5cacct=.
replace hh5cacct = gf010 if inrange(gf010,0,200000) 
 
gen hh5cfood =.
replace hh5cfood = hh5cbfood + hh5codinn + hh5cacct if ///
                    !mi(hh5cbfood) & !mi(hh5codinn) & !mi(hh5cacct)
 
*月消费
gen hh5ccomu=. 
replace hh5ccomu = gf011_1 if inrange(gf011_1,0,99999)

gen hh5cutil=.
replace hh5cutil = gf011_2 if inrange(gf011_2,0,99999)

gen hh5cfuel=.
replace hh5cfuel = gf011_3 if inrange(gf011_3,0,99999)

gen hh5cserv=.
replace hh5cserv = gf011_4 if inrange(gf011_4,0,99999)

gen hh5ctran=.
replace hh5ctran = gf011_5 if inrange(gf011_5,0,99999)

gen hh5cday=.
replace hh5cday = gf011_6 if inrange(gf011_6,0,99999)

gen hh5centa=.
replace hh5centa = gf011_7 if inrange(gf011_7,0,99999) 
 
*年消费
gen hh5cnf1m =.
replace hh5cnf1m = hh5ccomu + hh5cutil + hh5cfuel + hh5cserv +  ///
  hh5ctran + hh5cday + hh5centa if !mi(hh5ccomu) & !mi(hh5cutil) & ///
  !mi(hh5cfuel) & !mi(hh5cserv) & !mi(hh5ctran) & !mi(hh5cday) & !mi(hh5centa)

***
forvalues i=1/16 {
  replace gf013_`i'=. if inlist(gf013_`i',-1)
}
 
gen hh5cnf1y =.
replace hh5cnf1y = gf013_1 + gf013_2 + gf013_3 + gf013_4 + gf013_5 + ///
  gf013_6 + gf013_7 + gf013_8 + gf013_9 + gf013_10 + gf013_11 + gf013_12 + ///
  gf013_13 + gf013_14 + gf013_15 + gf013_16 if !mi(gf013_1) & !mi(gf013_2) & ///
  !mi(gf013_3) & !mi(gf013_4) & !mi(gf013_5) & !mi(gf013_6) & !mi(gf013_7) & ///
  !mi(gf013_8) & !mi(gf013_9) & !mi(gf013_10) & !mi(gf013_11) & !mi(gf013_12) & ///
  !mi(gf013_13) & !mi(gf013_14) & !mi(gf013_15) & !mi(gf013_16) 
   
***总消费   
gen hh5cfooda =.
replace hh5cfooda = hh5cfood*52 if !mi(hh5cfood)

gen hh5cnf1ma =.
replace hh5cnf1ma = hh5cnf1m*12 if !mi(hh5cnf1m)

gen hh5ctot =.
replace hh5ctot = hh5cfooda + hh5cnf1ma + hh5cnf1y if ///
                !mi(hh5cfooda) & !mi(hh5cnf1ma) & !mi(hh5cnf1y)
gen hh5cperc = hh5ctot/h5hhres		//人均消费


***受访时间
* 原始 xiwyear 在第五波 19,395 人里有 34 条缺失、4 条异常（2017×2、2018×2），
* 其中 2 条会与前面波次形成重复的 ID-iwy 合并键。第五波统一定为 2020，
* 与现有 charls.dta 的口径一致（该文件第五波 iwy 全部为 2020）。
rename xiwyear r5iwy_raw
gen r5iwy = 2020 if inw5 == 1
capture rename xiwmonth r5iwm

***健在子女数量   
recode ca002_*_  (1=1) (2=0)   
egen h5child=rowtotal(ca002_1_ ca002_2_ ca002_3_ ca002_4_ ca002_5_ ca002_6_ ///
  ca002_7_ ca002_8_ ca002_9_ ca002_10_ ca002_11_ ca002_12_ ca002_13_ ca002_14_ ///
  ca002_15_ ca002_16_ ca002_17_) 
  
***养老保险
recode ba014 (1/6=1) (7=0),gen(r5pension)

***医疗保险
recode ba016 (1/2=1) (3=0),gen(r5ins)   

***各种医保类型
tab ba017,gen(r5ea001s)
rename r5ea001s6 r5ea001s11  

***生活满意度
recode dc026 (1=5) (2=4) (3=3) (4=2) (5=1),gen(r5satlife)

***日常活动
recode db001 db003 db005 db007 db009 db011 (1=0) (2/4=1)
egen r5adlab_c=rowtotal(db001 db003 db005 db007 db009 db011),mi

***工具性日常活动
recode db012 db014 db016 db020 db022 (1=0) (2/4=1)
egen r5iadl=rowtotal(db012 db014 db016 db020 db022),mi

***子女对父母的经济支持
forvalues i=1/17 {
  recode ca017_1_`i'_ ca017_1_min_`i'_ ca017_1_max_`i'_ (-1=.) 
  replace ca017_1_`i'_=(ca017_1_min_`i'_ + ca017_1_max_`i'_)/2 if mi(ca017_1_`i'_) & !mi(ca017_1_min_`i'_) & !mi(ca017_1_max_`i'_)
}

forvalues i=1/17 {
  recode ca017_3_`i'_ ca017_3_min_`i'_ ca017_3_max_`i'_ (-1=.) 
  replace ca017_3_`i'_=(ca017_3_min_`i'_ + ca017_3_max_`i'_)/2 if !mi(ca017_3_min_`i'_) | !mi(ca017_3_max_`i'_)
}

***父母对子女的经济支持
forvalues i=1/11 {
  recode ca018_1_`i'_ ca018_1_min_`i'_ ca018_1_max_`i'_ (-1=.) 
  replace ca018_1_`i'_=(ca018_1_min_`i'_ + ca018_1_max_`i'_)/2 if mi(ca018_1_`i'_) & !mi(ca018_1_min_`i'_) & !mi(ca018_1_max_`i'_)
}

forvalues i=1/9 {
  recode ca018_3_`i'_ ca018_3_min_`i'_ ca018_3_max_`i'_ (-1=.) 
  replace ca018_3_`i'_=(ca018_3_min_`i'_ + ca018_3_max_`i'_)/2 if !mi(ca018_3_min_`i'_) | !mi(ca018_3_max_`i'_)
}  
  
egen h5fcamt=rowtotal(ca017_1_1_ ca017_1_2_ ca017_1_3_ ca017_1_4_ ca017_1_5_ ///
  ca017_1_6_ ca017_1_7_ ca017_1_8_ ca017_1_9_ ca017_1_10_ ca017_1_11_ ca017_1_12_ ///
  ca017_1_13_ ca017_1_14_ ca017_1_15_ ca017_1_16_ ca017_1_17_ ca017_3_1_ ///
  ca017_3_2_ ca017_3_3_ ca017_3_4_ ca017_3_5_ ca017_3_6_ ca017_3_7_ ca017_3_8_ ///
  ca017_3_9_ ca017_3_10_ ca017_3_11_ ca017_3_12_ ca017_3_13_ ca017_3_14_ ///
  ca017_3_15_ ca017_3_16_ ca017_3_17_)

egen h5tcamt=rowtotal(ca018_1_1_ ca018_1_2_ ca018_1_3_ ca018_1_4_ ca018_1_5_ ///
  ca018_1_6_ ca018_1_7_ ca018_1_8_ ca018_1_9_ ca018_1_10_ ca018_1_11_ ///
  ca018_1_12_ ca018_1_13_ ca018_1_14_ ca018_1_15_ ca018_1_16_ ca018_1_17_ ///
  ca018_3_1_ ca018_3_2_ ca018_3_3_ ca018_3_4_ ca018_3_5_ ca018_3_6_ ///
  ca018_3_7_ ca018_3_8_ ca018_3_9_ ca018_3_10_ ca018_3_11_ ca018_3_12_ ///
  ca018_3_13_ ca018_3_14_ ca018_3_15_ ca018_3_16_ ca018_3_17_)
  
***其他家户成员的工资收入
forvalues i=1/11 {
  replace gb003_`i'_=0 if gb002_`i'_==2  
  replace gb003_`i'_=.d if gb002_`i'_==997  //不知道,下同
  replace gb003_`i'_=.r if gb002_`i'_==999  //拒绝回答,下同
  recode gb003_`i'_ (-1=.d)
}

foreach i of numlist 1/7 11 {
  replace gb003_`i'_=(gb003_min_`i'_ + gb003_max_`i'_)/2 if mi(gb003_`i'_) & gb003_min_`i'_>=0 & !mi(gb003_min_`i'_) & gb003_max_`i'_>=0 & !mi(gb003_max_`i'_)
}

*其他家户成员的工资收入应扣除的杂费部分
forvalues i=1/11 {
 gen gb004`i'=.  //生成一个变量等于应扣除的杂费部分
 recode gb005_1_`i'_  gb005_1_min_`i'_  gb005_1_max_`i'_  (-1=.d)
 replace gb005_1_`i'_=gb005_1_min_`i'_ if !mi(gb005_1_min_`i'_) & mi(gb005_1_max_`i'_)
 replace gb005_1_`i'_=gb005_1_max_`i'_ if mi(gb005_1_min_`i'_) & !mi(gb005_1_max_`i'_)
 replace gb005_1_`i'_=(gb005_1_min_`i'_ + gb005_1_max_`i'_)/2 if !mi(gb005_1_min_`i'_) & !mi(gb005_1_max_`i'_)
 replace gb004`i'=gb005_1_`i'_*12 if gb005_`i'_==1 & !mi(gb005_1_`i'_)
 replace gb004`i'=0 if gb005_`i'_==4 
}

forvalues i=1/7 {
 replace gb004`i'=gb005_2_`i'_ if gb005_`i'_==2 & !mi(gb005_2_`i'_)
 replace gb004`i'=.d if gb005_`i'_==2 & gb005_2_`i'_==-1
}

forvalues i=1/5 {
 replace gb004`i'=gb003_`i'_*(gb005_3_`i'_/100) if gb005_`i'_==3 & !mi(gb005_3_`i'_)
 replace gb004`i'=.d if gb005_`i'_==3 & gb005_3_`i'_==-1
}

***计算其他家户成员的工资收入 - 应扣除的杂费部分
forvalues i=1/11 {
 replace gb003_`i'_=gb003_`i'_ - gb004`i' if !mi(gb003_`i'_) & !mi(gb004`i') & gb004_`i'_==2
}

egen hh5gz_other=rowtotal(gb003_1_ gb003_2_ gb003_3_ gb003_4_ gb003_5_ ///
  gb003_6_ gb003_7_ gb003_8_ gb003_9_ gb003_10_ gb003_11_) 
replace hh5gz_other=.d if gb003_1_==.d | gb003_2_==.d | gb003_3_==.d | gb003_4_==.d | ///
  gb003_5_==.d | gb003_6_==.d | gb003_7_==.d |gb003_8_==.d | gb003_9_==.d | gb003_10_==.d | gb003_11_==.d 
replace hh5gz_other=.r if gb003_1_==.r | gb003_2_==.r | gb003_3_==.r | gb003_4_==.r | ///
  gb003_5_==.r | gb003_6_==.r | gb003_7_==.r |gb003_8_==.r | gb003_9_==.r | gb003_10_==.r | gb003_11_==.r 
  

***其他家户成员的公共转移支付收入
recode gb006_1_1_ gb006_1_2_ gb006_1_3_ gb006_1_4_ gb006_1_5_ gb006_1_6_ ///
 gb006_1_7_ gb006_2_1_ gb006_2_2_ gb006_2_3_ gb006_2_4_ gb006_3_1_ gb006_3_2_ ///
 gb006_3_3_ gb006_3_4_ gb006_4_1_ gb006_4_2_ gb006_4_3_ gb006_4_4_ gb006_4_5_ ///
 gb006_4_6_ gb006_5_1_ gb006_5_2_ gb006_5_3_ gb006_5_4_ gb006_6_1_ gb006_6_2_ ///
 gb006_6_3_ gb006_6_4_ gb006_7_1_ gb006_7_2_ gb006_7_3_ gb006_7_4_ gb006_7_6_ ///
 gb006_8_1_ gb006_8_2_ gb006_8_3_ gb006_8_4_ gb006_8_5_ gb006_8_6_ gb006_8_8_ ///
 gb006_9_1_ gb006_9_2_ gb006_9_3_ gb006_9_4_ gb008_7_1_ gb008_7_2_ gb008_7_3_ /// 
 gb008_7_4_ gb008_7_5_ gb008_8_1_ gb008_8_2_ gb008_8_3_ gb008_8_4_ gb008_8_5_ /// 
 gb008_8_6_ gb008_8_7_ gb008_9_1_ gb008_9_2_ gb008_9_3_ gb008_9_4_ gb008_9_5_ ///
 gb008_9_6_ (.=0) (-1=.d) 
 
***计算其他家户成员的总收入 = 其他家户成员的公共转移支付收入 + 其他家户成员的工资收入减去杂费
gen hh5iothhh=hh5gz_other + gb006_1_1_ + gb006_1_2_  + gb006_1_3_  + gb006_1_4_ + ///
 gb006_1_5_ + gb006_1_6_ + gb006_1_7_ + gb006_2_1_ + gb006_2_2_ + gb006_2_3_ + ///
 gb006_2_4_ + gb006_3_1_ + gb006_3_2_ + gb006_3_3_ + gb006_3_4_ + gb006_4_1_ + ///
 gb006_4_2_ + gb006_4_3_ + gb006_4_4_ + gb006_4_5_ + gb006_4_6_ + gb006_5_1_ + ///
 gb006_5_2_ + gb006_5_3_ + gb006_5_4_ + gb006_6_1_ + gb006_6_2_ + gb006_6_3_ + ///
 gb006_6_4_ + gb006_7_1_ + gb006_7_2_ + gb006_7_3_ + gb006_7_4_ + gb006_7_6_ + ///
 gb006_8_1_ + gb006_8_2_ + gb006_8_3_ + gb006_8_4_ + gb006_8_5_ + gb006_8_6_ + ///
 gb006_8_8_ + gb006_9_1_ + gb006_9_2_ + gb006_9_3_ + gb006_9_4_ + gb008_7_1_ + ///
 gb008_7_2_ + gb008_7_3_ + gb008_7_4_ + gb008_7_5_ + gb008_8_1_ + gb008_8_2_ + ///
 gb008_8_3_ + gb008_8_4_ + gb008_8_5_ + gb008_8_6_ + gb008_8_7_ + gb008_9_1_ + ///
 gb008_9_2_ + gb008_9_3_ + gb008_9_4_ + gb008_9_5_ + gb008_9_6_ if !mi(hh5gz_other) | ///
 !mi(gb006_1_1_) | !mi(gb006_1_2_) | !mi(gb006_1_3_) | !mi(gb006_1_4_) | !mi(gb006_1_5_) | ///
 !mi(gb006_1_6_) | !mi(gb006_1_7_) | !mi(gb006_2_1_) | !mi(gb006_2_2_) | !mi(gb006_2_3_) | ///
 !mi(gb006_2_4_) | !mi(gb006_3_1_) | !mi(gb006_3_2_) | !mi(gb006_3_3_) | !mi(gb006_3_4_) | ///
 !mi(gb006_4_1_) | !mi(gb006_4_2_) | !mi(gb006_4_3_) | !mi(gb006_4_4_) | !mi(gb006_4_5_) | ///
 !mi(gb006_4_6_) | !mi(gb006_5_1_) | !mi(gb006_5_2_) | !mi(gb006_5_3_) | !mi(gb006_5_4_) | ///
 !mi(gb006_6_1_) | !mi(gb006_6_2_) | !mi(gb006_6_3_) | !mi(gb006_6_4_) | !mi(gb006_7_1_) | ///
 !mi(gb006_7_2_) | !mi(gb006_7_3_) | !mi(gb006_7_4_) | !mi(gb006_7_6_) | !mi(gb006_8_1_) | ///
 !mi(gb006_8_2_) | !mi(gb006_8_3_) | !mi(gb006_8_4_) | !mi(gb006_8_5_) | !mi(gb006_8_6_) | ///
 !mi(gb006_8_8_) | !mi(gb006_9_1_) | !mi(gb006_9_2_) | !mi(gb006_9_3_) | !mi(gb006_9_4_) | ///
 !mi(gb008_7_1_) | !mi(gb008_7_2_) | !mi(gb008_7_3_) | !mi(gb008_7_4_) | !mi(gb008_7_5_) | /// 
 !mi(gb008_8_1_) | !mi(gb008_8_2_) | !mi(gb008_8_3_) | !mi(gb008_8_4_) | !mi(gb008_8_5_) | ///
 !mi(gb008_8_6_) | !mi(gb008_8_7_) | !mi(gb008_9_1_) | !mi(gb008_9_2_) | !mi(gb008_9_3_) | ///
 !mi(gb008_9_4_) | !mi(gb008_9_5_) | !mi(gb008_9_6_) 

replace hh5iothhh=.d if hh5gz_other==.d | gb006_1_1_==.d | ///
 gb006_1_2_==.d | gb006_1_3_==.d | gb006_1_4_==.d | gb006_1_5_==.d | /// 
 gb006_1_6_==.d | gb006_1_7_==.d | gb006_2_1_==.d | gb006_2_2_==.d | /// 
 gb006_2_3_==.d | gb006_2_4_==.d | gb006_3_1_==.d | gb006_3_2_==.d | /// 
 gb006_3_3_==.d | gb006_3_4_==.d | gb006_4_1_==.d | gb006_4_2_==.d | /// 
 gb006_4_3_==.d | gb006_4_4_==.d | gb006_4_5_==.d | gb006_4_6_==.d | /// 
 gb006_5_1_==.d | gb006_5_2_==.d | gb006_5_3_==.d | gb006_5_4_==.d | /// 
 gb006_6_1_==.d | gb006_6_2_==.d | gb006_6_3_==.d | gb006_6_4_==.d | /// 
 gb006_7_1_==.d | gb006_7_2_==.d | gb006_7_3_==.d | gb006_7_4_==.d | /// 
 gb006_7_6_==.d | gb006_8_1_==.d | gb006_8_2_==.d | gb006_8_3_==.d | /// 
 gb006_8_4_==.d | gb006_8_5_==.d | gb006_8_6_==.d | gb006_8_8_==.d | /// 
 gb006_9_1_==.d | gb006_9_2_==.d | gb006_9_3_==.d | gb006_9_4_==.d | ///
 gb008_7_1_==.d | gb008_7_2_==.d | gb008_7_3_==.d | gb008_7_4_==.d | /// 
 gb008_7_5_==.d | gb008_8_1_==.d | gb008_8_2_==.d | gb008_8_3_==.d | ///
 gb008_8_4_==.d | gb008_8_5_==.d | gb008_8_6_==.d | gb008_8_7_==.d | /// 
 gb008_9_1_==.d | gb008_9_2_==.d | gb008_9_3_==.d | gb008_9_4_==.d | /// 
 gb008_9_5_==.d | gb008_9_6_==.d 

replace hh5iothhh=.r if hh5gz_other==.r | gb006_1_1_==.r | ///
 gb006_1_2_==.r | gb006_1_3_==.r | gb006_1_4_==.r | gb006_1_5_==.r | /// 
 gb006_1_6_==.r | gb006_1_7_==.r | gb006_2_1_==.r | gb006_2_2_==.r | /// 
 gb006_2_3_==.r | gb006_2_4_==.r | gb006_3_1_==.r | gb006_3_2_==.r | /// 
 gb006_3_3_==.r | gb006_3_4_==.r | gb006_4_1_==.r | gb006_4_2_==.r | /// 
 gb006_4_3_==.r | gb006_4_4_==.r | gb006_4_5_==.r | gb006_4_6_==.r | /// 
 gb006_5_1_==.r | gb006_5_2_==.r | gb006_5_3_==.r | gb006_5_4_==.r | /// 
 gb006_6_1_==.r | gb006_6_2_==.r | gb006_6_3_==.r | gb006_6_4_==.r | /// 
 gb006_7_1_==.r | gb006_7_2_==.r | gb006_7_3_==.r | gb006_7_4_==.r | /// 
 gb006_7_6_==.r | gb006_8_1_==.r | gb006_8_2_==.r | gb006_8_3_==.r | /// 
 gb006_8_4_==.r | gb006_8_5_==.r | gb006_8_6_==.r | gb006_8_8_==.r | /// 
 gb006_9_1_==.r | gb006_9_2_==.r | gb006_9_3_==.r | gb006_9_4_==.r | ///
 gb008_7_1_==.r | gb008_7_2_==.r | gb008_7_3_==.r | gb008_7_4_==.r | /// 
 gb008_7_5_==.r | gb008_8_1_==.r | gb008_8_2_==.r | gb008_8_3_==.r | ///
 gb008_8_4_==.r | gb008_8_5_==.r | gb008_8_6_==.r | gb008_8_7_==.r | /// 
 gb008_9_1_==.r | gb008_9_2_==.r | gb008_9_3_==.r | gb008_9_4_==.r | /// 
 gb008_9_5_==.r | gb008_9_6_==.r 

***家庭农业收入
recode gc004_1 gc004_2 gc004_1_min gc004_1_max (-1=.d)
replace gc004_1=0 if gc001==2  //非农业家庭
replace gc004_2=0 if gc001==2
replace gc004_1=0 if gc003==2  //没有从事农林生产
replace gc004_2=0 if gc003==2
replace gc004_1=0 if gc004==3  //农林生产不赔不赚
replace gc004_2=0 if gc004==3

replace gc004_1=(gc004_1_min+gc004_1_max)/2 if gc004==1 & mi(gc004_1) & ///
 !mi(gc004_1_min) & !mi(gc004_1_max)  //取中间值
replace gc004_1=gc004_1_max if gc004==1 & mi(gc004_1) & ///
 mi(gc004_1_min) & !mi(gc004_1_max)  
replace gc004_1=gc004_1_min if gc004==1 & mi(gc004_1) & ///
 !mi(gc004_1_min) & mi(gc004_1_max)  
replace gc004_2=(gc004_2_min+gc004_2_max)/2 if gc004==2 & mi(gc004_2) & ///
 !mi(gc004_2_min) & !mi(gc004_2_max)  //取中间值
replace gc004_2=gc004_2_max if gc004==2 & mi(gc004_2) & ///
 mi(gc004_2_min) & !mi(gc004_2_max)  
replace gc004_2=gc004_2_min if gc004==2 & mi(gc004_2) & ///
 !mi(gc004_2_min) & mi(gc004_2_max)  
replace gc004_2=gc004_2*(-1)  //亏损取负值
 
recode gc006_1 gc006_2 gc006_1_min gc006_1_max gc006_2_min gc006_2_max (-1=.d)
replace gc006_1=0 if gc001==2   //非农业家庭
replace gc006_2=0 if gc001==2
replace gc006_1=0 if gc006==3   //牲畜/水产品收入不赔不赚
replace gc006_2=0 if gc006==3
replace gc006_1=0 if gc005==2   //没有牲畜/水产品
replace gc006_2=0 if gc005==2
replace gc006_1=(gc006_1_min+gc006_1_max)/2 if gc006==1 & mi(gc006_1) & ///
 !mi(gc006_1_min) & !mi(gc006_1_max)  //取中间值
replace gc006_1=gc006_1_max if gc006==1 & mi(gc006_1) & ///
 mi(gc006_1_min) & !mi(gc006_1_max)  
replace gc006_1=gc006_1_min if gc006==1 & mi(gc006_1) & ///
 !mi(gc006_1_min) & mi(gc006_1_max)  
replace gc006_2=(gc006_2_min+gc006_2_max)/2 if gc006==2 & mi(gc006_2) & ///
 !mi(gc006_2_min) & !mi(gc006_2_max)  //取中间值
replace gc006_2=gc006_2_max if gc006==2 & mi(gc006_2) & ///
 mi(gc006_2_min) & !mi(gc006_2_max)  
replace gc006_2=gc006_2_min if gc006==2 & mi(gc006_2) & ///
 !mi(gc006_2_min) & mi(gc006_2_max)  
replace gc006_2=gc006_2*(-1)   //亏损取负值

***企业经营收入
recode gd004_1 gd004_2 gd004_1_min gd004_1_max gd004_2_min gd004_2_max (-1=.d)
replace gd004_1=0 if gd001==2   //非私营家庭
replace gd004_2=0 if gd001==2
replace gd004_1=0 if gd004==3   //经营收入不赔不赚
replace gd004_2=0 if gd004==3
replace gd004_1=(gd004_1_min+gd004_1_max)/2 if gd004==1 & mi(gd004_1) & ///
 !mi(gd004_1_min) & !mi(gd004_1_max)  //取中间值
replace gd004_1=gd004_1_max if gd004==1 & mi(gd004_1) & ///
 mi(gd004_1_min) & !mi(gd004_1_max)  
replace gd004_1=gd004_1_min if gd004==1 & mi(gd004_1) & ///
 !mi(gd004_1_min) & mi(gd004_1_max)  
replace gd004_2=(gd004_2_min+gd004_2_max)/2 if gd004==2 & mi(gd004_2) & ///
 !mi(gd004_2_min) & !mi(gd004_2_max)  //取中间值
replace gd004_2=gd004_2_max if gd004==2 & mi(gd004_2) & ///
 mi(gd004_2_min) & !mi(gd004_2_max)  
replace gd004_2=gd004_2_min if gd004==2 & mi(gd004_2) & ///
 !mi(gd004_2_min) & mi(gd004_2_max)  
replace gd004_2=gd004_2*(-1)

*****计算{农业收入+个体经营和私营}之和
egen hh5icap=rowtotal(gc004_1 gc004_2 gc006_1 gc006_2 gd004_1 gd004_2),mi //资本性收入=农业收入+经营收入
replace hh5icap=.m if gc001==.
replace hh5icap=.d if gc004_1==.d | gc004_2==.d | gc006_1==.d | gc006_2==.d | gd004_1==.d | gd004_2==.d 


***家户公共转移支付收入
*低保
recode ge004_1_ ge004_2_ ge004_3_ ge004_4_ ge004_5_ ge004_min_1_ ge004_max_1_ ///
  ge004_min_2_ ge004_max_2_ ge004_min_3_ ge004_max_3_ ge004_min_4_ ge004_max_4_ ///
  ge004_min_5_ ge004_max_5_ (-1=.d)
 
forvalues i=1/5 {
  replace ge004_`i'_=(ge004_min_`i'_ + ge004_max_`i'_)/2 if mi(ge004_`i'_) & !mi(ge004_min_`i'_) & !mi(ge004_max_`i'_) //取中间值
  replace ge004_`i'_=ge004_min_`i'_ if mi(ge004_`i'_) & !mi(ge004_min_`i'_) & mi(ge004_max_`i'_)
  replace ge004_`i'_=ge004_max_`i'_ if mi(ge004_`i'_) & mi(ge004_min_`i'_) & !mi(ge004_max_`i'_)
}  

*政府补助 
recode ge006_1 ge006_2 ge006_3 ge006_4 ge006_5 ge006_6 ge006_7 ge006_8 (-1=.d)

*农业保险赔付
recode ge007 (-1=.d)

*疫情补助
recode ge008_1 ge008_1_min ge008_1_max (-1=.d)
replace ge008_1=0 if ge008==2
replace ge008_1=(ge008_1_min + ge008_1_max)/2 if mi(ge008_1) & !mi(ge008_1_min) & !mi(ge008_1_max) //取中间值
replace ge008_1=ge008_1_min if mi(ge008_1) & !mi(ge008_1_min) & mi(ge008_1_max)
replace ge008_1=ge008_1_max if mi(ge008_1) & mi(ge008_1_min) & !mi(ge008_1_max)  

*光伏发电的收入
recode ge011 (-1=.d)  
replace ge011=0 if ge009==2

*土地出租
recode ge012 ge012_min ge012_max (-1=.d)  
replace ge012=(ge012_min + ge012_max)/2 if mi(ge012) & !mi(ge012_min) & !mi(ge012_max) //取中间值
replace ge012=ge012_min if mi(ge012) & !mi(ge012_min) & mi(ge012_max)
replace ge012=ge012_max if mi(ge012) & mi(ge012_min) & !mi(ge012_max)

*房产出租
recode ge013 ge013_min ge013_max (-1=.d)  
replace ge013=(ge013_min + ge013_max)/2 if mi(ge013) & !mi(ge013_min) & !mi(ge013_max) //取中间值
replace ge013=ge013_min if mi(ge013) & !mi(ge013_min) & mi(ge013_max)
replace ge013=ge013_max if mi(ge013) & mi(ge013_min) & !mi(ge013_max)

*出租其他家庭资产
recode ge014_1 (-1=.d)
replace ge014_1=0 if ge014==2
replace ge014_1=.d if ge014==997
replace ge014_1=.r if ge014==999

*****计算其他家庭成员的公共转移支出收入之和
egen hh5igxfr=rowtotal(ge004_1_ ge004_2_ ge004_3_ ge004_4_ ge004_5_ ge006_1 ///
 ge006_2 ge006_3 ge006_4 ge006_5 ge006_6 ge006_7 ge006_8 ge007 ge008_1 ge011 ///
 ge012 ge013 ge014_1),mi
replace hh5igxfr=.m if ge006_s9==. | ge001_s6==. 
replace hh5igxfr=.d if ge004_1_==.d | ge004_2_==.d | ge004_3_==.d | ge004_4_==.d | ///
 ge004_5_==.d | ge006_1==.d | ge006_2==.d | ge006_3==.d | ge006_4==.d | ge006_5==.d | ///
 ge006_6==.d | ge006_7==.d | ge006_8==.d | ge007==.d | ge008_1==.d | ge011==.d | ///
 ge012==.d | ge013==.d | ge014_1==.d 
replace hh5igxfr=.r if ge014_1==.r
 
***个人工资
recode ga002 ga002_min ga002_max (-1=.d)
replace ga002=0 if ga001==2 
replace ga002=(ga002_min + ga002_max)/2 if mi(ga002) & !mi(ga002_min) & !mi(ga002_max)
replace ga002=ga002_min if mi(ga002) & !mi(ga002_min) & mi(ga002_max)
replace ga002=ga002_max if mi(ga002) & mi(ga002_min) & !mi(ga002_max)

*个人工资应扣除杂费部分
recode ga004_1 ga004_1_min ga004_1_max ga004_2 ga004_3 (-1=.d)
gen r5ibonus=.
replace r5ibonus=(ga004_1_min + ga004_1_max)/2*12 if !mi(ga004_1_min) & !mi(ga004_1_max) & ga004==1
replace r5ibonus=ga004_1_min*12 if !mi(ga004_1_min) & mi(ga004_1_max) & ga004==1
replace r5ibonus=ga004_1_max*12 if mi(ga004_1_min) & !mi(ga004_1_max) & ga004==1
replace r5ibonus=ga004_2 if ga004==2
replace r5ibonus=ga002*(ga004_3/100) if !mi(ga002) & !mi(ga004_3) & ga004==3
replace r5ibonus=0 if ga004==4

gen r5itearn=ga002 
replace r5itearn=ga002-r5ibonus if ga003==2 & !mi(ga002) &!mi(r5ibonus)  //如果工资没有扣除杂费

*****计算受访者(配偶双方)的工资之和
bys householdID: egen h5itearn=total(r5itearn) if !mi(r5itearn)  

*****计算受访者(配偶双方)享受的公司福利
recode fc042_1 fc042_2 fc042_3 fc042_4 fc042_1_min fc042_1_max fc042_2_min ///
 fc042_2_max fc042_3_min fc042_3_max fc042_4_min fc042_4_max (-1=.d) (999=.r)
 
forvalues i=1/4 {
 replace fc042_`i'=(fc042_`i'_min + fc042_`i'_max)/2 if mi(fc042_`i') & !mi(fc042_`i'_min) & !mi(fc042_`i'_max)
 replace fc042_`i'=fc042_`i'_min if mi(fc042_`i') & !mi(fc042_`i'_min) & mi(fc042_`i'_max)
 replace fc042_`i'=fc042_`i'_max if mi(fc042_`i') & mi(fc042_`i'_min) & !mi(fc042_`i'_max)
}
forvalues i=1/4 {
 replace fc042_`i'=fc042_`i'*12 if !mi(fc042_`i')
}
egen r5iothr=rowtotal(fc042_1 fc042_2 fc042_3 fc042_4)
replace r5iothr=.d if fc042_1==.d | fc042_2==.d | fc042_3==.d | fc042_4==.d 
replace r5iothr=.r if fc042_1==.r | fc042_2==.r | fc042_3==.r | fc042_4==.r 
bys householdID: egen h5iothr=total(r5iothr) if !mi(r5iothr)  

***个人转移支付收入
recode ga005_1 ga005_1_min ga005_1_max ga005_2 ga005_3 ga005_4 ga005_5 ///
 ga005_6 ga005_7 ga005_8 ga005_9 (-1=.d)
replace ga005_1=(ga005_1_min + ga005_1_max)/2 if mi(ga005_1) & !mi(ga005_1_min) & !mi(ga005_1_max)
replace ga005_1=ga005_1_min if mi(ga005_1) & !mi(ga005_1_min) & mi(ga005_1_max)
replace ga005_1=ga005_1_max if mi(ga005_1) & mi(ga005_1_min) & !mi(ga005_1_max)
egen r5igxfr=rowtotal(ga005_1 ga005_2 ga005_3 ga005_4 ga005_5 ga005_6 ga005_7 ga005_8 ga005_9)
replace r5igxfr=.d if ga005_1==.d | ga005_2==.d | ga005_3==.d | ga005_4==.d | ///
  ga005_5==.d | ga005_6==.d | ga005_7==.d | ga005_8==.d | ga005_9==.d 
replace r5igxfr=.m if ga005_s10==.

*****计算受访者(配偶双方)的转移支付收入之和
bys householdID: egen h5igxfr=total(r5igxfr) if !mi(r5igxfr)  

* Xiaoai: each of the six income components is included once.
egen hh5itot=rowtotal(hh5iothhh hh5icap hh5igxfr h5itearn h5iothr h5igxfr),mi
replace hh5itot=.m if inw5==0
replace hh5itot=.m if mi(hh5iothhh) | mi(hh5icap) | mi(hh5igxfr) | mi(h5itearn) | mi(h5igxfr) | mi(h5iothr)
replace hh5itot=.d if hh5iothhh==.d | hh5icap==.d | hh5igxfr==.d | h5itearn==.d | h5igxfr==.d | h5iothr==.d
replace hh5itot=.r if hh5iothhh==.r | hh5icap==.r | hh5igxfr==.r | h5itearn==.r | h5igxfr==.r | h5iothr==.r

***是否退休
recode fh001 (2=0)
replace zrretired=fh001 if (zrretired==0 | zrretired==.) & !mi(fh001)
rename zrretired r5fret_c  

***过去一个月门诊
recode da005 (2=0),gen(r5doctor1m)  
rename da006 r5doctim1m   

***过去一年的住院
recode da007 (2=0),gen(r5hosp1y) 
rename da008 r5hsptim1y

***保存所需变量  
keep ID householdID communityID inw5 zrbirthyear r5gender r5educ_c r5mstath r5rural2 ///
  r5shlta r5smokev r5smoken r5drinkl r5total_cognition r5memeory r5executive r5cesd10 ///
  r5hibpe r5dyslipe r5diabe r5cancre r5lunge r5livere r5hearte r5stroke r5kidneye ///
  r5digeste r5psyche r5memrye r5arthre r5asthmae r5vgact_c r5mdact_c r5ltact_c ///
  r5act_1 r5act_2 r5act_3 r5act_4 r5act_5 r5act_6 r5act_7 r5act_8 hh5cperc r5iwy r5iwm ///
  h5rural r5ins r5pension h5child r5ea001s1 r5ea001s2 r5ea001s3 r5ea001s4 r5ea001s5 ///
  r5ea001s11 r5satlife h5hhres r5adlab_c r5iadl h5fcamt h5tcamt hh5itot r5fret_c ///
  r5doctor1m r5doctim1m r5hosp1y r5hsptim1y 
   
***final sort
sort ID

***compress dataset
compress	

***add label
label data "charls2020"

***save output dataset
save "$temp_data/charls2020", replace


* =============================================================================
* 第 6 段 / 共 6 段：五波合并 + Harmonized D + PSU → charls.dta
*   原文件 no.6_数据合并.do
* =============================================================================

****************************************************************************
use "$harmonized/H_CHARLS_D_Data 2.dta", clear     //导入数据 
merge 1:1 ID using "$temp_data/charls11.dta",nogen
merge 1:1 ID using "$temp_data/charls13.dta",nogen
merge 1:1 ID using "$temp_data/charls15.dta",nogen
merge 1:1 ID using "$temp_data/charls18.dta",nogen
merge 1:1 ID using "$temp_data/charls2020",nogen
merge m:1 communityID using "$psu2013",nogen   //已转 UTF-8 的副本

***是否参与本次调查
*inw1 inw2 inw3 inw4 inw5

***年龄 
*r1age r2age r3age r4age r5age
replace rabyear=zrbirthyear if mi(rabyear) & !mi(zrbirthyear)
forvalues i=1/5 {
  gen r`i'age=r`i'iwy-rabyear if !mi(r`i'iwy) & !mi(rabyear) //调查年份减出生年份
}

***性别
*ragender
* 修正：xrgender 是 CHARLS 对跨波性别冲突做过校正的版本，优先于 harmonized
* 的 ragender；ragender 只用来补 2020 未参与者。原写法 if mi(ragender) 会让
* 16 名两处记录冲突者中的 9 人取到未校正值。
replace ragender=r5gender if !mi(r5gender)   //2020 校正值优先
replace ragender=r5gender if mi(ragender)    //新增人群的性别
recode ragender (1=1) (2=0)  //男1 女0

***教育程度
*r1edu r2edu r3edu r4edu r5edu
gen r4educ_c=raeduc_c if inw4==1   
forvalues i=1/5 {
  recode r`i'educ_c (1/3=1) (4=2) (5=3) (6/11=4) (else=.),gen(r`i'edu)  
}  
 

***婚姻状况
*r1mstath r2mstath r3mstath r4mstath r5mstath
forvalues i=1/5 {
  recode r`i'mstath (1/3=1) (4/8=0)   //已婚为1,其他为0
} 

***户籍
*r1rural2 r2rural2 r3rural2 r4rural2 r5rural2  //农村1 城市0

***自评健康
*r1shlta r2shlta r3shlta r4shlta r5shlta
forvalues i=1/5 {
  recode r`i'shlta (1=5) (2=4) (3=3) (4=2) (5=1)   //越大越好
}

***吸烟
*r1smoken r2smoken r3smoken r4smoken r5smoken  //吸烟1不吸烟0

***曾经是否吸烟

***喝酒
*r1drinkl r2drinkl r3drinkl r4drinkl r5drinkl  //饮酒1不饮酒0

***曾经是否饮酒
*r1drinkev  r2drinkev  r3drinkev  r4drinkev  r5drinkev

***曾经是否吸烟
*r1smokev r2smokev r3smokev r4smokev r5smokev

***锻炼
*r1exercise r2exercise r3exercise r4exercise r5exercise
forvalues i=1/5 {
 gen r`i'exercise=. 
 replace r`i'exercise=1 if r`i'vgact_c==1 | r`i'mdact_c==1 | r`i'ltact_c==1
 replace r`i'exercise=0 if r`i'vgact_c==0 & r`i'mdact_c==0 & r`i'ltact_c==0
}

***社交活动
*省略

***认知功能
*r@total_cognation=r@memeory+r@executive
forvalues i=1/4 {
  gen r`i'memeory=r`i'tr20/2 
}

forvalues i=1/4 {
  egen r`i'executive=rowtotal(r`i'date_cognition r`i'ser7 r`i'draw)
  replace r`i'executive=. if mi(r`i'date_cognition) | mi(r`i'ser7) | mi(r`i'draw)
}

forvalues i=1/4 {
  egen r`i'total_cognition=rowtotal(r`i'memeory r`i'executive),mi //认知能力=情景记忆+心智状况
  replace r`i'total_cognition=.m if mi(r`i'executive) | mi(r`i'memeory)
  replace r`i'total_cognition=.d if r`i'executive==.d | r`i'memeory==.d
  replace r`i'total_cognition=.r if r`i'executive==.r | r`i'memeory==.r
  replace r`i'total_cognition=.p if r`i'executive==.p | r`i'memeory==.p   
}

***抑郁
*r1cesd10 r2cesd10 r3cesd10 r4cesd10 r5cesd10  //30分,数值越大越差

***慢性病
*r@hibpe r@diabe r@dyslipe r@cancre r@lunge r@livere r@hearte 
*r@stroke r@kidneye r@digeste r@psyche r@memrye r@arthre r@asthmae
forvalues i=1/5 {
egen r`i'chronic_num=rowtotal(r`i'hibpe  r`i'diabe  r`i'dyslipe  r`i'cancre ///
  r`i'lunge  r`i'livere r`i'hearte  r`i'stroke  r`i'kidneye  r`i'digeste ///
  r`i'psyche  r`i'memrye  r`i'arthre  r`i'asthmae)
replace r`i'chronic_num=. if mi(r`i'hibpe) & mi(r`i'diabe) & mi(r`i'dyslipe) & ///
  mi(r`i'cancre) & mi(r`i'lunge) & mi(r`i'livere) & mi(r`i'hearte) & ///
  mi(r`i'stroke) & mi(r`i'kidneye) & mi(r`i'digeste) & mi(r`i'psyche) & ///
  mi(r`i'memrye) & mi(r`i'arthre) & mi(r`i'asthmae) 
  recode r`i'chronic_num (0=0) (1/14=1) ,gen (r`i'chronic)   //是否有慢性病
}

***家庭人均消费
*hh1cperc hh2cperc hh3cperc hh4cperc hh5cperc  

***民族
*nation

***是否有医疗保险
*r1ins r2ins r3ins r4ins r5ins
forvalues i=1/4 {
  gen r`i'ins=.
  replace r`i'ins=1 if r`i'higov==1 | r`i'hipriv==1 | r`i'hiothp==1
  replace r`i'ins=0 if r`i'higov==0 & r`i'hipriv==0 & r`i'hiothp==0
}

***是否有养老保险
*r1pension r2pension r3pension r4pension r4pension r5pension
forvalues i=1/4 {
  gen r`i'pension=.
  replace r`i'pension=1 if r`i'pubpen==1 | r`i'peninc==1 | r`i'othpen==1 | r`i'jcpen==1 
  replace r`i'pension=0 if r`i'pubpen==0 & r`i'peninc==0 & r`i'othpen==0 & r`i'jcpen==0 
}

***健在子女数
*h1child h2child h3child h4child h5child

***代际支持
*h1fcamt h2fcamt h3fcamt h4fcamt h5fcamt 
*h1tcamt h2tcamt h3tcamt h4tcamt h5tcamt 

***是否残疾
*r1disability r2disability r3disability r4disability   //20年缺失

***ADL
*r1adlab_c r2adlab_c r3adlab_c r4adlab_c r5adlab_c  //参考CHARLS官方报告

***IADL
*r1iadl r2iadl r3iadl r4iadl r5iadl
forvalues i=1/4 {
  egen r`i'iadl=rowtotal(r`i'moneya r`i'medsa r`i'shopa r`i'mealsa r`i'housewka),mi  //参考CHARLS官方报告
}

***生活满意度
*r1satlife r2satlife r3satlife r4satlife r5satlife 

***家庭总收入
*hh1itot hh2itot hh3itot hh4itot hh5itot 

***家庭规模
*h1hhres h2hhres h3hhres h4hhres h5hhres


*****保留所需的变量
keep ID householdID communityID  ///
  inw1 inw2 inw3 inw4 inw5 city province ///
  r1iwy r2iwy r3iwy r4iwy r5iwy ///          /* 访问年份：PART 1 之后的所有筛选都靠它 */
  r1iwm r2iwm r3iwm r4iwm r5iwm ///          /* 访问月份 */
  r1rural2 r2rural2 r3rural2 r4rural2 r5rural2 ///   /* 户籍：13 个控制变量之一 */
  r1age r2age r3age r4age r5age ///
  ragender ///
  r1edu r2edu r3edu r4edu r5edu ///
  r1mstath r2mstath r3mstath r4mstath r5mstath ///
  r1shlta r2shlta r3shlta r4shlta r5shlta ///
  r1smoken r2smoken r3smoken r4smoken r5smoken ///
  r1drinkl r2drinkl r3drinkl r4drinkl r5drinkl ///
  r1drinkev r2drinkev r3drinkev r4drinkev ///
  r1smokev r2smokev r3smokev r4smokev r5smokev ///
  r1exercise r2exercise r3exercise r4exercise r5exercise ///
  r1vgact_c r1mdact_c r1ltact_c  /// 
  r2vgact_c r2mdact_c r2ltact_c  ///
  r3vgact_c r3mdact_c r3ltact_c  ///
  r4vgact_c r4mdact_c r4ltact_c  ///
  r5vgact_c r5mdact_c r5ltact_c  /// 
  r1act_1 r1act_2 r1act_3 r1act_4 r1act_5 r1act_6 r1act_7 r1act_8 ///
  r2act_1 r2act_2 r2act_3 r2act_4 r2act_5 r2act_6 r2act_7 r2act_8 ///
  r3act_1 r3act_2 r3act_3 r3act_4 r3act_5 r3act_6 r3act_7 r3act_8 ///
  r4act_1 r4act_2 r4act_3 r4act_4 r4act_5 r4act_6 r4act_7 r4act_8 ///
  r5act_1 r5act_2 r5act_3 r5act_4 r5act_5 r5act_6 r5act_7 r5act_8 ///
  r1total_cognition r2total_cognition r3total_cognition r4total_cognition r5total_cognition ///
  r1memeory r2memeory r3memeory r4memeory r5memeory ///
  r1executive r2executive r3executive r4executive r5executive ///
  r1cesd10 r2cesd10 r3cesd10 r4cesd10 r5cesd10 ///
  r1hibpe r1diabe r1dyslipe r1cancre r1lunge r1livere r1hearte ///
  r1stroke r1kidneye r1digeste r1psyche r1memrye r1arthre r1asthmae ///
  r2hibpe r2diabe r2dyslipe r2cancre r2lunge r2livere r2hearte ///
  r2stroke r2kidneye r2digeste r2psyche r2memrye r2arthre r2asthmae ///
  r3hibpe r3diabe r3dyslipe r3cancre r3lunge r3livere r3hearte ///
  r3stroke r3kidneye r3digeste r3psyche r3memrye r3arthre r3asthmae ///
  r4hibpe r4diabe r4dyslipe r4cancre r4lunge r4livere r4hearte ///
  r4stroke r4kidneye r4digeste r4psyche r4memrye r4arthre r4asthmae ///
  r5hibpe r5diabe r5dyslipe r5cancre r5lunge r5livere r5hearte ///
  r5stroke r5kidneye r5digeste r5psyche r5memrye r5arthre r5asthmae ///
  hh1cperc hh2cperc hh3cperc hh4cperc hh5cperc ///
  h1rural h2rural h3rural h4rural h5rural ///
  r1chronic r2chronic r3chronic r4chronic r5chronic ///
  nation r1ins r2ins r3ins r4ins r5ins ///
  r1pension r2pension r3pension r4pension r4pension r5pension ///
  h1child h2child h3child h4child h5child ///
  r1ea001s1 r1ea001s3 r1ea001s4 r1ea001s2 r1ea001s5 r1ea001s6 /// 
  r1ea001s7 r1ea001s8 r1ea001s11 r2ea001s1 r2ea001s3 r2ea001s4 /// 
  r2ea001s2 r2ea001s5 r2ea001s6 r2ea001s7 r2ea001s8 r2ea001s9  ///
  r2ea001s11 r3ea001s1 r3ea001s3 r3ea001s4 r3ea001s2 r3ea001s5 ///
  r3ea001s6 r3ea001s7 r3ea001s8 r3ea001s9 r3ea001s11 r4ea001s1 ///
  r4ea001s2 r4ea001s3 r4ea001s4 r4ea001s5 r4ea001s6 r4ea001s7 ///
  r4ea001s8 r4ea001s9 r4ea001s10 r4ea001s11 r5ea001s1 r5ea001s2 ///
  r5ea001s3 r5ea001s4 r5ea001s5 r5ea001s11 ///
  r1disability r2disability r3disability r4disability ///
  r1adlab_c r2adlab_c r3adlab_c r4adlab_c r5adlab_c ///
  r1iadl r2iadl r3iadl r4iadl r5iadl ///
  h1fcamt h2fcamt h3fcamt h4fcamt h5fcamt ///
  h1tcamt h2tcamt h3tcamt h4tcamt h5tcamt ///
  r1satlife r2satlife r3satlife r4satlife r5satlife ///
  hh1itot hh2itot hh3itot hh4itot hh5itot ///
  r1fret_c r2fret_c r3fret_c r4fret_c r5fret_c ///
  r1doctor1m r2doctor1m r3doctor1m r4doctor1m r5doctor1m ///
  r1doctim1m r2doctim1m r3doctim1m r4doctim1m r5doctim1m ///
  r1hosp1y r2hosp1y r3hosp1y r4hosp1y r5hosp1y ///
  r1hsptim1y r2hsptim1y r3hsptim1y r4hsptim1y r5hsptim1y ///
  h1hhres h2hhres h3hhres h4hhres h5hhres ///


*****将其转化为面板数据  
sreshape long inw@ r@iwy r@iwm r@rural2 r@age r@edu r@mstath r@shlta r@smoken r@drinkl r@exercise ///
  r@act_1 r@act_2 r@act_3 r@act_4 r@act_5 r@act_6 r@act_7 r@act_8 r@vgact_c r@mdact_c r@ltact_c ///
  r@total_cognition r@executive r@memeory r@cesd10 r@hibpe r@diabe r@dyslipe ///
  r@cancre r@lunge r@livere r@hearte r@stroke r@kidneye r@digeste r@psyche ///
  r@memrye r@arthre r@asthmae hh@cperc h@rural r@chronic r@ins r@pension h@child ///
  r@ea001s1 r@ea001s2 r@ea001s3 r@ea001s4 r@ea001s5 r@ea001s6 r@ea001s7 r@ea001s8 ///
  r@ea001s9 r@ea001s10 r@ea001s11 h@fcamt h@tcamt r@disability r@adlab_c r@iadl ///
  r@satlife hh@itot r@fret_c r@doctor1m r@doctim1m r@hosp1y r@hsptim1y h@hhres r@drinkev r@smokev,i(ID) j(year) 

  rename (ID year householdID communityID inw riwy riwm rrural2 rage ragender rmstath rshlta ///
  rhibpe rdiabe rcancre rlunge rhearte rstroke rpsyche rarthre rdyslipe ///
  rlivere rkidneye rdigeste rasthmae rmemrye rdrinkl rsmoken hhcperc ///
  rcesd10 ract_1 ract_2 ract_3 ract_4 ract_5 ract_6 ract_7 ract_8 ///
  province city redu rexercise rmemeory rexecutive rtotal_cognition hrural /// 
  rpension rins rchronic rea001s1 rea001s2 rea001s3 rea001s4 rea001s5 rea001s6 rea001s7 /// 
  rea001s8 rea001s9 rea001s10 rea001s11 hfcamt htcamt rdisability radlab_c ///
  riadl rsatlife hhitot rfret_c hhhres rdoctor1m rdoctim1m rhosp1y rhsptim1y ///
  rvgact_c rmdact_c rltact_c rdrinkev rsmokev) /// 
  (ID wave householdID communityID inw iwy iwm rural2 age gender marry srh hibpe /// 
  diabe cancre lunge hearte stroke psyche arthre dyslipe livere /// 
  kidneye digeste asthmae memrye drinkl smoken hhcperc cesd10 /// 
  act_1 act_2 act_3 act_4 act_5 act_6 act_7 act_8 province city edu /// 
  exercise memeory executive total_cognition rural pension ins chronic /// 
  ea001s1 ea001s2 ea001s3 ea001s4 ea001s5 ea001s6 ea001s7 ea001s8 ea001s9 /// 
  ea001s10 ea001s11 fcamt tcamt disability adlab_c iadl satlife income_total /// 
  retire family_size doctor doctor_time hospital hospital_time ///
  vgact_c mdact_c ltact_c drinkev smokev)   
   
*****上标签   
label var ID "受访者编码"  
label var wave "第几波调查"  
label var householdID "家庭编码"   
label var communityID "社区编码"    
label var inw "是否参与本轮调查" 
label var age "年龄" 
label var gender "性别" 
label var marry "婚姻" 
label var srh "自评健康" 
label var hibpe "高血压" 
label var diabe "糖尿病" 
label var cancre "癌症" 
label var lunge "肺病" 
label var hearte "心脏病" 
label var stroke "中风" 
label var psyche "精神疾病" 
label var arthre "关节炎" 
label var dyslipe "血脂异常" 
label var livere "肝脏疾病" 
label var kidneye "肾脏疾病" 
label var digeste "胃病" 
label var asthmae "哮喘病" 
label var memrye "记忆疾病" 
label var drinkl "现在是否饮酒" 
label var smoken "现在是否吸烟" 
label var drinkev "是否饮过酒"
label var smokev "是否吸过烟"
label var hhcperc "家庭人均消费" 
label var cesd10 "心理健康(30分,越大越差)" 
label var act_1 "串门" 
label var act_2 "打麻将" 
label var act_3 "提供帮助" 
label var act_4 "跳舞" 
label var act_5 "社团活动" 
label var act_6 "志愿者活动" 
label var act_7 "上学或培训" 
label var act_8 "其他社交"  
label var province "省份" 
label var city "城市" 
label var edu "教育"  
label var exercise "是否锻炼"  
label var vgact_c "重度锻炼"
label var mdact_c "中度锻炼"
label var ltact_c "轻度锻炼"
label var memeory "情景记忆(0~10分)" 
label var executive "心智状况(0~11分)" 
label var total_cognition "认知能力(0~21分,越大越好)" 
label var rural "居住地"
label var pension "是否有养老保险"
label var ins "是否有医疗保险"
label var chronic "是否有慢性病"
label var hchild "健在子女数"
label var nation "是否汉族"
label var ea001s1 "城镇职工医疗保险" 
label var ea001s2 "城乡居民医疗保险" 
label var ea001s3 "城镇居民医疗保险" 
label var ea001s4 " 新型农村合作医疗保险" 
label var ea001s5 "公费医疗" 
label var ea001s6 "医疗救助" 
label var ea001s7 "商业医疗保险: 单位购买" 
label var ea001s8 "商业医疗保险: 个人购买" 
label var ea001s9 "城镇无业居民大病医疗保险" 
label var ea001s10 "长期护理保险" 
label var ea001s11 "其他医疗保险" 
label var fcamt "子女对父母的经济支持"
label var tcamt "父母对子女的经济支持"
label var disability "是否残疾"
label var adlab_c "ADL"
label var iadl "IADL"
label var satlife  "生活满意度"
label var income_total "家庭总收入"
label var retire "是否退休"
label var family_size "家庭规模"
label var doctor "过去一个月是否门诊"
label var doctor_time "过去一个月门诊次数"
label var hospital "过去一年是否住院"
label var hospital_time "过去一年住院次数"

***只保留参与每一轮调查的样本
keep if inw==1   //只保留参与调查的个体
drop inw
label drop _all  //删除标签

***重新标签赋值
label define wave_ 1 "第1轮" 2 "第2轮" 3 "第3轮" 4 "第4轮" 5 "第5轮"
label value wave wave_ 

label define gender_ 0 "女性" 1 "男性"
label value gender gender_ 

label define edu_ 1 "小学以下" 2 "小学" 3 "中学" 4 "高中及以上" 
label value edu edu_

label define health_ 1 "很差" 2 "较差" 3 "一般" 4 "较好" 5 "很好"
label value srh health_

label define marry_ 0 "其他" 1 "已婚"
label value marry marry_

label define rural_ 0 "城市" 1 "农村"
label value rural rural_ 

label define yesno_ 0 "否" 1 "是"
label value ea001s10 ea001s9 ins pension chronic exercise nation disability ///
  ea001s11 ea001s8 ea001s7 ea001s6 ea001s5 ea001s2 ea001s4 ea001s3 ea001s1 ///
  act_8 act_7 act_6 act_5 act_4 act_3 act_2 act_1 retire doctor hospital ///
  smoken drinkl memrye asthmae digeste kidneye livere dyslipe arthre psyche ///
  stroke hearte lunge cancre diabe hibpe vgact_c mdact_c ltact_c drinkev smokev nation yesno_


save "$working_data/charls.dta",replace  //保存数据


isid ID wave
post `flowpost' ("01 raw-built individual panel") (_N)


* ==================== OUTCOME AND WORK ====================
use "$harmonized/H_CHARLS_D_Data 2.dta", clear
keep ID r1goingl r2goingl r3goingl r4goingl
save "$temp_data/自杀proxy变量.dta", replace

use "$raw2020/Health_Status_and_Functioning.dta", clear
keep ID dc025
rename dc025 r5goingl
merge 1:1 ID using "$temp_data/自杀proxy变量.dta"
drop _merge

reshape long r@goingl, i(ID) j(wave)
gen iwy = .
quietly bysort ID (ID): gen seq = _n
replace iwy = 2011 if seq == 1
replace iwy = 2013 if seq == 2
replace iwy = 2015 if seq == 3
replace iwy = 2018 if seq == 4
replace iwy = 2020 if seq == 5
drop wave
drop seq
save "$temp_data/自杀proxy.dta", replace

* -----------------------------------------------------------------------------
* 并入面板，生成 treat / post / did
* -----------------------------------------------------------------------------
use "$working_data/charls.dta", clear
count                                             // 96,628

merge 1:1 ID iwy using "$temp_data/自杀proxy.dta"
drop _merge
count                                             // 129,725

gen byte treat = 0

foreach cc in 西城区 和平区 迁安市 侯马市 包头市 大连市 长春市 大庆市 嘉定区 ///
              苏州市 无锡市 镇江市 杭州市 宁波市 桐乡市 马鞍山市 厦门市 宜春市 ///
              济南市 威海市 烟台市 郑州市 宜昌市 资兴市 珠海市 南宁市 琼海市 ///
              合川区 成都市 泸州市 贵阳市 玉溪市 拉萨市 宝鸡市 金昌市 格尔木市 ///
              银川市 克拉玛依市 {
    replace treat = 1 if city == "`cc'"
}
* 上面 38 个城市与 total do.do 第 32–79 行的 38 条 replace 语句完全一致，
* 只是改写成循环。2016 年国家卫计委首批健康城市试点名单。

gen byte post = iwy >= 2017
gen byte did  = treat * post

save "$temp_data/panel_merged.dta", replace

* -----------------------------------------------------------------------------
* 工作状态变量，再并回去
* -----------------------------------------------------------------------------
use "$harmonized/H_CHARLS_D_Data 2.dta", clear
keep ID r1work r2work r3work r4work
save "$temp_data/work1.dta", replace

use "$raw2020/Work_Retirement.dta", clear
keep ID xworking
rename xworking r5work
merge 1:1 ID using "$temp_data/work1.dta"
drop _merge

reshape long r@work, i(ID) j(wave)
gen iwy = .
quietly bysort ID (ID): gen seq = _n
replace iwy = 2011 if seq == 1
replace iwy = 2013 if seq == 2
replace iwy = 2015 if seq == 3
replace iwy = 2018 if seq == 4
replace iwy = 2020 if seq == 5
drop wave
drop seq
save "$temp_data/work.dta", replace

use "$temp_data/panel_merged.dta", clear
merge 1:1 ID iwy using "$temp_data/work.dta"
drop _merge
save "$temp_data/panel_merged.dta", replace

count                                             // 129,745


* ============================================================================

post `flowpost' ("02 merge outcome and work") (_N)


* ==================== CITY AND HOUSEHOLD SOURCE TABLES ====================
version 18.0
set type double
clear
set more off

* Stata cannot reliably open the 27 MB source workbook on this Mac. The helper
* extracts only named source columns to UTF-8 CSV; all cleaning remains here.
foreach f in city_yearbook_extract municipal_extract covid_city_year_extract {
    capture erase "$temp_data/`f'.csv"
}
shell "$python" "$code/prepare_source_workbooks.py" "$citybook" ///
    "$municipal" "$covidbook" "$temp_data"
confirm file "$temp_data/city_yearbook_extract.csv"
confirm file "$temp_data/municipal_extract.csv"
confirm file "$temp_data/covid_city_year_extract.csv"

* Statistical-yearbook city-year variables.
import delimited using "$temp_data/city_yearbook_extract.csv", ///
    varnames(1) encoding(UTF-8) clear
keep if inlist(iwy, 2011, 2013, 2015, 2018, 2020)
drop if missing(city) | missing(iwy)
replace city=strtrim(city)
replace city="北京" if city=="北京市"
replace city="天津" if city=="天津市"
isid city iwy
rename registered_population_10k 户籍人口万人
rename fixed_asset_investment_10k fixed_asset_investment
rename hospitals 医院卫生院数个
rename so2_tons 工业二氧化硫排放量吨
compress
save "$temp_data/city_yearbook_clean.dta", replace

* Municipal road and green-space variables.
import delimited using "$temp_data/municipal_extract.csv", ///
    varnames(1) encoding(UTF-8) clear
rename roadsurareapercap RoadSurAreaPerCap
rename greencoverageratebd GreenCoverageRateBD
keep if inlist(iwy, 2011, 2013, 2015, 2018, 2020)
drop if missing(city) | missing(iwy)
replace city=strtrim(city)
replace city="北京" if city=="北京市"
replace city="天津" if city=="天津市"
isid city iwy
compress
save "$temp_data/municipal_clean.dta", replace

* Annual COVID cumulative cases (thousands); only 2020 is used in the panel.
import delimited using "$temp_data/covid_city_year_extract.csv", ///
    varnames(1) encoding(UTF-8) clear
drop if missing(city) | missing(iwy)
replace city=strtrim(city)
replace city="北京" if city=="北京市"
replace city="天津" if city=="天津市"
isid city iwy
compress
save "$temp_data/covid_city_year.dta", replace

* PM2.5 source is already a city-year file supplied with the project.
use "$pm25", clear
keep iwy PR_ID PR CITY_ID city pm
drop if missing(city) | missing(iwy)
replace city = "北京" if city == "北京市"
replace city = "天津" if city == "天津市"
replace city=strtrim(city)
replace city="北京" if city=="北京市"
replace city="天津" if city=="天津市"
isid city iwy
compress
save "$temp_data/pm25_city_year.dta", replace

* Household medical expenditure. One record per household-year is required.
tempfile medall
local first = 1
forvalues w = 1/5 {
    local yy = cond(`w'==1,2011,cond(`w'==2,2013,cond(`w'==3,2015,cond(`w'==4,2018,2020))))
    local src = cond(`w'==1,"$raw2011/Household_Income.dta", ///
        cond(`w'==2,"$raw2013/Household_Income.dta", ///
        cond(`w'==3,"$raw2015/Household_Income.dta", ///
        cond(`w'==4,"$raw2018/Household_Income.dta", ///
        "$raw2020/Household_Income.dta"))))
    use "`src'", clear
    if `w' < 5 {
        keep householdID ge010_6
        rename ge010_6 medicalexp
    }
    else {
        keep householdID gf013_6
        rename gf013_6 medicalexp
    }
    if `w' == 1 replace householdID = householdID + "0"
    * Negative raw nonresponse codes cannot be monetary expenditure.
    * Original questionnaire values retained here; medical expenditure is not a model control.
    gen int iwy = `yy'
    isid householdID iwy
    if `first' {
        save `medall', replace
        local first = 0
    }
    else {
        append using `medall'
        save `medall', replace
    }
}
use `medall', clear
isid householdID iwy
compress
save "$temp_data/medical_household_year.dta", replace


* ==================== SAVE 0507 ====================

use "$temp_data/panel_merged.dta", clear
replace city=strtrim(city)
* Preserve author calendar-year matching; late interviews are reported losses.
keep if inlist(iwy,2011,2013,2015,2018,2020)
post `flowpost' ("03 nominal interview years retained") (_N)
drop if missing(city)
post `flowpost' ("04 nonempty city") (_N)
merge m:1 city iwy using "$temp_data/city_yearbook_clean.dta", keep(match) nogen
post `flowpost' ("05 author yearbook inner join") (_N)
merge m:1 city iwy using "$temp_data/municipal_clean.dta", keep(master match) nogen
merge m:1 householdID iwy using "$temp_data/medical_household_year.dta", keep(master match) nogen
drop if missing(rwork)
post `flowpost' ("06 nonmissing work status") (_N)
drop if inlist(rgoingl,997,999)
assert inrange(rgoingl,1,4) | missing(rgoingl)
post `flowpost' ("07 valid-or-missing outcome codes") (_N)
merge m:1 city iwy using "$temp_data/pm25_city_year.dta", keep(match using) gen(merge_pm25)
post `flowpost' ("08 author PM25 match and using rows") (_N)
gen byte has_person=!missing(ID) & !missing(wave)
bysort ID wave: assert _N==1 if has_person
merge m:1 city iwy using "$temp_data/covid_city_year.dta", keep(master match) gen(merge_covid)
replace covidnumber=0 if iwy<2020
* Missing 2020 case counts remain unknown; they are not invented zero cases.
gen double cpi_index=.
replace cpi_index=1 if iwy==2011
replace cpi_index=1.053702 if iwy==2013
replace cpi_index=1.091967 if iwy==2015
replace cpi_index=1.157663 if iwy==2018
replace cpi_index=1.217449 if iwy==2020
gen double real_inc_per=(income_total/family_size)/cpi_index if income_total>0 & income_total<. & family_size>0 & family_size<. & cpi_index<.
gen double log_real_inc_per=ln(real_inc_per) if real_inc_per>0 & real_inc_per<.
gen double hosper=医院卫生院数个/户籍人口万人 if 户籍人口万人>0 & 户籍人口万人<.
gen double ln_invest=ln(fixed_asset_investment) if fixed_asset_investment>0 & fixed_asset_investment<.
gen double act_12=act_1+act_2
gen double total_act=act_1+act_2+act_3+act_4+act_5+act_6+act_7+act_8
label var act_12 "Two-item social interaction score; both items required"
sort ID iwy
save "$analysisfile", replace
post `flowpost' ("09 saved newly built dataset 0507") (_N)
postclose `flowpost'
preserve
use `sampleflow', clear
export delimited using "$outpath/build_sample_flow.csv", replace
restore
display as result "RAW_TO_0507_COMPLETED"
}
if "`mode'"=="build" {
    log close
    exit
}
