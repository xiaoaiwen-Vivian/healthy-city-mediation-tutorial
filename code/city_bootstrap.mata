mata:
void city_products(string scalar mediator, string scalar regressors,
                   string scalar filename, real matrix counts)
{
    struct hc_equation scalar a_fit, b_fit
    real matrix info, z, x, a_draws, b_draws
    real colvector m, y, products
    info=panelsetup(st_data(.,"city_id"),1)
    z=hc_demean(st_data(.,(mediator,"outcome",tokens(regressors))),info)
    m=z[,1]; y=z[,2]; x=z[,3..cols(z)]
    a_fit=hc_fit(x,m,info)
    b_fit=hc_fit((m,x),y,info)
    if(cols(counts)!=rows(info) | rows(counts)!=2000) _error(3498)
    // BEGIN mata_draws
    a_draws=hc_solve(a_fit,counts)
    b_draws=hc_solve(b_fit,counts)
    products=a_draws[,1]:*b_draws[,1]
    if(hasmissing(products)) _error(3498)
    hc_csv(filename,"draw,a,b,ab",
           ((1::rows(counts)),a_draws[,1],b_draws[,1],products))
    // END mata_draws
}
end
