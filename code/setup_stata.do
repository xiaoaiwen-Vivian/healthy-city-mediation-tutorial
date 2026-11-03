version 18.0
sysdir set PLUS "`c(pwd)'/vendor/stata/"
foreach sub in r f l s m {
    adopath ++ "`c(pwd)'/vendor/stata/`sub'"
}
adopath ++ "`c(pwd)'/vendor/boottest"
mata: mata mlib index
foreach command in reghdfe ftools sreshape boottest ms_parse_varlist ms_fvstrip {
    which `command'
    quietly findfile `command'.ado
    if strpos("`r(fn)'", "`c(pwd)'/vendor/")!=1 {
        display as error "A required command did not resolve to the bundled dependency."
        exit 499
    }
}
