#lang scribble/lp2

@(require (for-label racket/base
                     scs))

@section[#:tag "ex-maxent"]{Maximum entropy}

This example, mirroring the SCS
@hyperlink["https://www.cvxgrp.org/scs/examples/python/entropy.html"]{entropy
example}, finds the maximum-entropy distribution on a finite set:

@nested[#:style 'inset]{
  maximize    @tt{−Σ x_i log x_i} @linebreak[]
  subject to  @tt{1ᵀx = 1}, @tt{x ≥ 0}
}

With only the simplex constraint the maximizer is the uniform distribution
@tt{x = (⅓, ⅓, ⅓)}, with entropy @tt{log 3}. This is the
@secref["ex-exp"] put to work: the @tech{epigraph trick} turns the nonlinear
objective into cone membership.

@chunk[<require>
(require scs)]

@chunk[<provide>
(provide run-example)]

@subsection{Epigraph form via the exponential cone}

Minimizing @tt{−Σ x_i log x_i} is minimizing @tt{Σ t_i} subject to
@tt{t_i ≥ x_i log x_i}. That epigraph constraint is exactly exponential-cone
membership:

@nested[#:style 'inset]{
  @tt{(−t_i, x_i, 1) ∈ K_exp   ⟺   x_i·e^(−t_i / x_i) ≤ 1   ⟺   t_i ≥ x_i log x_i}
}

Variables are @tt{w = (x₀, x₁, x₂, t₀, t₁, t₂)}. Row 0 is the simplex equality
@tt{Σ x = 1} (@tech{zero cone}); then three exponential-cone triples, each three
rows encoding @tt{(−t_i, x_i, 1)}:

@chunk[<matrix>
  (define A
    (scs:matrix 10 6
                ;; x0 x1 x2 t0 t1 t2
                 1  1  1  0  0  0    (code:comment "sum x = 1   (zero cone)")
                 0  0  0  1  0  0    (code:comment "s = -t0")
                -1  0  0  0  0  0    (code:comment "s = x0")
                 0  0  0  0  0  0    (code:comment "s = 1")
                 0  0  0  0  1  0    (code:comment "s = -t1")
                 0 -1  0  0  0  0    (code:comment "s = x1")
                 0  0  0  0  0  0    (code:comment "s = 1")
                 0  0  0  0  0  1    (code:comment "s = -t2")
                 0  0 -1  0  0  0    (code:comment "s = x2")
                 0  0  0  0  0  0))  (code:comment "s = 1")]

The @tt{1} rows for the third triple coordinate come from the @tt{b} vector
(the matching @tt{A} rows are zero). The objective @tt{c} sums the @tt{t_i}.

@chunk[<solve>
  (solve #:A A
         #:b #(1.0 0.0 0.0 1.0 0.0 0.0 1.0 0.0 0.0 1.0)
         #:c #(0.0 0.0 0.0 1.0 1.0 1.0)
         #:cone (make-cone #:zero 1 #:exp-primal 3)
         #:settings (make-settings #:eps-abs 1e-9 #:eps-rel 1e-9))]

@chunk[<run-example>
(define (run-example)
  <matrix>
  <solve>)]

@bold{Running it.}

@racketblock[
(scs-result-x (run-example))         (code:comment "#(0.333 0.333 0.333 ...)")
(- (scs-result-pobj (run-example)))  (code:comment "~ log 3, the maximum entropy")
]

@chunk[<*>
  <require>
  <provide>
  <run-example>]
