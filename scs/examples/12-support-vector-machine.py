#!/usr/bin/env python3
"""Python reproduction of 12-support-vector-machine.rkt (upstream `scs`).

Soft-margin SVM as a QP over v = (w, b, slacks).  Prints {"values": [...]} =
[w0, w1, b].  Run inside `nix develop`.
"""
import json

import numpy as np
import scipy.sparse as sp
import scs


def train_svm(data, C=1.0):
    m = len(data)
    d = len(data[0][0])
    n = d + 1 + m
    b_col = d
    # P: identity on the w block -> (1/2)||w||^2.
    Pdense = np.zeros((n, n))
    for j in range(d):
        Pdense[j, j] = 1.0
    P = sp.csc_matrix(np.triu(Pdense))
    rows = []
    rhs = []
    for i, (xs, y) in enumerate(data):
        margin = np.zeros(n)
        for f in range(d):
            margin[f] = -y * xs[f]
        margin[b_col] = -y
        margin[d + 1 + i] = -1.0
        nonneg = np.zeros(n)
        nonneg[d + 1 + i] = -1.0
        rows += [margin, nonneg]
        rhs += [-1.0, 0.0]
    A = sp.csc_matrix(np.array(rows))
    b = np.array(rhs)
    c = np.concatenate([np.zeros(d + 1), np.full(m, C)])
    sol = scs.solve(dict(P=P, A=A, b=b, c=c), dict(l=2 * m),
                    verbose=False, eps_abs=1e-9, eps_rel=1e-9)
    x = sol["x"]
    return list(x[:d]) + [x[b_col]]


def solve_example():
    data = [((2.0, 1.0), 1), ((2.0, -1.0), 1),
            ((-2.0, 1.0), -1), ((-2.0, -1.0), -1)]
    return train_svm(data, C=1.0)


if __name__ == "__main__":
    print(json.dumps({"values": solve_example()}))
