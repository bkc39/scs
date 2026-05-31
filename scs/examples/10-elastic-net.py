#!/usr/bin/env python3
"""Python reproduction of 10-elastic-net.rkt (upstream `scs`).

minimize ||X w - y||^2 + lambda*alpha||w||^2 + lambda(1-alpha)||w||_1, as a QP
over (w, t) with |w_i| <= t_i.  Prints {"values": [...]} = the ridge (alpha=1)
weights followed by the elastic (alpha=0.5) weights.  Run inside `nix develop`.
"""
import json

import numpy as np
import scipy.sparse as sp
import scs


def elastic_net(X, y, lam, alpha):
    X = np.asarray(X, float)
    y = np.asarray(y, float)
    n = X.shape[1]
    n2 = 2 * n
    XtX = X.T @ X
    Xty = X.T @ y
    # P: 2(XtX + lam*alpha*I) on the w-block, zeros on the t-block.
    Pdense = np.zeros((n2, n2))
    Pdense[:n, :n] = 2.0 * (XtX + lam * alpha * np.eye(n))
    P = sp.csc_matrix(np.triu(Pdense))
    # Constraints: w_i - t_i <= 0 and -w_i - t_i <= 0.
    rows = []
    for i in range(n):
        r1 = np.zeros(n2); r1[i] = 1.0; r1[n + i] = -1.0
        r2 = np.zeros(n2); r2[i] = -1.0; r2[n + i] = -1.0
        rows += [r1, r2]
    A = sp.csc_matrix(np.array(rows))
    b = np.zeros(n2)
    c = np.concatenate([-2.0 * Xty, np.full(n, lam * (1.0 - alpha))])
    sol = scs.solve(dict(P=P, A=A, b=b, c=c), dict(l=n2),
                    verbose=False, eps_abs=1e-9, eps_rel=1e-9)
    return list(sol["x"][:n])


def solve_example():
    X = [[1.0, 0.0], [0.0, 1.0], [1.0, 1.0]]
    y = [1.0, 2.0, 0.5]
    return elastic_net(X, y, 0.1, 1.0) + elastic_net(X, y, 0.2, 0.5)


if __name__ == "__main__":
    print(json.dumps({"values": solve_example()}))
