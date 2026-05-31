#lang scribble/lp2

@(require (for-label racket/base
                     scs))

@section[#:tag "ex-qp"]{Quadratic program}

A @deftech{quadratic program} adds a quadratic term to the objective. We solve

@nested[#:style 'inset]{
  minimize    @tt{½ xᵀP x + cᵀx} @linebreak[]
  subject to  @tt{−x₀ + x₁ = −1} @linebreak[]
  @tt{x₀ ≤ 0.3}, @tt{x₁ ≤ −0.5}
}

with @tt{P = [[3 −1] [−1 2]]} and @tt{c = (−1, −1)}; the optimum is
@tt{x = (0.3, −0.7)}. This is the linear program of @secref["ex-lp"] plus a
@racket[#:P] matrix and one equality (@tech{zero cone}) row.

@chunk[<require>
(require scs)]

@chunk[<provide>
(provide run-example)]

@subsection{The objective matrix}

SCS reads @tt{P} as a symmetric matrix but only needs its upper triangle, which
@racket[scs:sparse-matrix] takes as @tt{(row col value)} triples. Here that is
@tt{P₀₀ = 3}, @tt{P₀₁ = −1}, @tt{P₁₁ = 2}:

@chunk[<P>
  (define P
    (scs:sparse-matrix 2 2
                       '(0 0 3)
                       '(0 1 -1)
                       '(1 1 2)))]

@subsection{Constraints}

The first row is the equality @tt{−x₀ + x₁ = −1}; the next two are the upper
bounds @tt{x₀ ≤ 0.3} and @tt{x₁ ≤ −0.5}. The rows must appear in cone order ---
zero-cone rows first, then positive-orthant rows --- matching the
@racket[make-cone] keywords:

@chunk[<matrix>
  (define A
    (scs:matrix 3 2
                ;; x0  x1
                -1   1     (code:comment "-x0 + x1 = -1   (zero cone)")
                 1   0     (code:comment "x0 <= 0.3       (positive)")
                 0   1))   (code:comment "x1 <= -0.5      (positive)")]

@chunk[<solve>
  (solve #:A A
         #:b #(-1.0 0.3 -0.5)
         #:c #(-1.0 -1.0)
         #:P P
         #:cone (make-cone #:zero 1 #:positive 2)
         #:settings (make-settings #:eps-abs 1e-9 #:eps-rel 1e-9))]

@chunk[<run-example>
(define (run-example)
  <P>
  <matrix>
  <solve>)]

@bold{Running it.}

@racketblock[
(scs-result-x (run-example))      (code:comment "#(0.3 -0.7)")
(scs-result-pobj (run-example))   (code:comment "the optimal objective value")
]

@chunk[<*>
  <require>
  <provide>
  <run-example>]
