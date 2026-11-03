"""Reproduce Step 6 from aggregate draws; no respondent data required."""
from pathlib import Path
import numpy as np
import pandas as pd
from inference import bootstrap_summary, sign_tail_summary

root=Path("results/python")
rows=[]
for level in ["city","individual"]:
    estimates=pd.read_csv(root/f"{level}_results.csv")
    for _,result in estimates.iterrows():
        draw=pd.read_csv(root/f"{level}_draws_{result.Mediator}.csv")
        interval=bootstrap_summary(draw.ab.to_numpy(),result.ab)
        tail=sign_tail_summary(draw.ab.to_numpy())
        for name,value in {**interval,**tail}.items():
            np.testing.assert_allclose(value,result[name],rtol=1e-12,atol=1e-12)
        rows.append(dict(Level=level,Mediator=result.Mediator,**interval,**tail))
summary=pd.DataFrame(rows)
summary.to_csv(root/"recalculated_intervals.csv",index=False)
print(summary.loc[summary.Mediator.eq("Social")].to_string(index=False))
print("All 12 interval and sign-count summaries reproduced.")
