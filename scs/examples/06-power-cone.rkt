#lang scribble/lp2

@(require (for-label racket/base
                     scs))

@section[#:tag "ex-power"]{Power cone}

The @deftech{power cone} @tt{K_pow(a) = {(x, y, z) : x^a · y^(1−a) ≥ |z|,
x ≥ 0, y ≥ 0}} with parameter @tt{a ∈ [0, 1]} captures weighted geometric
means. As a small demonstration we maximize the geometric mean coordinate:

@nested[#:style 'inset]{
  maximize    @tt{z} @linebreak[]
  subject to  @tt{(x, y, z) ∈ K_pow(½)}, @tt{x = 2}, @tt{y = 8}
}

With @tt{a = ½} the cone reads @tt{√(x·y) ≥ |z|}, so @tt{z ≤ √(2·8) = 4}; the
optimum is @tt{z = 4}.

@chunk[<require>
(require scs)]

@chunk[<provide>
(provide run-example)]

@bold{Layout.}

Pin @tt{x} and @tt{y} with two @tech{zero cone} rows, then drop the slack
@tt{(x, y, z)} into the power cone with an @tt{A = −I} block. SCS minimizes, so
maximizing @tt{z} means @tt{c = (0, 0, −1)}.

@chunk[<matrix>
  (define A
    (scs:matrix 5 3
                ;; x   y   z
                 1   0   0    (code:comment "x = 2   (zero cone)")
                 0   1   0    (code:comment "y = 8")
                -1   0   0    (code:comment "power-cone block: s = (x, y, z)")
                 0  -1   0
                 0   0  -1))]

@racket[#:power] takes a list of parameters in @tt{[−1, 1]}; a positive value
@tt{a} selects @tt{K_pow(a)} and a negative value selects the dual power cone.

@chunk[<solve>
  (solve #:A A
         #:b #(2.0 8.0 0.0 0.0 0.0)
         #:c #(0.0 0.0 -1.0)
         #:cone (make-cone #:zero 2 #:power '(0.5))
         #:settings (make-settings #:eps-abs 1e-9 #:eps-rel 1e-9))]

@chunk[<run-example>
(define (run-example)
  <matrix>
  <solve>)]

@bold{Running it.}

@racketblock[
(vector-ref (scs-result-x (run-example)) 2)   (code:comment "~ 4.0 = sqrt(2*8)")
]

@chunk[<*>
  <require>
  <provide>
  <run-example>]
