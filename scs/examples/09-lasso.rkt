#lang scribble/lp2

@(require (for-label racket/base
                     ffi/unsafe
                     scs
                     scs/foreign))

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
we build one workspace and @racket[scs-update] it as we sweep the path --- the
warm-start pattern from @secref["ex-warm-start"].

The data is @tt{A = [[1 0] [0 1] [1 1]]}, @tt{b = (1, 2, 0.5)}, giving
@tt{AᵀA = [[2 1] [1 2]]} and @tt{Aᵀb = (1.5, 2.5)}. Variables are
@tt{w = (x₀, x₁, t₀, t₁)}.

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
               0  -1   0  -1))

(define h (scs:vector->float-ptr #(0.0 0.0 0.0 0.0)))]

Only the objective depends on @tt{λ}: @tt{c(λ) = (−Aᵀb, λ, λ)}.

@chunk[<cost>
(define (cost lambda)
  (scs:vector->float-ptr (vector -1.5 -2.5 lambda lambda)))]

@subsection{Sweeping the path}

We solve the first @tt{λ} cold, then for each subsequent @tt{λ} call
@racket[scs-update] with the new @tt{c} and re-solve warm started. The result
is a list of @tt{(λ flag x)} rows.

@chunk[<run>
(define (run-example [lambdas '(0.1 0.3)])
  (define c0 (cost (car lambdas)))
  (define data (retain! (make-scs-data 4 4 G P h c0) G P h c0))
  (define cone (make-cone #:positive 4))
  (define stgs (make-settings #:eps-abs 1e-9 #:eps-rel 1e-9))
  (define work (scs-init data cone stgs))
  (define sx (malloc 'atomic-interior _scs-float 4))
  (define sy (malloc 'atomic-interior _scs-float 4))
  (define ss (malloc 'atomic-interior _scs-float 4))
  (define sol (retain! (make-scs-solution sx sy ss) sx sy ss))
  (define info (make-info))
  (for/list ([lambda (in-list lambdas)]
             [step (in-naturals)])
    (define warm
      (cond
        [(zero? step) (scs-solve work sol info 0)]
        [else
         (define c (cost lambda))
         (scs-update work h c)
         (scs-solve work sol info 1)]))
    (define x (scs:float-ptr->vector (scs-solution-x sol) 2))
    (list lambda warm x)))]

@bold{Running it.}

Larger @tt{λ} shrinks @tt{x} toward zero:

@racketblock[
(run-example)
(code:comment "((0.1 1 #(0.1333 1.1333)) (0.3 1 #(0.0667 1.0667)))")
]

@chunk[<*>
  <require>
  <provide>
  <make-info>
  <P>
  <G>
  <cost>
  <run>]
