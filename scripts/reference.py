#!/usr/bin/env python3
"""Reference solutions from the upstream Python `scs` package.

Run inside `nix develop` (which provides python3 with scs/numpy/scipy):

    python scripts/reference.py

Prints the solution of each example problem so the Racket bindings can be
cross-checked against the reference implementation.  The numbers printed for the
QP and LP are mirrored as constants in scs/tests/reference-test.rkt; re-run this
script to regenerate them if the problems change.
"""

import numpy as np
import scipy.sparse as sp
import scs


def report(name, data, cone, **settings):
    sol = scs.solve(data, cone, verbose=False, **settings)
    info = sol["info"]
    print(f"=== {name} ===")
    print(f"  status: {info['status']}")
    print(f"  x:      {np.array2string(sol['x'], precision=10)}")
    print(f"  y:      {np.array2string(sol['y'], precision=10)}")
    print(f"  pobj:   {info['pobj']:.10f}")
    print(f"  dobj:   {info['dobj']:.10f}")
    print()
    return sol


def qp():
    # minimize (1/2) x'P x + c'x s.t. -x0+x1 = -1, x0 <= 0.3, x1 <= -0.5
    P = sp.csc_matrix(np.array([[3.0, -1.0], [0.0, 2.0]]))  # upper triangle
    A = sp.csc_matrix(np.array([[-1.0, 1.0], [1.0, 0.0], [0.0, 1.0]]))
    b = np.array([-1.0, 0.3, -0.5])
    c = np.array([-1.0, -1.0])
    report("QP (example 00)",
           dict(P=P, A=A, b=b, c=c), dict(z=1, l=2),
           eps_abs=1e-9, eps_rel=1e-9)


def lp():
    # maximize x0 + x1 s.t. x0 <= 1, x1 <= 1, x0 >= 0, x1 >= 0
    A = sp.csc_matrix(np.array([[1.0, 0.0], [0.0, 1.0],
                                [-1.0, 0.0], [0.0, -1.0]]))
    b = np.array([1.0, 1.0, 0.0, 0.0])
    c = np.array([-1.0, -1.0])
    report("LP (example 01)",
           dict(A=A, b=b, c=c), dict(l=4),
           eps_abs=1e-9, eps_rel=1e-9)


def soc():
    # minimize t s.t. ||(u,v)|| <= t, u = 3, v = 4
    A = sp.csc_matrix(np.array([[0.0, 1.0, 0.0], [0.0, 0.0, 1.0],
                                [-1.0, 0.0, 0.0], [0.0, -1.0, 0.0],
                                [0.0, 0.0, -1.0]]))
    b = np.array([3.0, 4.0, 0.0, 0.0, 0.0])
    c = np.array([1.0, 0.0, 0.0])
    report("SOC (example 02)",
           dict(A=A, b=b, c=c), dict(z=2, q=[3]),
           eps_abs=1e-9, eps_rel=1e-9)


def exp_cone():
    # minimize z s.t. (x,y,z) in K_exp, x = 1, y = 1  ->  z = e
    A = sp.csc_matrix(np.array([[1.0, 0.0, 0.0], [0.0, 1.0, 0.0],
                                [-1.0, 0.0, 0.0], [0.0, -1.0, 0.0],
                                [0.0, 0.0, -1.0]]))
    b = np.array([1.0, 1.0, 0.0, 0.0, 0.0])
    c = np.array([0.0, 0.0, 1.0])
    report("EXP (example 04)",
           dict(A=A, b=b, c=c), dict(z=2, ep=1),
           eps_abs=1e-9, eps_rel=1e-9)


def lasso():
    # min 1/2||Ax-b||^2 + lambda||x||_1 ; vars (x0,x1,t0,t1); |x_i| <= t_i.
    # P has AtA on the x-block; only c changes with lambda (warm-start path).
    P = sp.csc_matrix(np.triu(np.array([[2.0, 1, 0, 0], [1, 2, 0, 0],
                                        [0, 0, 0, 0], [0, 0, 0, 0]])))
    G = sp.csc_matrix(np.array([[1, 0, -1, 0], [-1, 0, -1, 0],
                                [0, 1, 0, -1], [0, -1, 0, -1]], float))
    h = np.zeros(4)
    for lam in (0.1, 0.3):
        c = np.array([-1.5, -2.5, lam, lam])
        report(f"lasso (example 07, lambda={lam})",
               dict(P=P, A=G, b=h, c=c), dict(l=4),
               eps_abs=1e-9, eps_rel=1e-9)


def max_entropy():
    # max -sum x log x s.t. 1'x=1 ; vars (x0..2,t0..2); (-t_i,x_i,1) in Kexp.
    rows = [[1, 1, 1, 0, 0, 0]]
    for i in range(3):
        r1 = [0] * 6; r1[3 + i] = 1
        r2 = [0] * 6; r2[i] = -1
        rows += [r1, r2, [0] * 6]
    G = sp.csc_matrix(np.array(rows, float))
    h = np.array([1.0, 0, 0, 1, 0, 0, 1, 0, 0, 1])
    c = np.array([0, 0, 0, 1, 1, 1], float)
    report("max-entropy (example 08)",
           dict(A=G, b=h, c=c), dict(z=1, ep=3), eps_abs=1e-9, eps_rel=1e-9)


def mpc():
    # x_{t+1}=x_t+u_t, x0=2, T=3, min sum x_t^2 + 0.1 u_t^2, |u|<=1 (box cone).
    # vars w=(u0,u1,u2,x1,x2,x3).
    P = sp.csc_matrix(np.triu(np.diag([0.2, 0.2, 0.2, 2, 2, 2.0])))
    G = sp.csc_matrix(np.array([[-1, 0, 0, 1, 0, 0],
                                [0, -1, 0, -1, 1, 0],
                                [0, 0, -1, 0, -1, 1],
                                [0, 0, 0, 0, 0, 0],
                                [-1, 0, 0, 0, 0, 0],
                                [0, -1, 0, 0, 0, 0],
                                [0, 0, -1, 0, 0, 0]], float))
    h = np.array([2.0, 0, 0, 1, 0, 0, 0])
    c = np.zeros(6)
    report("mpc (example 09, x0=2)",
           dict(P=P, A=G, b=h, c=c),
           dict(z=3, bl=[-1.0, -1, -1], bu=[1.0, 1, 1]),
           eps_abs=1e-9, eps_rel=1e-9)


if __name__ == "__main__":
    print(f"scs version: {scs.__version__}\n")
    qp()
    lp()
    soc()
    exp_cone()
    lasso()
    max_entropy()
    mpc()
