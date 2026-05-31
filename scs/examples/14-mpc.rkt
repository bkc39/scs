#lang scribble/lp2

@(require (for-label racket/base
                     ffi/unsafe
                     scs
                     scs/foreign))

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
(require ffi/unsafe
         scs
         scs/foreign)]

@chunk[<provide>
(provide run-example)]

@chunk[<make-info>
(define info-str-type (_array _byte 128))

(define (make-info)
  (new-scs-info
   #:status (ptr-ref (malloc 'atomic-interior info-str-type) info-str-type 0)
   #:lin_sys_solver (ptr-ref (malloc 'atomic-interior info-str-type) info-str-type 0)))]

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
               0  0 -1  0  0  0))  (code:comment "s = u2")

(define c (scs:vector->float-ptr #(0.0 0.0 0.0 0.0 0.0 0.0)))]

The right-hand side depends only on the initial state @tt{x₀} (its first
entry), and the box scale row contributes the @tt{1}:

@chunk[<rhs>
(define (rhs x0)
  (scs:vector->float-ptr (vector x0 0.0 0.0 1.0 0.0 0.0 0.0)))]

@subsection{Receding horizon}

We solve for @tt{x₀ = 2}, then @racket[scs-update] the right-hand side and
warm-solve for @tt{x₀ = 1.5}. @racket[#:box-lower] and @racket[#:box-upper]
declare the bounds; the cone is three zero rows then the box block.

@chunk[<run>
(define (run-example [x0s '(2.0 1.5)])
  (define b0 (rhs (car x0s)))
  (define data (retain! (make-scs-data 7 6 G P b0 c) G P b0 c))
  (define cone
    (make-cone #:zero 3 #:box-lower '(-1.0 -1.0 -1.0) #:box-upper '(1.0 1.0 1.0)))
  (define stgs (make-settings #:eps-abs 1e-9 #:eps-rel 1e-9))
  (define work (scs-init data cone stgs))
  (define sx (malloc 'atomic-interior _scs-float 6))
  (define sy (malloc 'atomic-interior _scs-float 7))
  (define ss (malloc 'atomic-interior _scs-float 7))
  (define sol (retain! (make-scs-solution sx sy ss) sx sy ss))
  (define info (make-info))
  (for/list ([x0 (in-list x0s)]
             [step (in-naturals)])
    (define flag
      (cond
        [(zero? step) (scs-solve work sol info 0)]
        [else
         (scs-update work (rhs x0) c)
         (scs-solve work sol info 1)]))
    ;; w = (u0 u1 u2 x1 x2 x3); report the first control input u0.
    (define w (scs:float-ptr->vector (scs-solution-x sol) 6))
    (list x0 flag (vector-ref w 0))))]

@bold{Running it.}

Both initial states drive the first input to its lower bound:

@racketblock[
(run-example)   (code:comment "((2.0 1 -1.0) (1.5 1 -1.0))")
]

@chunk[<*>
  <require>
  <provide>
  <make-info>
  <P>
  <G>
  <rhs>
  <run>]
