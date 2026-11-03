from pathlib import Path
import time
import numpy as np
import pandas as pd
from scipy.stats import norm, t as student_t
from case_core import CONTROLS
def _city_within_transform(values, city_codes, n_cities):
    counts = np.bincount(city_codes, minlength=n_cities).astype(float)
    sums = np.zeros((n_cities, values.shape[1]), dtype=float)
    np.add.at(sums, city_codes, values)
    means = sums / counts[:, None]
    return values - means[city_codes]


def fit_ordinary_fe(data, outcome, regressors, target):
    needed = ["ID", "city", "iwy", outcome, *regressors]
    sample = data[needed].dropna().copy().reset_index(drop=True)

    years = pd.get_dummies(
        sample["iwy"].astype(int), prefix="year", drop_first=True, dtype=float
    ).reset_index(drop=True)
    x_frame = pd.concat(
        [sample[regressors].astype(float).reset_index(drop=True), years],
        axis=1,
    )

    city_codes, city_values = pd.factorize(sample["city"], sort=True)
    id_codes, id_values = pd.factorize(sample["ID"], sort=True)
    n_cities = len(city_values)
    n_clusters = len(id_values)

    combined = np.column_stack(
        [sample[outcome].to_numpy(float), x_frame.to_numpy(float)]
    )
    within = _city_within_transform(combined, city_codes, n_cities)
    y = within[:, 0]
    x = within[:, 1:]

    # Drop regressors fully absorbed by fixed effects, notably `treat`.
    diagonal = np.einsum("ij,ij->j", x, x)
    tolerance = max(diagonal.max(), 1.0) * 1e-12
    active = diagonal > tolerance
    x_active = x[:, active]
    active_names = np.asarray(x_frame.columns)[active]

    beta = np.linalg.lstsq(x_active, y, rcond=None)[0]
    residual = y - x_active @ beta

    bread = np.linalg.pinv(x_active.T @ x_active)
    cluster_scores = np.zeros((n_clusters, x_active.shape[1]), dtype=float)
    np.add.at(cluster_scores, id_codes, x_active * residual[:, None])
    meat = cluster_scores.T @ cluster_scores

    rank_x = np.linalg.matrix_rank(x_active)
    effective_parameters = rank_x + n_cities
    n_obs = len(sample)
    correction = (
        n_clusters / (n_clusters - 1)
        * (n_obs - 1) / max(n_obs - effective_parameters, 1)
    )
    covariance = correction * bread @ meat @ bread
    standard_errors = np.sqrt(np.maximum(np.diag(covariance), 0))

    target_index = int(np.where(active_names == target)[0][0])
    coefficient = beta[target_index]
    standard_error = standard_errors[target_index]
    degrees_freedom = n_clusters - 1
    statistic = coefficient / standard_error
    p_value = 2 * student_t.sf(abs(statistic), df=degrees_freedom)

    return {
        "Coefficient": coefficient,
        "Cluster_SE": standard_error,
        "t": statistic,
        "P": p_value,
        "N": n_obs,
        "ID_clusters": n_clusters,
        "City_FE": True,
        "Year_FE": True,
        "Treat_in_model": True,
    }


def _prepare_bootstrap_stats(data, mediator):
    needed = [
        "ID", "city", "iwy", "did", "treat", "post", "rgoingl_clean",
        mediator, *CONTROLS,
    ]
    sample = data[needed].dropna().copy().reset_index(drop=True)

    years = pd.get_dummies(
        sample["iwy"].astype(int), prefix="year", drop_first=True, dtype=float
    ).reset_index(drop=True)
    regressors = pd.concat(
        [
            sample[["did", "treat", "post", *CONTROLS]]
            .astype(float)
            .reset_index(drop=True),
            years,
        ],
        axis=1,
    )

    # z columns: mediator, outcome, then common regressors (DID is first).
    z = np.column_stack(
        [
            sample[mediator].to_numpy(float),
            sample["rgoingl_clean"].to_numpy(float),
            regressors.to_numpy(float),
        ]
    )

    id_codes, id_values = pd.factorize(sample["ID"], sort=True)
    city_codes, city_values = pd.factorize(sample["city"], sort=True)
    n_ids = len(id_values)
    n_cities = len(city_values)

    id_city = np.full(n_ids, -1, dtype=np.int32)
    id_city[id_codes] = city_codes
    if np.any(id_city < 0):
        raise RuntimeError("Could not map every ID to a city.")

    p = z.shape[1]
    id_n = np.bincount(id_codes, minlength=n_ids).astype(float)
    id_sum = np.zeros((n_ids, p), dtype=float)
    np.add.at(id_sum, id_codes, z)

    id_cross = np.zeros((n_ids, p, p), dtype=float)
    np.add.at(id_cross, id_codes, z[:, :, None] * z[:, None, :])

    return {
        "n_obs": len(sample),
        "n_ids": n_ids,
        "n_cities": n_cities,
        "id_city": id_city,
        "id_n": id_n,
        "id_sum": id_sum,
        "id_cross": id_cross,
    }


