#!/usr/bin/env python3
"""Python reproduction of 11-max-entropy.rkt (upstream `scs`).

max -sum x_i log x_i s.t. 1'x = 1, via the exponential cone with
(-t_i, x_i, 1) in K_exp.  Prints {"values": [...]} = the primal x = (x0..2, t0..2).
Run inside `nix develop`.
"""
import json

import numpy as np
import scipy.sparse as sp
import scs


def solve_example():
    rows = [[1, 1, 1, 0, 0, 0]]
    for i in range(3):
        r1 = [0] * 6; r1[3 + i] = 1
        r2 = [0] * 6; r2[i] = -1
        rows += [r1, r2, [0] * 6]
    A = sp.csc_matrix(np.array(rows, float))
    b = np.array([1.0, 0, 0, 1, 0, 0, 1, 0, 0, 1])
    c = np.array([0, 0, 0, 1, 1, 1], float)
    sol = scs.solve(dict(A=A, b=b, c=c), dict(z=1, ep=3),
                    verbose=False, eps_abs=1e-9, eps_rel=1e-9)
    return list(sol["x"])


if __name__ == "__main__":
    print(json.dumps({"values": solve_example()}))
