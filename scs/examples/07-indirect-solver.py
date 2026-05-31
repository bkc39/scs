#!/usr/bin/env python3
"""Python reproduction of 07-indirect-solver.rkt (upstream `scs`).

Same QP as example 02, solved with the indirect (conjugate-gradient) solver via
use_indirect=True.  Prints {"values": [...]} = the primal solution x.
Run inside `nix develop`.
"""
import json

import numpy as np
import scipy.sparse as sp
import scs


def solve_example():
    P = sp.csc_matrix(np.array([[3.0, -1.0], [0.0, 2.0]]))  # upper triangle
    A = sp.csc_matrix(np.array([[-1.0, 1.0], [1.0, 0.0], [0.0, 1.0]]))
    b = np.array([-1.0, 0.3, -0.5])
    c = np.array([-1.0, -1.0])
    sol = scs.solve(dict(P=P, A=A, b=b, c=c), dict(z=1, l=2),
                    verbose=False, eps_abs=1e-9, eps_rel=1e-9,
                    use_indirect=True)
    return list(sol["x"])


if __name__ == "__main__":
    print(json.dumps({"values": solve_example()}))
