"""Least-squares and whole-city resampling functions for the Healthy City case."""

from pathlib import Path
import numpy as np
import pandas as pd
from scipy import stats

CONTROLS = ['gender','marry','log_real_inc_per','rwork','rural2','edu',
            'hchild','retire','adlab_c','smoken','drinkl','srh','age']

MEDIATORS = ['Green','Road','SO2','Medical','PM25','Social']

M_COLUMNS = ['m_green','m_road','m_so2','m_medical','m_pm25','m_social']

ALIASES = {'ID':'person_id','iwy':'year','treat':'treated','rgoingl':'outcome',
           'GreenCoverageRateBD':'m_green','RoadSurAreaPerCap':'m_road',
           '工业二氧化硫排放量吨':'m_so2','hosper':'m_medical','pm':'m_pm25','act_12':'m_social'}

YEARS = [2011,2013,2015,2018,2020]

def read_input(path):
    path=Path(path)
    if path.suffix.lower()=='.dta': d=pd.read_stata(path,convert_categoricals=False)
    else: d=pd.read_csv(path,dtype={'person_id':str,'city':str})
    d=d.rename(columns={a:b for a,b in ALIASES.items() if a in d and b not in d})
    required=['person_id','city','year','wave','treated','rural','outcome']+CONTROLS+M_COLUMNS
    missing=set(required)-set(d)
    if missing: raise ValueError(f'Missing input columns: {sorted(missing)}')
    for col in ['person_id','city']: d[col]=d[col].fillna('').astype(str).str.strip()
    person=d.person_id.ne('')
    if 'wave' in d: person &= d.wave.notna()
    if d.loc[person].duplicated(['person_id','year']).any(): raise ValueError('Duplicate person/year')
    if not d.year.dropna().isin(YEARS).all(): raise ValueError('Unexpected wave years; adapt the design explicitly')
    person &= d.city.ne('') & d.year.notna()
    d['did_expected']=d.treated*(d.year>=2017)
    if 'did' in d:
        check=person & d.did.notna() & d.did_expected.notna()
        if not np.array_equal(d.loc[check,'did'],d.loc[check,'did_expected']): raise ValueError('DID coding mismatch')
    d['did']=d.pop('did_expected')
    for col,values in [('treated',[0,1]),('rural',[0,1]),('outcome',[1,2,3,4]),('m_social',[0,1,2])]:
        if not d.loc[person,col].dropna().isin(values).all(): raise ValueError(f'Unexpected values: {col}')
    if d.loc[person].groupby('city').treated.nunique().gt(1).any(): raise ValueError('Treatment varies within city')
    if d.loc[person].groupby('person_id').city.nunique().gt(1).any(): raise ValueError('Migration needs a new clustering decision')
    if {'act_1','act_2'} <= set(d):
        if not np.allclose(d.m_social,d.act_1+d.act_2,equal_nan=True): raise ValueError('Social item sum mismatch')
    eligible=person & d.age.ge(45) & d.age.notna() & d.rural.eq(0)
    flow=[('merged_input',len(d)),('person_records',int(person.sum())),('age_urban_eligible',int(eligible.sum()))]
    return d.loc[eligible].copy(),flow

def common_sample(d, cols):
    s=d.dropna(subset=cols).copy()
    while len(s):
        keep=s.groupby('city').city.transform('size').gt(1) & s.groupby('year').year.transform('size').gt(1)
        if keep.all(): break
        s=s.loc[keep].copy()
    return s.sort_values(['city','person_id','year']).reset_index(drop=True)

def design(s, mediator):
    years=pd.get_dummies(s.year.astype(int),drop_first=True,dtype=float)
    x=pd.concat([s[['did']+CONTROLS],years],axis=1)
    values=pd.concat([s[[mediator,'outcome']],x],axis=1).astype(float)
    w=(values-values.groupby(s.city).transform('mean')).to_numpy()
    return w[:,0],w[:,1],w[:,2:],pd.factorize(s.city,sort=True)[0],list(x.columns)

