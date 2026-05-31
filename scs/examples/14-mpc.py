#!/usr/bin/env python3
"""Python reproduction of 14-mpc.rkt (upstream `scs`).

Receding-horizon MPC with the box cone for input bounds.  The Racket version
warm-starts across initial states; warm starting changes the path, not the
optimum, so here we solve each state fresh.  Prints {"values": [...]} = the first
control input u0 at each initial state.  Run inside `nix develop`.
"""
import json

import numpy as np
import scipy.sparse as sp
import scs


def solve_example(x0s=(2.0, 1.5)):
    P = sp.csc_matrix(np.triu(np.diag([0.2, 0.2, 0.2, 2, 2, 2.0])))
    G = sp.csc_matrix(np.array([[-1, 0, 0, 1, 0, 0],
                                [0, -1, 0, -1, 1, 0],
                                [0, 0, -1, 0, -1, 1],
                                [0, 0, 0, 0, 0, 0],
                                [-1, 0, 0, 0, 0, 0],
                                [0, -1, 0, 0, 0, 0],
                                [0, 0, -1, 0, 0, 0]], float))
    c = np.zeros(6)
    cone = dict(z=3, bl=[-1.0, -1, -1], bu=[1.0, 1, 1])
    values = []
    for x0 in x0s:
        h = np.array([x0, 0, 0, 1, 0, 0, 0], float)
        sol = scs.solve(dict(P=P, A=G, b=h, c=c), cone,
                        verbose=False, eps_abs=1e-9, eps_rel=1e-9)
        values.append(sol["x"][0])  # first control input u0
    return values


if __name__ == "__main__":
    print(json.dumps({"values": solve_example()}))
