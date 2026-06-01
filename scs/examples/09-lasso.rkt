#lang scribble/lp2

@(require (for-label racket/base
                     scs))

@section[#:tag "ex-lasso"]{Lasso along a regularization path}

The @deftech{lasso} is L1-regularized least squares,

@nested[#:style 'inset]{
  minimize  @tt{½‖A x − b‖₂² + λ‖x‖₁}
}

It mirrors the SCS
@hyperlink["https://www.cvxgrp.org/scs/examples/python/lasso.html"]{lasso
example}. The L1 term is handled with the standard @tech{absolute-value trick}:
introduce @tt{t} with @tt{|x_i| ≤ t_i} (two linear inequalities each) and
minimize @tt{Σ t_i}. Over @tt{w = (x, t)} this is the quadratic cone program

@nested[#:style 'inset]{
  minimize    @tt{½ wᵀP w + c(λ)ᵀ w} @linebreak[]
  subject to  @tt{x_i − t_i ≤ 0}, @tt{−x_i − t_i ≤ 0}
}

where @tt{P} carries @tt{AᵀA} on the @tt{x} block and
@tt{c(λ) = (−Aᵀb, λ·1)}. Crucially, @bold{only @tt{c} changes with @tt{λ}}, so
we build one solver and @racket[solver-update!] its @tt{c} as we sweep the path,
warm starting each re-solve --- the pattern from @secref["ex-warm-start"].

The data is @tt{A = [[1 0] [0 1] [1 1]]}, @tt{b = (1, 2, 0.5)}, giving
@tt{AᵀA = [[2 1] [1 2]]} and @tt{Aᵀb = (1.5, 2.5)}. Variables are
@tt{w = (x₀, x₁, t₀, t₁)}.

@chunk[<require>
(require scs)]

@chunk[<provide>
(provide run-example)]

@subsection{The fixed data: P, constraints, and c(λ)}

@tt{P} holds @tt{AᵀA} in the @tt{x} block (upper triangle) and zeros on the
@tt{t} block:

@chunk[<P>
(define P (scs:sparse-matrix 4 4 '(0 0 2) '(0 1 1) '(1 1 2)))]

The constraint matrix encodes @tt{x_i − t_i ≤ 0} and @tt{−x_i − t_i ≤ 0}:

@chunk[<G>
(define G
  (scs:matrix 4 4
              ;; x0  x1  t0  t1
               1   0  -1   0
              -1   0  -1   0
               0   1   0  -1
               0  -1   0  -1))]

Only the objective depends on @tt{λ}: @tt{c(λ) = (−Aᵀb, λ, λ)}.

@chunk[<cost>
(define (cost lambda)
  (vector -1.5 -2.5 lambda lambda))]

@subsection{Sweeping the path}

We build the solver at the first @tt{λ}, solve it cold, then for each subsequent
@tt{λ} call @racket[solver-update!] with the new @tt{c} and re-solve (warm
started automatically). The result is a list of @tt{(λ flag x)} rows.

@chunk[<run>
(define (run-example [lambdas '(0.1 0.3)])
  (define s
    (make-solver #:A G
                 #:b #(0.0 0.0 0.0 0.0)
                 #:c (cost (car lambdas))
                 #:P P
                 #:cone (make-cone #:positive 4)
                 #:settings (make-settings #:eps-abs 1e-9 #:eps-rel 1e-9)))
  (for/list ([lambda (in-list lambdas)]
             [step (in-naturals)])
    (define r
      (cond
        [(zero? step) (solver-solve! s)]
        [else
         (solver-update! s #:c (cost lambda))
         (solver-solve! s)]))
    (define x (scs-result-x r))
    (list lambda (scs-result-exit-flag r)
          (vector (vector-ref x 0) (vector-ref x 1)))))]

@bold{Running it.}

Larger @tt{λ} shrinks @tt{x} toward zero:

@racketblock[
(run-example)
(code:comment "((0.1 1 #(0.1333 1.1333)) (0.3 1 #(0.0667 1.0667)))")
]

@chunk[<*>
  <require>
  <provide>
  <P>
  <G>
  <cost>
  <run>]
