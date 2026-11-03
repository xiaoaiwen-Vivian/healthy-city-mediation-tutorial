/* Stata/Mata implementation. Whole-city weighted least squares.
   City crossproducts accelerate whole-city resampling. The first ten draws
   are also checked by direct weighted rectangular QR fits. */
mata:
struct hc_equation {
    real matrix x, y, xx, xy, influence, V
    real rowvector scale
    real colvector beta
    real scalar n, g, p, correction
}

void hc_csv(string scalar file, string scalar header, real matrix a)
{
    real scalar h,i,j
    string scalar line
    if(fileexists(file)) unlink(file)
    h=fopen(file,"w")
    fput(h,header)
    for(i=1;i<=rows(a);i++) {
        line=""
        for(j=1;j<=cols(a);j++) line=line+(j>1 ? "," : "")+strtrim(strofreal(a[i,j],"%24.17g"))
        fput(h,line)
    }
    fclose(h)
}

real matrix hc_demean(real matrix a, real matrix info)
{
    real scalar j
    real matrix z
    z=a
    for(j=1;j<=rows(info);j++) z[|info[j,1],1\info[j,2],cols(a)|]=a[|info[j,1],1\info[j,2],cols(a)|]:-mean(a[|info[j,1],1\info[j,2],cols(a)|])
    return(z)
}

struct hc_equation scalar hc_fit(real matrix x,real colvector y,real matrix info)
{
    struct hc_equation scalar e
    real matrix z,bread,scores,zj
    real colvector beta,residual,yj
    real scalar j,lo,hi
    e.n=rows(x);e.p=cols(x);e.g=rows(info)
    e.scale=sqrt(colsum(x:^2))
    if(any(e.scale:<=0)) _error(3498,"Zero-variance regressor")
    z=x:/e.scale
    if(rank(z)!=e.p) _error(3498,"Observed rank deficiency")
    beta=qrsolve(z,y);e.beta=beta:/e.scale'
    bread=invsym(cross(z,z));residual=y-z*beta
    scores=J(e.g,e.p,0);e.xx=J(e.g*e.p,e.p,0);e.xy=J(e.g,e.p,0)
    for(j=1;j<=e.g;j++) {
        lo=info[j,1];hi=info[j,2];zj=z[|lo,1\hi,e.p|];yj=y[|lo\hi|]
        scores[j,.]=cross(zj,residual[|lo\hi|])'
        e.xx[|(j-1)*e.p+1,1\j*e.p,e.p|]=cross(zj,zj)
        e.xy[j,.]=cross(zj,yj)'
    }
    e.influence=(scores*bread):/e.scale
    e.correction=e.g/(e.g-1)*(e.n-1)/(e.n-e.p-1)
    e.V=e.correction*cross(e.influence,e.influence)
    e.x=z;e.y=y
    return(e)
}

real matrix hc_solve(struct hc_equation scalar e,real matrix w)
{
    real scalar r,j,k
    real matrix xx,ans
    real colvector xy,b
    ans=J(rows(w),e.p+1,.)
    for(r=1;r<=rows(w);r++) {
        xx=J(e.p,e.p,0);xy=J(e.p,1,0)
        for(j=1;j<=e.g;j++) if(w[r,j]>0) {
            xx=xx+w[r,j]*e.xx[|(j-1)*e.p+1,1\j*e.p,e.p|]
            xy=xy+w[r,j]*e.xy[j,.]'
        }
        k=rank(xx);ans[r,e.p+1]=k
        if(k==e.p) {
            b=cholsolve(xx,xy)
            if(!hasmissing(b)) ans[r,1..e.p]=(b:/e.scale')'
        }
    }
    return(ans)
}

real scalar hc_q(real colvector v,real scalar p)
{
    real scalar h,l,u
    v=sort(v,1);h=1+(rows(v)-1)*p;l=floor(h);u=ceil(h)
    return(v[l]+(h-l)*(v[u]-v[l]))
}

end
