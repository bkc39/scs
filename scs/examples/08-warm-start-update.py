#!/usr/bin/env python3
"""Python reproduction of 08-warm-start-update.rkt (upstream `scs`).

The Racket version reuses one workspace and warm-starts; warm starting changes
the solver path, not the optimum, so here we simply solve each right-hand side
fresh.  Prints {"values": [...]} = the two solutions x concatenated.
Run inside `nix develop`.
"""
import json

import numpy as np
import scipy.sparse as sp
import scs


def solve_example():
    A = sp.csc_matrix(np.array([[1.0, 0.0],
                                [0.0, 1.0],
                                [-1.0, 0.0],
                                [0.0, -1.0]]))
    c = np.array([-1.0, -1.0])
    values = []
    for b in (np.array([1.0, 1.0, 0.0, 0.0]), np.array([2.0, 3.0, 0.0, 0.0])):
        sol = scs.solve(dict(A=A, b=b, c=c), dict(l=4),
                        verbose=False, eps_abs=1e-9, eps_rel=1e-9)
        values += list(sol["x"])
    return values


if __name__ == "__main__":
    print(json.dumps({"values": solve_example()}))
