#lang scribble/lp2

@(require (for-label racket/base
                     scs))

@section[#:tag "ex-exp"]{Exponential cone}

The @deftech{exponential cone} is the closure of
@tt{{(x, y, z) : y·e^(x/y) ≤ z, y > 0}}. It is the building block for problems
with logarithms and exponentials (see @secref["ex-maxent"]). As a minimal
demonstration we solve

@nested[#:style 'inset]{
  minimize    @tt{z} @linebreak[]
  subject to  @tt{(x, y, z) ∈ K_exp}, @tt{x = 1}, @tt{y = 1}
}

With @tt{x = y = 1} the cone forces @tt{z ≥ e¹}, so the optimum is
@tt{z = e ≈ 2.71828}.

@chunk[<require>
(require scs)]

@chunk[<provide>
(provide run-example)]

@bold{Layout.}

As with the SOC example, the equality rows (@tt{x = 1}, @tt{y = 1}) come first
as the @tech{zero cone}, then an @tt{A = −I} block drops the slack
@tt{(x, y, z)} into the exponential cone:

@chunk[<matrix>
  (define A
    (scs:matrix 5 3
                ;; x   y   z
                 1   0   0    (code:comment "x = 1   (zero cone)")
                 0   1   0    (code:comment "y = 1")
                -1   0   0    (code:comment "exp-cone block: s = (x, y, z)")
                 0  -1   0
                 0   0  -1))]

@racket[#:exp-primal] is the @emph{count} of consecutive exponential-cone
triples (one here).

@chunk[<solve>
  (solve #:A A
         #:b #(1.0 1.0 0.0 0.0 0.0)
         #:c #(0.0 0.0 1.0)
         #:cone (make-cone #:zero 2 #:exp-primal 1)
         #:settings (make-settings #:eps-abs 1e-9 #:eps-rel 1e-9))]

@chunk[<run-example>
(define (run-example)
  <matrix>
  <solve>)]

@bold{Running it.}

@racketblock[
(vector-ref (scs-result-x (run-example)) 2)   (code:comment "~ 2.71828 = e")
]

@chunk[<*>
  <require>
  <provide>
  <run-example>]
