#lang scribble/lp2

@(require (for-label racket/base
                     scs))

@section[#:tag "ex-mpc"]{Model predictive control}

@deftech{Model predictive control} (MPC) repeatedly solves a finite-horizon
optimal-control problem as the system state evolves, applying the first control
and re-solving. It mirrors the SCS
@hyperlink["https://www.cvxgrp.org/scs/examples/python/mpc.html"]{MPC example}
and showcases two features: the @tech{box cone} for input bounds, and
receding-horizon @tech{warm starting} when only @tt{b} changes between solves.

For a scalar system @tt{x_{t+1} = x_t + u_t} over horizon @tt{T = 3} with
@tt{x₀} given:

@nested[#:style 'inset]{
  minimize    @tt{Σ_{t=1}^{3} x_t² + 0.1·Σ_{t=0}^{2} u_t²} @linebreak[]
  subject to  @tt{x_{t+1} = x_t + u_t}, @tt{−1 ≤ u_t ≤ 1}
}

Variables are @tt{w = (u₀, u₁, u₂, x₁, x₂, x₃)}.

@chunk[<require>
(require scs)]

@chunk[<provide>
(provide run-example)]

@subsection{Objective and dynamics}

The quadratic cost gives @tt{P} entries @tt{0.2} on each @tt{u_t} (from
@tt{0.1·u² = ½·0.2·u²}) and @tt{2} on each @tt{x_t}:

@chunk[<P>
(define P
  (scs:sparse-matrix 6 6
                     '(0 0 0.2) '(1 1 0.2) '(2 2 0.2)
                     '(3 3 2) '(4 4 2) '(5 5 2)))]

@subsection{The box cone for input bounds}

The bounds @tt{−1 ≤ u_t ≤ 1} use SCS's box cone @tt{{(s₀, r) : s₀·l ≤ r ≤
s₀·u}}. Its first row is the scale @tt{s₀}, which we pin to @tt{1} with a
constant row (all-zero @tt{A} coefficients and right-hand side @tt{1}); the
remaining rows carry @tt{u₀..u₂}. The three dynamics equations come first as
the @tech{zero cone}:

@chunk[<G>
(define G
  (scs:matrix 7 6
              ;; u0 u1 u2 x1 x2 x3
              -1  0  0  1  0  0    (code:comment "x1 - u0 = x0   (dynamics)")
               0 -1  0 -1  1  0    (code:comment "x2 - x1 - u1 = 0")
               0  0 -1  0 -1  1    (code:comment "x3 - x2 - u2 = 0")
               0  0  0  0  0  0    (code:comment "box scale row -> s0 = 1")
              -1  0  0  0  0  0    (code:comment "s = u0")
               0 -1  0  0  0  0    (code:comment "s = u1")
               0  0 -1  0  0  0))] (code:comment "s = u2")

The right-hand side depends only on the initial state @tt{x₀} (its first
entry), and the box scale row contributes the @tt{1}:

@chunk[<rhs>
(define (rhs x0)
  (vector x0 0.0 0.0 1.0 0.0 0.0 0.0))]

@subsection{Receding horizon}

We build the solver for @tt{x₀ = 2}, solve it, then @racket[solver-update!] the
right-hand side and warm-solve for @tt{x₀ = 1.5}. @racket[#:box-lower] and
@racket[#:box-upper] declare the bounds; the cone is three zero rows then the
box block.

@chunk[<run>
(define (run-example [x0s '(2.0 1.5)])
  (define s
    (make-solver #:A G
                 #:b (rhs (car x0s))
                 #:c #(0.0 0.0 0.0 0.0 0.0 0.0)
                 #:P P
                 #:cone (make-cone #:zero 3
                                   #:box-lower '(-1.0 -1.0 -1.0)
                                   #:box-upper '(1.0 1.0 1.0))
                 #:settings (make-settings #:eps-abs 1e-9 #:eps-rel 1e-9)))
  (for/list ([x0 (in-list x0s)]
             [step (in-naturals)])
    (define r
      (cond
        [(zero? step) (solver-solve! s)]
        [else
         (solver-update! s #:b (rhs x0))
         (solver-solve! s)]))
    ;; w = (u0 u1 u2 x1 x2 x3); report the first control input u0.
    (list x0 (scs-result-exit-flag r) (vector-ref (scs-result-x r) 0))))]

@bold{Running it.}

Both initial states drive the first input to its lower bound:

@racketblock[
(run-example)   (code:comment "((2.0 1 -1.0) (1.5 1 -1.0))")
]

@chunk[<*>
  <require>
  <provide>
  <P>
  <G>
  <rhs>
  <run>]
