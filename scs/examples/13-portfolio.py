#!/usr/bin/env python3
"""Python reproduction of 13-portfolio.rkt (upstream `scs`).

Markowitz: minimize w'Sigma w s.t. 1'w = 1, mu'w >= r, w >= 0.  Prints
{"values": [...]} = the portfolio weights w.  Run inside `nix develop`.
"""
import json

import numpy as np
import scipy.sparse as sp
import scs


def optimize_portfolio(Sigma, mu, min_return):
    Sigma = np.asarray(Sigma, float)
    mu = np.asarray(mu, float)
    n = len(mu)
    P = sp.csc_matrix(np.triu(2.0 * Sigma))
    budget = np.ones(n)             # 1'w = 1            (zero cone)
    ret = -mu                       # -mu'w <= -r        (positive orthant)
    long_only = -np.eye(n)          # -w_i <= 0
    A = sp.csc_matrix(np.vstack([budget, ret, long_only]))
    b = np.concatenate([[1.0, -min_return], np.zeros(n)])
    c = np.zeros(n)
    sol = scs.solve(dict(P=P, A=A, b=b, c=c), dict(z=1, l=n + 1),
                    verbose=False, eps_abs=1e-9, eps_rel=1e-9)
    return list(sol["x"])


def solve_example():
    Sigma = [[2.0, 0.0], [0.0, 1.0]]
    mu = [0.2, 0.1]
    return optimize_portfolio(Sigma, mu, 0.15)


if __name__ == "__main__":
    print(json.dumps({"values": solve_example()}))