def _two_way_fe_cross(stats, id_frequencies):
    # Absorb city FE using bootstrap frequency weights. Year FE remain in the
    # regressor block as year indicators, exactly equivalent to absorb(city iwy).
    weighted_sum = stats["id_sum"] * id_frequencies[:, None]
    city_sum = np.zeros((stats["n_cities"], weighted_sum.shape[1]), dtype=float)
    np.add.at(city_sum, stats["id_city"], weighted_sum)

    city_n = np.bincount(
        stats["id_city"],
        weights=id_frequencies * stats["id_n"],
        minlength=stats["n_cities"],
    )
    active_city = city_n > 0

    total_cross = np.tensordot(id_frequencies, stats["id_cross"], axes=(0, 0))
    return total_cross - city_sum[active_city].T @ (
        city_sum[active_city] / city_n[active_city, None]
    )


def _solve_cross(cross_xx, cross_xy):
    diagonal = np.diag(cross_xx)
    tolerance = max(np.max(np.abs(diagonal)), 1.0) * 1e-12
    active = np.abs(diagonal) > tolerance
    beta = np.zeros(len(diagonal), dtype=float)
    beta[active] = np.linalg.lstsq(
        cross_xx[np.ix_(active, active)], cross_xy[active], rcond=None
    )[0]
    return beta


def _mediation_from_cross(cross):
    r = np.arange(2, cross.shape[0])

    beta_a = _solve_cross(cross[np.ix_(r, r)], cross[r, 0])
    path_a = beta_a[0]

    beta_total = _solve_cross(cross[np.ix_(r, r)], cross[r, 1])
    total_effect = beta_total[0]

    x_b = np.r_[0, r]
    beta_b = _solve_cross(cross[np.ix_(x_b, x_b)], cross[x_b, 1])
    path_b = beta_b[0]
    direct_effect = beta_b[1]
    indirect_effect = path_a * path_b

    return np.array(
        [path_a, path_b, total_effect, direct_effect, indirect_effect],
        dtype=float,
    )


def _bootstrap_interval_summary(observed, draws):
    bootstrap_se = draws.std(ddof=1) 
    pct_low, pct_high = np.quantile(draws, [0.025, 0.975])

    p0 = np.clip(np.mean(draws <= observed), 1e-4, 1 - 1e-4)
    z0 = norm.ppf(p0)
    bc_low_probability = norm.cdf(2 * z0 + norm.ppf(0.025))
    bc_high_probability = norm.cdf(2 * z0 + norm.ppf(0.975))
    bc_low, bc_high = np.quantile(
        draws, [bc_low_probability, bc_high_probability]
    )

    below_zero = int(np.sum(draws < 0))
    above_zero = int(np.sum(draws > 0))
    opposite_side = min(below_zero, above_zero)
    p_plus_one = min(
        1.0,
        2.0 * (opposite_side + 1) / (len(draws) + 1),
    )

    return {
        "Bootstrap_SE": bootstrap_se,
        "Pct_CI_L": pct_low,
        "Pct_CI_U": pct_high,
        "BC_CI_L": bc_low,
        "BC_CI_U": bc_high,
        "Below_zero": below_zero,
        "Above_zero": above_zero,
        "Bootstrap_P": p_plus_one,
    }

