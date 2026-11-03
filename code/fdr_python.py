"""Step 7. Run without respondent data, using the supplied aggregate results."""
from pathlib import Path
import numpy as np
import pandas as pd
from scipy import stats
from inference import bh_adjust, bh_walk

root = Path("results/python")
# BEGIN apply_product_bh
city = pd.read_csv(root / "city_results.csv")
individual = pd.read_csv(root / "individual_results.csv")
city["Sobel_BH_6"] = bh_adjust(city["Sobel_p"])
city["sign_tail_BH"] = bh_adjust(city["sign_tail"])
individual["sign_tail_BH"] = bh_adjust(individual["sign_tail"])
print('Hypothesis-test inputs: city Sobel p values and BH adjustments across six candidates.')
print(city[["Mediator", "Sobel_p", "Sobel_BH_6"]].to_string(index=False))
print('Descriptive bootstrap calculations below: these values do not determine statistical significance.')
for label, frame in [('City', city), ('Individual', individual)]:
    print(label)
    print(frame[["Mediator", "sign_tail", "sign_tail_BH"]].to_string(index=False))
# END apply_product_bh
city.to_csv(root/"city_adjusted.csv",index=False)
individual.to_csv(root/"individual_adjusted.csv",index=False)

# BEGIN apply_path_bh
paths = pd.read_csv(root / "component_paths.csv")
reported = paths.loc[
    paths["Sample"].eq("Common")
].copy()
family_keys = ["Level", "Sample", "Path"]
reported["BH"] = reported.groupby(family_keys)["p"].transform(bh_adjust)
print(reported[[*family_keys, "Mediator", "p", "BH"]].to_string(index=False))
# END apply_path_bh
reported.to_csv(root/"component_adjusted.csv",index=False)
families=[]
for key,group in reported.groupby(family_keys,sort=False):
    families.append(pd.DataFrame({"Family":"_".join(key),"Mediator":group.Mediator,
                                 "input":group.p,"BH":group.BH}))
for name,frame,value,adj in [
    ("City_common_Sobel",city,"Sobel_p","Sobel_BH_6"),
    ("City_bootstrap_sign",city,"sign_tail","sign_tail_BH"),
    ("Individual_bootstrap_sign",individual,"sign_tail","sign_tail_BH")]:
    families.append(pd.DataFrame({"Family":name,"Mediator":frame.Mediator,
                                 "input":frame[value],"BH":frame[adj]}))
long=pd.concat(families,ignore_index=True)
long['Use']=np.where(long.Family.isin(['City_bootstrap_sign','Individual_bootstrap_sign']),
                     'Descriptive only','Hypothesis-test p values')
assert long.groupby("Family").size().eq(6).all()
for name,group in long.groupby("Family"):
    np.testing.assert_allclose(group.BH,stats.false_discovery_control(group.input,method="bh"),rtol=1e-14,atol=1e-15)
long.to_csv(root/"all_bh_families.csv",index=False)
long.loc[long.Use.eq('Hypothesis-test p values')].to_csv(root/'hypothesis_test_bh.csv',index=False)
long.loc[long.Use.eq('Descriptive only')].rename(columns={
    'input':'Sign_tail_summary','BH':'BH_calculation_descriptive'
}).to_csv(root/'descriptive_bh.csv',index=False)
bh_walk(city.Mediator,city.Sobel_p).to_csv(root/"sobel_bh_worked.csv",index=False)
bh_walk(individual.Mediator,individual.sign_tail).to_csv(root/"individual_sign_bh_worked.csv",index=False)
print("Five hypothesis-testing families and two descriptive groups; six candidates in each.")
print("All 42 calculations agree with SciPy. The 12 descriptive calculations are not FDR-controlled significance tests.")

