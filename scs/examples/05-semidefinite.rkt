#lang scribble/lp2

@(require (for-label racket/base
                     scs))

@section[#:tag "ex-sdp"]{Semidefinite program}

A @deftech{semidefinite program} optimizes over positive semidefinite (PSD)
matrices. (This requires the LAPACK-enabled SCS build, which this package
ships.) Over symmetric 2×2 matrices @tt{X = [[a b] [b c]]} we solve

@nested[#:style 'inset]{
  minimize    @tt{trace(X) = a + c} @linebreak[]
  subject to  @tt{X ⪰ 0}, @tt{b = 1}
}

@tt{X ⪰ 0} with @tt{b = 1} forces @tt{ac ≥ 1}, so @tt{a + c ≥ 2} with equality
at @tt{a = c = 1}. The optimum is @tt{(a, b, c) = (1, 1, 1)}.

@chunk[<require>
(require scs)]

@chunk[<provide>
(provide run-example)]

@subsection{The svec scaling}

SCS represents a @tt{k}×@tt{k} symmetric matrix by the lower triangle stacked
column-wise, with the off-diagonal entries scaled by @tt{√2} (so that the
standard inner product is preserved). For our 2×2 matrix that vector is
@tt{svec(X) = (a, √2·b, c)}. To make the cone slack equal @tt{svec(X)} we put
@tt{−diag(1, √2, 1)} on the PSD block:

@chunk[<matrix>
  (define root2 (sqrt 2.0))
  (define A
    (scs:matrix 4 3
                ;; a       b   c
                 0         1   0    (code:comment "b = 1   (zero cone)")
                -1         0   0    (code:comment "svec = (a, root2 b, c)")
                 0  (- root2)  0
                 0         0  -1))]

@racket[#:psd] takes the list of matrix dimensions @tt{k} (here @tt{'(2)}); the
block length is @tt{k(k+1)/2}.

@chunk[<solve>
  (solve #:A A
         #:b #(1.0 0.0 0.0 0.0)
         #:c #(1.0 0.0 1.0)
         #:cone (make-cone #:zero 1 #:psd '(2))
         #:settings (make-settings #:eps-abs 1e-9 #:eps-rel 1e-9))]

@chunk[<run-example>
(define (run-example)
  <matrix>
  <solve>)]

@bold{Running it.}

@racketblock[
(scs-result-x (run-example))   (code:comment "#(1.0 1.0 1.0) = (a, b, c)")
]

@chunk[<*>
  <require>
  <provide>
  <run-example>]
