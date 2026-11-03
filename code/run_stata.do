* Called by run.py from a fresh run directory; can also be used interactively.
version 18.0
args input_path
do code/setup_stata.do
capture mkdir results
capture mkdir results/stata
capture mkdir results/wild
capture mkdir logs
capture log close mainlog
log using "logs/stata_analysis.log", text replace name(mainlog)
do code/case_stata.do "`input_path'"
do code/worked_examples.do "`input_path'"
do code/fdr_stata.do
do code/individual_fe_sensitivity.do "`input_path'"
do code/worked_fe_examples.do "`input_path'"
do code/wild_cluster.do "`input_path'" 9999
display "STATA_ESTIMATION_COMPLETED"
log close mainlog
file open verified using "logs/stata_completed.ok", write text replace
file write verified "All required Stata programs completed without error." _n
file close verified
