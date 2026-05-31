#lang scribble/lp2

@(require (for-label racket/base
                     scs))

@section[#:tag "ex-indirect"]{Indirect solver}

SCS can solve the linear system at the heart of each iteration two ways: a
@deftech{direct} method that factorizes once and back-solves (the default), and
an @deftech{indirect} method that uses conjugate gradients and never forms a
factorization. The indirect solver scales better to very large, sparse problems
where a factorization would be expensive or memory-hungry.

Switching is a one-keyword change: pass @racket[#:indirect? #t] to
@racket[solve]. Here we re-solve the quadratic program of @secref["ex-qp"] with
the indirect solver; the answer is identical, @tt{x = (0.3, −0.7)}.

@chunk[<require>
(require scs)]

@chunk[<provide>
(provide run-example)]

@chunk[<problem>
  (define A
    (scs:matrix 3 2
                -1   1
                 1   0
                 0   1))
  (define P
    (scs:sparse-matrix 2 2
                       '(0 0 3)
                       '(0 1 -1)
                       '(1 1 2)))]

@subsection{Choosing the indirect solver}

@chunk[<solve>
  (solve #:A A
         #:b #(-1.0 0.3 -0.5)
         #:c #(-1.0 -1.0)
         #:P P
         #:cone (make-cone #:zero 1 #:positive 2)
         #:settings (make-settings #:eps-abs 1e-9 #:eps-rel 1e-9)
         #:indirect? #t)]

@chunk[<run-example>
(define (run-example)
  <problem>
  <solve>)]

@bold{Running it.}

@racketblock[
(scs-result-x (run-example))   (code:comment "#(0.3 -0.7), same as the direct solver")
]

@chunk[<*>
  <require>
  <provide>
  <run-example>]
