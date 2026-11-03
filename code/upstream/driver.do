version 18.0
clear all
set more off
args python_executable
global package_root "`c(pwd)'"
global project "`c(pwd)'"
do config.local.do
global python "`python_executable'"
global code "$package_root/code/upstream"
global temp_data "$project/temp"
global working_data "$project/data"
global outpath "$project/output"
global analysisfile "$working_data/analysis_input.dta"
foreach d in temp data output logs {
    capture mkdir "$project/`d'"
}
do code/setup_stata.do
tempname paths
file open `paths' using "input_paths.tsv", write text replace
foreach key in rawroot raw2011 raw2013 raw2015 raw2018 raw2020 harmonized harmonizedC citybook municipal covidbook pm25 {
    file write `paths' "`key'" _tab "${`key'}" _n
}
file close `paths'
shell "$python" "code/upstream/check_inputs.py"
confirm file "logs/upstream_inputs_verified.ok"
do code/upstream/build_input.do build
confirm file "$analysisfile"
file open done using "logs/input_build_completed.ok", write text replace
file write done "Upstream input construction completed." _n
file close done
