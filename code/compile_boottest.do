* Optional rebuild for the local Stata version; run from the package root.
version 18.0
clear all
do code/setup_stata.do
run vendor/boottest/boottest.mata
copy vendor/stata/l/lboottest.mlib vendor/boottest/lboottest.mlib, replace
display "LOCAL_BOOTTEST_LIBRARY_COMPILED"
