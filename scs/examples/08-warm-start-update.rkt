#lang scribble/lp2

@(require (for-label racket/base
                     scs))

@section[#:tag "ex-warm-start"]{Warm starting and re-solving}

When you solve a @emph{sequence} of problems that differ only in the right-hand
side @tt{b} or the objective @tt{c}, you can keep one solver, swap in the new
data, and re-solve @deftech{warm starting} from the previous solution. This is
much cheaper than rebuilding from scratch, and it is the pattern behind the
lasso (@secref["ex-lasso"]) and MPC (@secref["ex-mpc"]) examples.

The high-level @racket[make-solver] builds a reusable solver;
@racket[solver-solve!] solves it (warm starting automatically on every call
after the first), and @racket[solver-update!] swaps in a new @tt{b} and/or
@tt{c}. No native memory is managed by hand.

We reuse the linear program of @secref["ex-lp"], solving first with bounds
@tt{b = (1, 1)} (giving @tt{x = (1, 1)}), then updating to @tt{b = (2, 3)}
(giving @tt{x = (2, 3)}).

@chunk[<require>
(require scs)]

@chunk[<provide>
(provide run-example)]

@subsection{Building the solver}

@racket[make-solver] takes the same problem description as @racket[solve] --- the
constraint matrix, the right-hand side, the objective, and the cone --- but
returns a reusable solver instead of solving immediately:

@chunk[<setup>
  (define A
    (scs:matrix 4 2
                 1   0
                 0   1
                -1   0
                 0  -1))
  (define s
    (make-solver #:A A
                 #:b #(1.0 1.0 0.0 0.0)
                 #:c #(-1.0 -1.0)
                 #:cone (make-cone #:positive 4)
                 #:settings (make-settings #:eps-abs 1e-9 #:eps-rel 1e-9)))]

@subsection{Solve, update, re-solve}

The first @racket[solver-solve!] is a cold start. @racket[solver-update!] swaps
in the new @tt{b}, and the second @racket[solver-solve!] warm starts from the
previous iterate automatically:

@chunk[<run>
  (define r1 (solver-solve! s))
  (define x1 (scs-result-x r1))

  (solver-update! s #:b #(2.0 3.0 0.0 0.0))
  (define r2 (solver-solve! s))
  (define x2 (scs-result-x r2))

  (list (list (scs-result-exit-flag r1) x1)
        (list (scs-result-exit-flag r2) x2))]

@chunk[<run-example>
(define (run-example)
  <setup>
  <run>)]

@bold{Running it.}

@racketblock[
(run-example)
(code:comment "'((1 #(1.0 1.0)) (1 #(2.0 3.0)))")
]

For full control --- driving the C workspace directly, custom solution buffers,
deterministic release --- the @racketmodname[scs/foreign] layer is still
available; @racket[make-solver] is the ergonomic path for the common case.

@chunk[<*>
  <require>
  <provide>
  <run-example>]
