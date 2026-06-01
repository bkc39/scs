#lang scribble/manual

@(require (for-label racket/base
                     scs))

@title[#:tag "guide"]{Guide}

@; ----------------------------------------------------------------------------
@section{The problem SCS solves}

SCS solves the convex quadratic cone program

@nested[#:style 'inset]{
  minimize    ½ xᵀ@bold{P}x + @bold{c}ᵀx @linebreak[]
  subject to  @bold{A}x + s = @bold{b}, @bold{s} ∈ @bold{K}
}

over the variable @tt{x} ∈ ℝⁿ and slack @tt{s} ∈ ℝᵐ, where @tt{P} is symmetric
positive semidefinite, @tt{A} is @tt{m}×@tt{n}, and @tt{K} is a closed convex
cone. SCS simultaneously produces a solution to the dual problem; the dual
variable is returned as @racket[scs-result-y]. See the upstream
@hyperlink["https://www.cvxgrp.org/scs/algorithm/index.html"]{algorithm notes}
for the precise primal/dual pair.

In Racket you supply @tt{A} and the optional @tt{P} as compressed-sparse-column
matrices (@racket[scs:matrix] / @racket[scs:sparse-matrix]), @tt{b} and @tt{c}
as vectors or lists, and @tt{K} as a @racket[make-cone] value, then call
@racket[solve].

@; ----------------------------------------------------------------------------
@section[#:tag "cones"]{Cones}

The cone @tt{K} is a Cartesian product of primitive cones. The rows of @tt{A}
(and the entries of @tt{b} and @tt{s}) @emph{must appear in this exact order},
which is also the order of the @racket[make-cone] keywords:

@itemlist[
 @item{the @deftech{zero cone} --- @racket[#:zero] equality rows (@tt{s} = 0).}
 @item{the @deftech{positive orthant} --- @racket[#:positive] inequality rows
       (@tt{s} ≥ 0).}
 @item{the @tech{box cone} --- @racket[#:box-lower] / @racket[#:box-upper];
       see @secref["box-cones"].}
 @item{@bold{second-order} (Lorentz) cones --- @racket[#:soc], a list of block
       sizes; each block @tt{(t, u)} satisfies ‖u‖₂ ≤ t.}
 @item{@bold{positive semidefinite} cones --- @racket[#:psd], a list of matrix
       dimensions; see @secref["psd-cones"].}
 @item{@bold{exponential} cones --- @racket[#:exp-primal] / @racket[#:exp-dual]
       counts of triples; the primal cone is the closure of
       @tt{{(x,y,z) : y·e^(x/y) ≤ z, y > 0}}.}
 @item{@bold{power} cones --- @racket[#:power], a list of parameters in
       @tt{[-1, 1]} (negative values select the dual power cone).}
]

This mirrors the cone ordering documented in the SCS
@hyperlink["https://www.cvxgrp.org/scs/api/cones.html"]{cones reference}.

@subsection[#:tag "box-cones"]{Box cones}

The @deftech{box cone} is @tt{{(t, r) : t·l ≤ r ≤ t·u}} with a leading scale variable
@tt{t}. To impose plain bounds @tt{l ≤ y ≤ u}, arrange @tt{A} and @tt{b} so the
first box row's slack is a constant @tt{1} (a row of zeros in @tt{A} with the
matching @tt{b} entry equal to @racket[1]) and the remaining rows carry @tt{y}.
@racket[make-cone] takes the bounds with @racket[#:box-lower] and
@racket[#:box-upper]; their length is the number of box-constrained entries, and
SCS's @tt{bsize} is that length plus one. @secref["ex-mpc"] is a worked example.

@subsection[#:tag "psd-cones"]{Semidefinite cones}

For a @tt{k}×@tt{k} symmetric matrix, the PSD cone slack is the lower triangle
stacked column-wise with the off-diagonal entries scaled by @tt{√2}; the block
length is @tt{k(k+1)/2}. So a 2×2 matrix @tt{[[a b] [b c]]} is represented by
@tt{(a, √2·b, c)}. @racket[#:psd] takes the list of @tt{k} values. See the
@hyperlink["https://www.cvxgrp.org/scs/api/cones.html"]{cones reference} and
@secref["ex-sdp"].

@; ----------------------------------------------------------------------------
@section{Building matrices and vectors}

@racket[scs:matrix] builds a matrix from a dense, row-major sequence of values:

@racketblock[
(scs:matrix 3 2     (code:comment "3 rows, 2 columns")
            -1 1
             1 0
             0 1)
]

It also accepts a single list of rows, inferring the dimensions, which reads
like a 2D literal:

@racketblock[
(scs:matrix '((-1 1)
              ( 1 0)
              ( 0 1)))
]

@racket[scs:sparse-matrix] builds one from explicit @tt{(row col value)} triples,
which is convenient for a quadratic @tt{P} (supply only the upper triangle):

@racketblock[
(scs:sparse-matrix 2 2
                   '(0 0 3)
                   '(0 1 -1)
                   '(1 1 2))
]

For data already in a @tt{scipy}-style coordinate form, @racket[scs:coo-matrix]
takes three parallel sequences @tt{(rows cols vals)} (vectors or lists), matching
@tt{scipy.sparse.coo_matrix((data, (row, col)))}:

@racketblock[
(scs:coo-matrix 2 2 '(0 0 1) '(0 1 1) '(3 -1 2))
]

All three return a CSC matrix suitable for @racket[#:A] or @racket[#:P]. The
right-hand side @tt{b} and objective @tt{c} are passed to @racket[solve] as
plain vectors @emph{or} lists.

@; ----------------------------------------------------------------------------
@section[#:tag "cookbook"]{Modeling cookbook}

Getting a problem into SCS's standard form @tt{Ax + s = b}, @tt{s ∈ K} comes
down to a handful of recurring moves. Each is used by one or more of the worked
@secref["examples"].

@subsection{Laying out @tt{A} in cone-ordered row-blocks}

The rows of @tt{A} (and the entries of @tt{b} and @tt{s}) must appear in the
@secref["cones"] order: zero rows, then positive, box, second-order,
semidefinite, exponential, and power. Build @tt{A} as a @emph{stack of
row-blocks}, one per primitive cone, in that order, and make @racket[make-cone]'s
keywords describe the same blocks. A slack lands in a given cone exactly when
@tt{s = b − Ax} restricted to that block satisfies the membership condition; a
common idiom is an @tt{A = −I} block with @tt{b = 0}, which sets
@tt{s = x} on those rows so the variables themselves are constrained
(@secref["ex-soc"], @secref["ex-exp"], @secref["ex-power"]).

@subsection{Bounds and the @tech{absolute-value trick}}

A two-sided bound @tt{l ≤ aᵀx ≤ u} is two positive-orthant rows, @tt{aᵀx ≤ u}
and @tt{−aᵀx ≤ −l}. The @deftech{absolute-value trick} models @tt{|aᵀx|}:
introduce an auxiliary @tt{t}, add the two rows @tt{aᵀx − t ≤ 0} and
@tt{−aᵀx − t ≤ 0} (so @tt{t ≥ |aᵀx|}), and use @tt{t} in the objective. This is
how L1 penalties become cone programs in @secref["ex-lasso"] and
@secref["ex-elastic-net"].

@subsection{Norms via the second-order cone}

A Euclidean-norm bound @tt{‖u‖₂ ≤ t} is one second-order cone block over
@tt{(t, u)} (@secref["ex-soc"]). To @emph{minimize} a norm, bound it by a fresh
variable @tt{t} with @tt{‖u‖₂ ≤ t} and minimize @tt{t}.

@subsection{The @tech{epigraph trick} for nonlinear objectives}

To minimize a convex function @tt{f(x)} that is not already linear or quadratic,
minimize a new variable @tt{t} subject to the @deftech{epigraph trick}
constraint @tt{f(x) ≤ t}, then express that constraint with a cone. For
@tt{x log x} the epigraph is exponential-cone membership, which is how
@secref["ex-maxent"] maximizes entropy.

@subsection{Box-cone layout}

The @tech{box cone} carries a leading scale variable. To impose plain bounds
@tt{l ≤ y ≤ u}, pin that scale to @racket[1] with a constant row (zeros in
@tt{A}, a @racket[1] in @tt{b}) and put @tt{y} on the remaining rows; see
@secref["box-cones"] and the worked @secref["ex-mpc"].

@subsection{Symmetric matrices and the svec scaling}

A semidefinite constraint @tt{X ⪰ 0} is one @racket[#:psd] block whose slack is
the @tt{√2}-scaled lower-triangular vectorization of @tt{X}; see
@secref["psd-cones"] and @secref["ex-sdp"].

@; ----------------------------------------------------------------------------
@section[#:tag "guide-settings"]{Settings}

@racket[make-settings] produces a settings value populated with SCS's defaults,
overridden by the keywords you pass. Unlike the C library, @racket[verbose?]
defaults to @racket[#f] (libraries should be quiet). The most common knobs are
the convergence tolerances @racket[#:eps-abs] and @racket[#:eps-rel] (SCS
default @racket[1e-4]) and @racket[#:max-iters]. See the upstream
@hyperlink["https://www.cvxgrp.org/scs/api/settings.html"]{settings reference}
for the full list and defaults. Passing no @racket[#:settings] to @racket[solve]
uses the defaults.

@; ----------------------------------------------------------------------------
@section{Solving and reading results}

@racket[solve] returns an @racket[scs-result]. Check @racket[solved?] (true when
the exit flag is @racket[1], @tt{SCS_SOLVED}); @racket[scs-result-status] is the
human-readable status string and @racket[scs-result-status-val] the integer exit
flag. The exit flags follow the SCS
@hyperlink["https://www.cvxgrp.org/scs/api/exit_flags.html"]{exit-flag reference}:
@racket[1] solved, @racket[2] solved-inaccurate, @racket[-1] unbounded,
@racket[-2] infeasible, and @racket[-3] through @racket[-7] for the
indeterminate/failed/interrupted and inaccurate-certificate cases.

The primal solution is @racket[scs-result-x], the dual is @racket[scs-result-y],
and the slack is @racket[scs-result-s]; @racket[scs-result-pobj] and
@racket[scs-result-dobj] are the primal and dual objectives.

@subsection{Direct vs. indirect solver}

By default @racket[solve] uses the direct linear-system solver. Pass
@racket[#:indirect? #t] to use the indirect (conjugate-gradient) solver, which
can scale better on very large sparse problems.

@subsection[#:tag "warm-starting"]{Warm starting and re-solving}

When a sequence of problems differs only in @tt{b} or @tt{c}, build a solver
once with @racket[make-solver] and re-solve it instead of rebuilding from
scratch. @racket[solver-solve!] returns an @racket[scs-result]; it cold-starts
the first time and warm-starts (reusing the previous iterate) on every call
after that. @racket[solver-update!] swaps in a new @tt{b} and/or @tt{c} (the
matrices and cone are fixed):

@racketblock[
(define s (make-solver #:A A #:b b #:c c #:cone cone))
(solver-solve! s)              (code:comment "cold start")
(solver-update! s #:b b2)      (code:comment "only b changes")
(solver-solve! s)              (code:comment "warm-started re-solve")
]

@racket[solve] is just @racket[make-solver] followed by a single
@racket[solver-solve!]. @secref["ex-warm-start"], @secref["ex-lasso"], and
@secref["ex-mpc"] show the pattern. For full manual control over the workspace
and solution buffers, the @racketmodname[scs/foreign] layer exposes the
underlying @racket[scs-init] / @racket[scs-update] / @racket[scs-solve].

@subsection[#:tag "troubleshooting"]{Troubleshooting and status}

When @racket[solved?] is false, the exit flag says why, and the result still
carries useful information:

@itemlist[
 @item{@bold{Infeasible} (flag @racket[-2]): no @tt{x} satisfies the
       constraints. SCS returns a @emph{certificate of infeasibility} in
       @racket[scs-result-y] (a dual ray); @racket[scs-result-x] is not
       meaningful.}
 @item{@bold{Unbounded} (flag @racket[-1]): the objective can be driven to
       @tt{−∞} within the constraints. The certificate is a primal ray in
       @racket[scs-result-x].}
 @item{@bold{Inaccurate} (flags @racket[2], @racket[-6], @racket[-7]): SCS hit
       its iteration or time limit with the residuals only partially converged.
       The iterate is usually close; loosen @racket[#:eps-abs] /
       @racket[#:eps-rel] to accept it, or raise @racket[#:max-iters] /
       @racket[#:time-limit-secs] to push further.}
 @item{@bold{Indeterminate / failed} (flags @racket[-3] through @racket[-5]):
       the problem could not be classified, or setup failed.}
]

A few common modeling mistakes produce a spurious infeasible or unbounded
result rather than an error:

@itemlist[
 @item{@bold{Cone-order mismatch.} The rows of @tt{A} must follow the
       @secref["cones"] order and match @racket[make-cone]'s keyword counts
       exactly. A miscounted block silently re-interprets later rows.}
 @item{@bold{A missing box scale row.} The @tech{box cone} needs its leading
       scale entry pinned (see @secref["box-cones"]); omitting it changes the
       feasible set.}
 @item{@bold{Wrong PSD scaling.} Off-diagonal entries of a semidefinite block
       must be @tt{√2}-scaled (see @secref["psd-cones"]).}
]

To see SCS's own iteration log while diagnosing, pass
@racket[(make-settings #:verbose? #t)].