def equation(x,y,codes):
    """OLS after city demeaning; reghdfe-compatible nested-city CR1 correction.
    Year indicators are regressors, not demeaned-away global constants.
    The absorbed intercept adds one to the non-nested parameter count.
    """
    n,p=x.shape; g=int(codes.max())+1
    scales=np.sqrt((x*x).sum(0))
    if (scales<=0).any(): raise ValueError('Zero-variance column: inspect the model')
    z=x/scales
    beta,_,rank,_=np.linalg.lstsq(z,y,rcond=None)
    if rank!=p: raise ValueError('Observed design rank deficient')
    bread=np.linalg.inv(z.T@z)
    residual=y-z@beta
    scores=np.zeros((g,p));np.add.at(scores,codes,z*residual[:,None])
    multiplier=g/(g-1)*(n-1)/(n-p-1)
    influence=(scores@bread)/scales
    cov=multiplier*(influence.T@influence)
    xx=np.zeros((g,p,p));xy=np.zeros((g,p))
    for j in range(g):
        zj=z[codes==j];yj=y[codes==j];xx[j]=zj.T@zj;xy[j]=zj.T@yj
    return dict(beta=beta/scales,cov=cov,influence=influence,multiplier=multiplier,
                xx=xx,xy=xy,scale=scales,n=n,g=g,p=p,x=z,y=y,codes=codes)

def fit_paths(s,mediator):
    m,y,x,codes,names=design(s,mediator)
    a=equation(x,m,codes);b=equation(np.column_stack([m,x]),y,codes);t=equation(x,y,codes)
    av=a['beta'][0];bv=b['beta'][0];ab=av*bv
    sea=np.sqrt(a['cov'][0,0]);seb=np.sqrt(b['cov'][0,0])
    var0=bv*bv*sea*sea+av*av*seb*seb
    pa=2*stats.t.sf(abs(av/sea),a['g']-1);pb=2*stats.t.sf(abs(bv/seb),a['g']-1)
    result=dict(N=len(s),Cities=a['g'],TreatedCities=int(s.groupby('city').treated.first().sum()),
        Respondents=s.person_id.nunique(),a=av,b=bv,c=t['beta'][0],cprime=b['beta'][1],ab=ab,
        SE_a=sea,SE_b=seb,p_a=pa,p_b=pb,Sobel_SE=np.sqrt(var0),
        Sobel_p=2*stats.norm.sf(abs(ab/np.sqrt(var0))),
        Identity_error=abs(t['beta'][0]-b['beta'][1]-ab))
    if result['Identity_error']>1e-8: raise ValueError('Common-sample decomposition failed')
    return a,b,t,result,(m,y,x,codes)

def weights(g,reps,seed,shared):
    if shared:
        a=pd.read_csv(shared)
        if a.shape!=(reps,g+1) or list(a.columns)!=['draw']+[f'g{k:03d}' for k in range(1,g+1)]:
            raise ValueError('Shared schedule shape or column order mismatch')
        w=a.iloc[:,1:].to_numpy(float)
    else:
        rng=np.random.Generator(np.random.PCG64(seed));picks=rng.integers(0,g,(reps,g))
        w=np.zeros((reps,g));np.add.at(w,(np.repeat(np.arange(reps),g),picks.ravel()),1)
    if (w<0).any() or not np.equal(w,np.floor(w)).all() or not (w.sum(1)==g).all(): raise ValueError('Invalid multiplicities')
    return w

def weighted_solutions(eq,w):
    gram=np.einsum('rg,gij->rij',w,eq['xx']);rhs=w@eq['xy']
    beta=np.full((len(w),eq['p']),np.nan);ranks=[]
    for j,(xx,xy) in enumerate(zip(gram,rhs)):
        ev=np.linalg.eigvalsh(xx);tol=ev[-1]*eq['p']*np.finfo(float).eps
        rank=int((ev>tol).sum());ranks.append(rank)
        if rank==eq['p']:
            try: beta[j]=np.linalg.solve(xx,xy)/eq['scale']
            except np.linalg.LinAlgError: pass
    return beta,np.asarray(ranks)
