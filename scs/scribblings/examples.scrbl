#lang scribble/manual

@(require (for-label racket/base
                     scs))

@title[#:tag "examples"]{Examples}

Each example below has a runnable counterpart in the package's @filepath{examples/}
directory (e.g. @filepath{examples/00-quadratic-program.rkt}) with a
@racket[module+] test. They mirror the worked examples in the SCS
@hyperlink["https://www.cvxgrp.org/scs/examples/index.html"]{documentation},
rewritten in Racket.

@; ----------------------------------------------------------------------------
@section{Quadratic and linear programs}

A quadratic program with one equality and two inequalities
(@filepath{examples/00-quadratic-program.rkt}); optimum @tt{x = (0.3, -0.7)}:

@racketblock[
(solve #:A (scs:matrix 3 2  -1 1   1 0   0 1)
       #:b #(-1.0 0.3 -0.5)
       #:c #(-1.0 -1.0)
       #:P (scs:sparse-matrix 2 2 '(0 0 3) '(0 1 -1) '(1 1 2))
       #:cone (make-cone #:zero 1 #:positive 2))
]

A pure linear program over the positive orthant
(@filepath{examples/01-linear-program.rkt}) drops @racket[#:P] and uses only
@racket[#:positive] rows.

@; ----------------------------------------------------------------------------
@section{Second-order cone}

Minimize @tt{t} subject to ‖(u, v)‖₂ ≤ t with @tt{u}, @tt{v} pinned by equalities
(@filepath{examples/02-second-order-cone.rkt}); optimum @tt{(t, u, v) = (5, 3, 4)}.
The SOC block is encoded with @tt{A = -I} so the slack @tt{s = (t, u, v)} lands
in the cone:

@racketblock[
(solve #:A (scs:matrix 5 3
                       0 1 0     (code:comment "u = 3")
                       0 0 1     (code:comment "v = 4")
                       -1 0 0    (code:comment "SOC block")
                       0 -1 0
                       0 0 -1)
       #:b #(3.0 4.0 0.0 0.0 0.0)
       #:c #(1.0 0.0 0.0)
       #:cone (make-cone #:zero 2 #:soc '(3)))
]

@; ----------------------------------------------------------------------------
@section[#:tag "ex-sdp"]{Semidefinite program}

Minimize the trace of a 2×2 PSD matrix @tt{X = [[a b] [b c]]} subject to
@tt{b = 1} (@filepath{examples/03-semidefinite.rkt}); optimum
@tt{(a, b, c) = (1, 1, 1)}. The PSD block uses the @tt{√2}-scaled vectorization
@tt{(a, √2·b, c)} (see @secref["psd-cones"]):

@racketblock[
(define root2 (sqrt 2.0))
(solve #:A (scs:matrix 4 3
                       0 1 0           (code:comment "b = 1")
                       -1 0 0          (code:comment "svec = (a, root2 b, c)")
                       0 (- root2) 0
                       0 0 -1)
       #:b #(1.0 0.0 0.0 0.0)
       #:c #(1.0 0.0 1.0)
       #:cone (make-cone #:zero 1 #:psd '(2)))
]

@; ----------------------------------------------------------------------------
@section{Exponential cone}

Minimize @tt{z} subject to @tt{(x, y, z)} in the exponential cone with
@tt{x = y = 1} (@filepath{examples/04-exponential-cone.rkt}); the cone forces
@tt{z ≥ e}, so the optimum is @tt{z = e}.

@; ----------------------------------------------------------------------------
@section[#:tag "ex-lasso"]{Lasso with warm starting}

@tt{minimize (1/2)‖Ax − b‖² + λ‖x‖₁} over a sequence of @tt{λ}
(@filepath{examples/07-lasso.rkt}), mirroring the SCS
@hyperlink["https://www.cvxgrp.org/scs/examples/python/lasso.html"]{lasso example}.
Writing @tt{|x_i| ≤ t_i} as two linear inequalities gives a quadratic cone
program in @tt{(x, t)} where @tt{P} carries @tt{AᵀA}; only @tt{c} changes with
@tt{λ}, so a single workspace is reused and @racket[scs-update]d across the
regularization path:

@racketblock[
(require scs scs/foreign)
(define work (scs-init data cone stgs))
(scs-solve work sol info 0)               (code:comment "first lambda")
(scs-update work b (cost next-lambda))    (code:comment "only c changes")
(scs-solve work sol info 1)               (code:comment "warm-started re-solve")
]

@; ----------------------------------------------------------------------------
@section{Maximum entropy}

@tt{maximize −Σ x_i log x_i} over the probability simplex
(@filepath{examples/08-max-entropy.rkt}), mirroring the SCS
@hyperlink["https://www.cvxgrp.org/scs/examples/python/entropy.html"]{entropy
example}. The epigraph @tt{t_i ≥ x_i log x_i} is the exponential-cone membership
@tt{(−t_i, x_i, 1) ∈ K_exp}. With only the simplex constraint the maximizer is
the uniform distribution.

@; ----------------------------------------------------------------------------
@section[#:tag "ex-mpc"]{Model predictive control}

A finite-horizon control problem with input bounds via the box cone and
receding-horizon warm starting (@filepath{examples/09-mpc.rkt}), mirroring the
SCS @hyperlink["https://www.cvxgrp.org/scs/examples/python/mpc.html"]{MPC
example}. The bounds @tt{−1 ≤ u_t ≤ 1} use @racket[#:box-lower] and
@racket[#:box-upper], and the workspace is @racket[scs-update]d as the initial
state evolves.
