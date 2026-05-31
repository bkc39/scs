#lang scribble/lp2

@(require (for-label racket/base
                     scs))

@section[#:tag "ex-lp"]{Linear program}

The smallest interesting problem is a @deftech{linear program}: a linear
objective over a polyhedron. We solve

@nested[#:style 'inset]{
  maximize    @tt{x₀ + x₁} @linebreak[]
  subject to  @tt{0 ≤ x₀ ≤ 1}, @tt{0 ≤ x₁ ≤ 1}
}

whose optimum is @tt{x = (1, 1)}. SCS minimizes, so we minimize
@tt{−x₀ − x₁}; the bounds become four positive-orthant inequalities
(upper bounds @tt{x_i ≤ 1} and lower bounds written as @tt{−x_i ≤ 0}).

@chunk[<require>
(require scs)]

Every example exports a @racket[run-example] thunk so the test submodule and
the @racketmodname[scs] documentation can drive it.

@chunk[<provide>
(provide run-example)]

@bold{Standard form.}

SCS solves @tt{Ax + s = b}, @tt{s ∈ K}. With @tt{K} the positive orthant the
slack @tt{s = b − Ax ≥ 0} encodes @tt{Ax ≤ b}. Stacking the four bounds, the
constraint matrix has one row per inequality:

@chunk[<matrix>
  (define A
    (scs:matrix 4 2
                ;; x0  x1
                 1   0     (code:comment "x0 <= 1")
                 0   1     (code:comment "x1 <= 1")
                -1   0     (code:comment "-x0 <= 0, i.e. x0 >= 0")
                 0  -1))   (code:comment "-x1 <= 0, i.e. x1 >= 0")]

The right-hand side carries the bounds, the objective @tt{c = (−1, −1)} asks to
maximize @tt{x₀ + x₁}, and @racket[make-cone] declares all four rows as
positive-orthant inequalities. Tightening @racket[#:eps-abs]/@racket[#:eps-rel]
sharpens the solution for the test's tolerance.

@chunk[<solve>
  (solve #:A A
         #:b #(1.0 1.0 0.0 0.0)
         #:c #(-1.0 -1.0)
         #:cone (make-cone #:positive 4)
         #:settings (make-settings #:eps-abs 1e-9 #:eps-rel 1e-9))]

@bold{Running it.}

@racket[run-example] returns an @racket[scs-result]; @racket[scs-result-x] is
the primal solution:

@racketblock[
(scs-result-status (run-example))   (code:comment "\"solved\"")
(scs-result-x (run-example))        (code:comment "#(1.0 1.0)")
]

The companion harness @filepath{test/01-linear-program.rkt} drives this and
checks the optimum (run with @exec{raco test}).

@chunk[<run-example>
(define (run-example)
  <matrix>
  <solve>)]

@chunk[<*>
  <require>
  <provide>
  <run-example>]
