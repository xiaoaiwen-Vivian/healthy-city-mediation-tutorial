"""Run the real Healthy City case using an authorized linked Stata dataset.
Run from the companion folder: python code/case_python.py --data INPUT
"""
import argparse
from pathlib import Path
from concurrent.futures import ThreadPoolExecutor
import numpy as np
import pandas as pd
from scipy import stats
from case_core import (read_input, common_sample, fit_paths, design,
                       equation, weights, weighted_solutions,
                       CONTROLS, MEDIATORS, M_COLUMNS, ALIASES)
import individual_core as individual
from inference import bootstrap_summary, sign_tail_summary

# BEGIN setup
parser = argparse.ArgumentParser()
parser.add_argument("--data", required=True)
parser.add_argument("--out", default="results/python")
args = parser.parse_args()
out = Path(args.out)
out.mkdir(parents=True, exist_ok=True)
d, flow = read_input(args.data)
required = ["outcome", "did", "year", "treated"] + CONTROLS
base = common_sample(d, required)
# END setup
pd.DataFrame(flow + [("baseline_complete_case", len(base))],
             columns=["stage", "N"]).to_csv(out/"sample_flow.csv", index=False)

# The respondent comparison uses the same variables under their source names.
raw = d.rename(columns={v: k for k, v in ALIASES.items()}).copy()
raw["rgoingl_clean"] = raw["rgoingl"]
raw["post"] = (raw["iwy"] >= 2017).astype(int)
component_rows = []
city_rows = []
sample_rows = []
common_raw_by_candidate = {}

for label, mediator in zip(MEDIATORS, M_COLUMNS):
    # BEGIN city_paths
    sample = common_sample(base, required + [mediator])
    a_fit, b_fit, total_fit, result, _ = fit_paths(sample, mediator)
    a = result["a"]
    b = result["b"]
    se_a = result["SE_a"]
    se_b = result["SE_b"]
    indirect = a * b
    # END city_paths
    # BEGIN sobel
    sobel_se = np.sqrt(b**2 * se_a**2 + a**2 * se_b**2)
    sobel_z = indirect / sobel_se
    sobel_p = 2 * stats.norm.sf(abs(sobel_z))
    sobel_ci = indirect + np.array([-1, 1]) * 1.959963984540054 * sobel_se
    # END sobel
    result.update(Mediator=label, Sobel_SE=sobel_se, Sobel_p=sobel_p,
                  Sobel_CI_L=sobel_ci[0], Sobel_CI_U=sobel_ci[1])
    # BEGIN city_draws
    B = 2000
    counts = weights(a_fit["g"], B, 2025,
                     "code/shared_draw_counts_94.csv")
    draw_a, _ = weighted_solutions(a_fit, counts)
    draw_b, _ = weighted_solutions(b_fit, counts)
    products = draw_a[:, 0] * draw_b[:, 0]
    if not np.isfinite(products).all():
        raise ValueError("At least one planned bootstrap fit failed")
    result.update(bootstrap_summary(products, indirect))
    result.update(sign_tail_summary(products))
    # END city_draws
    pd.DataFrame({"draw":np.arange(1,B+1), "a":draw_a[:,0],
                  "b":draw_b[:,0], "ab":products}).to_csv(
                      out/f"city_draws_{label}.csv", index=False)
    city_rows.append(result)
    for path,coef,se,pvalue in [("a",a,se_a,result["p_a"]),
                                ("b",b,se_b,result["p_b"])]:
        component_rows.append(dict(Mediator=label,Level="City",Sample="Common",
                              Path=path,N=len(sample),estimate=coef,se=se,p=pvalue))
    original_mediator = {v:k for k,v in ALIASES.items()}[mediator]
    common_ids = sample.rename(columns={"person_id":"ID","year":"iwy"})[["ID","iwy"]]
    common_raw = raw.merge(common_ids, on=["ID","iwy"], how="inner", validate="one_to_one")
    common_raw_by_candidate[label] = common_raw
    assert len(common_raw) == len(sample)
    for scope,dat in [("Common",common_raw)]:
        for path,y,x,target in [
            ("a",original_mediator,["did","treat","post"]+CONTROLS,"did"),
            ("b","rgoingl_clean",[original_mediator,"did","treat","post"]+CONTROLS,original_mediator)]:
            fit = individual.fit_ordinary_fe(dat,y,x,target)
            component_rows.append(dict(Mediator=label,Level="Individual",Sample=scope,
                Path=path,N=fit["N"],estimate=fit["Coefficient"],se=fit["Cluster_SE"],p=fit["P"]))
    sample_rows.append(dict(Mediator=label,Common_N=len(sample),
        Respondents=sample.person_id.nunique(),Cities=sample.city.nunique(),
        TreatedCities=int(sample.groupby("city").treated.first().sum())))
    print(f"{label}: city fits and {B} bootstrap products complete",flush=True)

pd.DataFrame(city_rows).to_csv(out/"city_results.csv",index=False)
pd.DataFrame(component_rows).to_csv(out/"component_paths.csv",index=False)
pd.DataFrame(sample_rows).to_csv(out/"sample_sizes.csv",index=False)

def individual_bootstrap(pair):
    label, mediator = pair
    source = {v:k for k,v in ALIASES.items()}[mediator]
    # BEGIN individual_draws
    sufficient = individual._prepare_bootstrap_stats(common_raw_by_candidate[label], source)
    assert sufficient["n_obs"] == len(common_raw_by_candidate[label])
    G = sufficient["n_ids"]
    observed = individual._mediation_from_cross(
        individual._two_way_fe_cross(sufficient, np.ones(G))
    )
    rng = np.random.default_rng(2025)
    draws = np.empty((2000, 5))
    for r in range(2000):
        frequency = rng.multinomial(G, np.full(G, 1/G)).astype(float)
        cross = individual._two_way_fe_cross(sufficient, frequency)
        draws[r] = individual._mediation_from_cross(cross)
    products = draws[:, 4]
    # END individual_draws
    if not np.isfinite(products).all():raise ValueError("Individual bootstrap fit failed")
    result = dict(Mediator=label,N=sufficient["n_obs"],Respondents=G,
                  a=observed[0],b=observed[1],c=observed[2],cprime=observed[3],ab=observed[4])
    result.update(bootstrap_summary(products, observed[4]))
    result.update(sign_tail_summary(products))
    pd.DataFrame({"draw":np.arange(1,2001),"a":draws[:,0],"b":draws[:,1],
                  "ab":products}).to_csv(out/f"individual_draws_{label}.csv",index=False)
    print(f"{label}: 2000 individual bootstrap products complete",flush=True)
    return result

with ThreadPoolExecutor(max_workers=2) as pool:
    individual_rows = list(pool.map(individual_bootstrap, zip(MEDIATORS,M_COLUMNS)))
pd.DataFrame(individual_rows).to_csv(out/"individual_results.csv",index=False)
print("PYTHON_ESTIMATION_COMPLETED", flush=True)
