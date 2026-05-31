#!/usr/bin/env python3
"""Python reproduction of 05-semidefinite.rkt (upstream `scs`).

Prints {"values": [...]} = the primal solution x = (a, b, c).  The PSD block
uses the sqrt(2)-scaled svec, so A = -diag(1, sqrt(2), 1) on those rows.
Run inside `nix develop`.
"""
import json

import numpy as np
import scipy.sparse as sp
import scs


def solve_example():
    root2 = np.sqrt(2.0)
    A = sp.csc_matrix(np.array([[0.0, 1.0, 0.0],
                                [-1.0, 0.0, 0.0],
                                [0.0, -root2, 0.0],
                                [0.0, 0.0, -1.0]]))
    b = np.array([1.0, 0.0, 0.0, 0.0])
    c = np.array([1.0, 0.0, 1.0])
    sol = scs.solve(dict(A=A, b=b, c=c), dict(z=1, s=[2]),
                    verbose=False, eps_abs=1e-9, eps_rel=1e-9)
    return list(sol["x"])


if __name__ == "__main__":
    print(json.dumps({"values": solve_example()}))
