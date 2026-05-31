#!/usr/bin/env python3
"""Python reproduction of 06-power-cone.rkt (upstream `scs`).

Prints {"values": [...]} = the primal solution x = (x, y, z).
Run inside `nix develop`.
"""
import json

import numpy as np
import scipy.sparse as sp
import scs


def solve_example():
    A = sp.csc_matrix(np.array([[1.0, 0.0, 0.0],
                                [0.0, 1.0, 0.0],
                                [-1.0, 0.0, 0.0],
                                [0.0, -1.0, 0.0],
                                [0.0, 0.0, -1.0]]))
    b = np.array([2.0, 8.0, 0.0, 0.0, 0.0])
    c = np.array([0.0, 0.0, -1.0])
    sol = scs.solve(dict(A=A, b=b, c=c), dict(z=2, p=[0.5]),
                    verbose=False, eps_abs=1e-9, eps_rel=1e-9)
    return list(sol["x"])


if __name__ == "__main__":
    print(json.dumps({"values": solve_example()}))
