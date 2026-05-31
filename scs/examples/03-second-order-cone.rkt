#lang scribble/lp2

@(require (for-label racket/base
                     scs))

@section[#:tag "ex-soc"]{Second-order cone}

The @deftech{second-order} (Lorentz) cone @tt{{(t, u) : ‖u‖₂ ≤ t}} lets us
minimize a Euclidean norm. We solve

@nested[#:style 'inset]{
  minimize    @tt{t} @linebreak[]
  subject to  @tt{‖(u, v)‖₂ ≤ t}, @tt{u = 3}, @tt{v = 4}
}

over @tt{x = (t, u, v)}. With @tt{u} and @tt{v} pinned, the cone forces
@tt{t ≥ √(3² + 4²) = 5}, so the optimum is @tt{(t, u, v) = (5, 3, 4)}.

@chunk[<require>
(require scs)]

@chunk[<provide>
(provide run-example)]

@subsection{Encoding cone membership}

A slack lands in a cone when @tt{s = b − Ax}. To put @tt{(t, u, v)} itself into
the SOC block we use @tt{A = −I} with @tt{b = 0} on those rows, so
@tt{s = (t, u, v)}. The two equality rows (@tt{u = 3}, @tt{v = 4}) come first,
as the @tech{zero cone}; then the three-row SOC block:

@chunk[<matrix>
  (define A
    (scs:matrix 5 3
                ;; t   u   v
                 0   1   0    (code:comment "u = 3   (zero cone)")
                 0   0   1    (code:comment "v = 4")
                -1   0   0    (code:comment "SOC block: s = (t, u, v)")
                 0  -1   0
                 0   0  -1))]

@racket[#:soc] takes a list of block sizes; here a single block of size 3. The
first entry of each block is the cone's scale @tt{t}, the rest are @tt{u}.

@chunk[<solve>
  (solve #:A A
         #:b #(3.0 4.0 0.0 0.0 0.0)
         #:c #(1.0 0.0 0.0)
         #:cone (make-cone #:zero 2 #:soc '(3))
         #:settings (make-settings #:eps-abs 1e-9 #:eps-rel 1e-9))]

@chunk[<run-example>
(define (run-example)
  <matrix>
  <solve>)]

@bold{Running it.}

@racketblock[
(scs-result-x (run-example))   (code:comment "#(5.0 3.0 4.0)")
]

@chunk[<*>
  <require>
  <provide>
  <run-example>]
