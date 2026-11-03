"""Transparent percentile, BC and BH calculations used in the tutorial."""
import numpy as np
import pandas as pd
from scipy import stats

# BEGIN bh
def bh_adjust(values):
    values = np.asarray(values, dtype=float)
    m = len(values)
    order = np.argsort(values, kind="stable")
    ranked = values[order]
    scaled = ranked * m / np.arange(1, m + 1)
    adjusted_sorted = np.minimum.accumulate(scaled[::-1])[::-1]
    adjusted_sorted = np.minimum(adjusted_sorted, 1.0)
    adjusted = np.empty(m)
    adjusted[order] = adjusted_sorted
    return adjusted
# END bh

def bh_walk(labels, values):
    t = pd.DataFrame({"Mediator": labels, "input_value": values})
    t = t.sort_values("input_value", kind="stable").reset_index(drop=True)
    t["rank"] = np.arange(1, len(t) + 1)
    t["six_times_value_over_rank"] = t.input_value * len(t) / t["rank"]
    t["BH"] = bh_adjust(t.input_value)
    return t

# BEGIN intervals
def bootstrap_summary(products, observed):
    products = np.asarray(products, dtype=float)
    B = len(products)
    pct = np.quantile(products, [0.025, 0.975], method="linear")
    proportion = np.mean(products <= observed)
    z0 = stats.norm.ppf(np.clip(proportion, 0.0001, 0.9999))
    bc_prob = stats.norm.cdf(
        2 * z0 + stats.norm.ppf([0.025, 0.975])
    )
    bc = np.quantile(products, bc_prob, method="linear")
    return {"B": B, "Pct_L": pct[0], "Pct_U": pct[1],
            "BC_L": bc[0], "BC_U": bc[1], "z0": z0,
            "BC_prob_L": bc_prob[0], "BC_prob_U": bc_prob[1]}
# END intervals

# BEGIN sign_tail
def sign_tail_summary(products):
    products = np.asarray(products, dtype=float)
    negative = int(np.sum(products < 0))
    positive = int(np.sum(products > 0))
    zero = int(np.sum(products == 0))
    B = len(products)
    value = min(1.0, 2 * (min(negative, positive) + 1) / (B + 1))
    return {"Negative": negative, "Positive": positive,
            "Zero": zero, "sign_tail": value}
# END sign_tail
