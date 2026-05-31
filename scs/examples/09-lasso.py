#!/usr/bin/env python3
"""Python reproduction of 09-lasso.rkt (upstream `scs`).

minimize (1/2)||A x - b||^2 + lambda||x||_1 over a regularization path; vars
w = (x0, x1, t0, t1) with |x_i| <= t_i.  Only c changes with lambda.  Prints
{"values": [...]} = the x (first two coords) at each lambda, concatenated.
Run inside `nix develop`.
"""
import json

import numpy as np
import scipy.sparse as sp
import scs


def solve_example(lambdas=(0.1, 0.3)):
    # P has AtA on the x-block (upper triangle); zeros on the t-block.
    P = sp.csc_matrix(np.triu(np.array([[2.0, 1, 0, 0], [1, 2, 0, 0],
                                        [0, 0, 0, 0], [0, 0, 0, 0]])))
    G = sp.csc_matrix(np.array([[1, 0, -1, 0], [-1, 0, -1, 0],
                                [0, 1, 0, -1], [0, -1, 0, -1]], float))
    h = np.zeros(4)
    values = []
    for lam in lambdas:
        c = np.array([-1.5, -2.5, lam, lam])
        sol = scs.solve(dict(P=P, A=G, b=h, c=c), dict(l=4),
                        verbose=False, eps_abs=1e-9, eps_rel=1e-9)
        values += list(sol["x"][:2])
    return values


if __name__ == "__main__":
    print(json.dumps({"values": solve_example()}))
