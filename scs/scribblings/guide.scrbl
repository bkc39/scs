#lang scribble/manual

@(require (for-label racket/base
                     scs))

@title[#:tag "guide"]{Guide}

@; ----------------------------------------------------------------------------
@section{The problem SCS solves}

SCS solves the convex quadratic cone program

@nested[#:style 'inset]{
  minimize    @racket[(/ 1 2)] xᵀ@bold{P}x + @bold{c}ᵀx @linebreak[]
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
 @item{@bold{zero} cone --- @racket[#:zero] equality rows (@tt{s} = 0).}
 @item{@bold{positive} orthant --- @racket[#:positive] inequality rows
       (@tt{s} ≥ 0).}
 @item{@bold{box} cone --- @racket[#:box-lower] / @racket[#:box-upper];
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

The box cone is @tt{{(t, r) : t·l ≤ r ≤ t·u}} with a leading scale variable
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

@racket[scs:sparse-matrix] builds one from explicit @tt{(row col value)} triples,
which is convenient for a quadratic @tt{P} (supply only the upper triangle):

@racketblock[
(scs:sparse-matrix 2 2
                   '(0 0 3)
                   '(0 1 -1)
                   '(1 1 2))
]

Both return a CSC matrix suitable for @racket[#:A] or @racket[#:P]. The
right-hand side @tt{b} and objective @tt{c} are passed to @racket[solve] as
plain vectors or lists.

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

@subsection{Warm starting and re-solving}

When a sequence of problems differs only in @tt{b} or @tt{c}, you can keep one
solver workspace and update it instead of rebuilding from scratch. This is done
through the @racketmodname[scs/foreign] layer with
@racket[scs-init], @racket[scs-update], and @racket[scs-solve] (passing a warm
flag of @racket[1] to the re-solve). @secref["ex-lasso"] and @secref["ex-mpc"]
show the pattern.
