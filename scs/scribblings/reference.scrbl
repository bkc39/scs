#lang scribble/manual

@(require (for-label (only-in ffi/unsafe cpointer?)
                     racket/base
                     racket/contract
                     scs
                     (except-in scs/foreign scs-version)
                     (submod scs/foreign unsafe)))

@title[#:tag "reference"]{Reference}

@; ============================================================================
@section{High-level API}

@defmodule[scs]

The @racketmodname[scs] module re-exports the matrix builders under the
@racket[scs:] prefix together with the cone, settings, and solve API.

@subsection[#:tag "ref-matrices"]{Matrices and vectors}

@defproc[(scs:matrix [nrow exact-nonnegative-integer?]
                     [ncol exact-nonnegative-integer?]
                     [val real?] ...)
         any/c]{
Builds an @racket[nrow]×@racket[ncol] CSC matrix from a dense, row-major
sequence of @racket[val]s (there must be @racket[(* nrow ncol)] of them). Exact
zeros are dropped from the sparse representation.}

@defproc[(scs:sparse-matrix [nrow exact-nonnegative-integer?]
                            [ncol exact-nonnegative-integer?]
                            [triple (list/c exact-nonnegative-integer?
                                            exact-nonnegative-integer?
                                            real?)] ...)
         any/c]{
Builds an @racket[nrow]×@racket[ncol] CSC matrix from explicit
@racket[(list row col value)] triples. For a quadratic objective @racket[P],
supply only the upper-triangular entries.}

@defproc[(scs:matrix-ref [m any/c]
                         [i exact-nonnegative-integer?]
                         [j exact-nonnegative-integer?])
         real?]{
Returns entry @racket[(i, j)], or @racket[0.0] if it is absent from the sparse
representation.}

@deftogether[(@defproc[(scs:matrix-nnz [m any/c]) exact-nonnegative-integer?]
              @defproc[(scs:matrix-p->vector [m any/c]) (vectorof exact-integer?)]
              @defproc[(scs:matrix-x->vector [m any/c]) (vectorof real?)]
              @defproc[(scs:matrix-i->vector [m any/c]) (vectorof exact-integer?)])]{
Inspect a CSC matrix: its non-zero count and its column-pointer, value, and
row-index arrays.}

@deftogether[(@defproc[(scs:vector->float-ptr [v (or/c (vectorof real?) (listof real?))]) cpointer?]
              @defproc[(scs:float-ptr->vector [ptr cpointer?] [len exact-nonnegative-integer?]) (vectorof real?)])]{
Low-level helpers to copy a Racket sequence into a freshly allocated
@tt{scs_float} array and to read one back. Used when driving the
@racketmodname[scs/foreign] layer directly.}

@subsection[#:tag "ref-cones"]{Cones}

@defproc[(make-cone [#:zero z exact-nonnegative-integer? 0]
                    [#:positive l exact-nonnegative-integer? 0]
                    [#:box-lower box-lower (listof real?) '()]
                    [#:box-upper box-upper (listof real?) '()]
                    [#:soc soc (listof exact-nonnegative-integer?) '()]
                    [#:psd psd (listof exact-nonnegative-integer?) '()]
                    [#:complex-psd complex-psd (listof exact-nonnegative-integer?) '()]
                    [#:exp-primal exp-primal exact-nonnegative-integer? 0]
                    [#:exp-dual exp-dual exact-nonnegative-integer? 0]
                    [#:power power (listof real?) '()])
         scs-cone?]{
Assembles a cone specification. The keywords correspond to the primitive cones
in the order the rows of @racket[A] must follow; see @secref["cones"].
@racket[box-lower] and @racket[box-upper] must have equal length.}

@subsection[#:tag "ref-settings"]{Settings}

@defproc[(make-settings [#:verbose? verbose? boolean? #f]
                        [#:normalize? normalize? boolean? #t]
                        [#:max-iters max-iters (or/c #f exact-positive-integer?) #f]
                        [#:eps-abs eps-abs (or/c #f real?) #f]
                        [#:eps-rel eps-rel (or/c #f real?) #f]
                        [#:eps-infeas eps-infeas (or/c #f real?) #f]
                        [#:time-limit-secs time-limit-secs (or/c #f real?) #f]
                        [#:warm-start? warm-start? boolean? #f])
         scs-settings?]{
Returns a settings value initialized to SCS's defaults, with the supplied
keywords overridden. A @racket[#f] override leaves the SCS default in place. See
the @hyperlink["https://www.cvxgrp.org/scs/api/settings.html"]{settings reference}.

The keywords above cover the most common knobs. SCS's full settings struct has
more fields; the table below lists them and how to reach each one. Fields not
yet exposed by @racket[make-settings] can still be set on the struct directly
through the @racketmodname[scs/foreign] layer, and broadening
@racket[make-settings] to cover them is a planned follow-up.

@tabular[#:style 'boxed
         #:column-properties '(left left left)
         #:row-properties '(bottom-border ())
 (list (list @bold{SCS setting} @bold{meaning} @bold{in @racket[make-settings]?})
       (list @tt{normalize}        "rescale data before solving"                 @elem{@racket[#:normalize?]})
       (list @tt{max_iters}        "iteration cap"                               @elem{@racket[#:max-iters]})
       (list @tt{eps_abs}          "absolute convergence tolerance"              @elem{@racket[#:eps-abs]})
       (list @tt{eps_rel}          "relative convergence tolerance"              @elem{@racket[#:eps-rel]})
       (list @tt{eps_infeas}       "infeasibility tolerance"                     @elem{@racket[#:eps-infeas]})
       (list @tt{time_limit_secs}  "wall-clock limit"                            @elem{@racket[#:time-limit-secs]})
       (list @tt{verbose}          "print an iteration log"                      @elem{@racket[#:verbose?]})
       (list @tt{warm_start}       "start from a supplied iterate"               @elem{@racket[#:warm-start?]})
       (list @tt{scale}            "initial primal/dual scale factor"            "no (struct only)")
       (list @tt{adaptive_scale}   "adapt @tt{scale} during the solve"           "no (struct only)")
       (list @tt{rho_x}            "primal scaling of the @tt{x} variable"       "no (struct only)")
       (list @tt{alpha}            "over-relaxation parameter"                   "no (struct only)")
       (list @tt{acceleration_lookback}  "Anderson-acceleration memory"          "no (struct only)")
       (list @tt{acceleration_interval} "iterations between acceleration steps"  "no (struct only)")
       (list @tt{write_data_filename}   "dump the problem to a file"             "no (struct only)")
       (list @tt{log_csv_filename}      "log per-iteration data to CSV"          "no (struct only)"))]}

@subsection[#:tag "ref-solving"]{Solving}

@defproc[(solve [#:A A any/c]
                [#:b b (or/c (vectorof real?) (listof real?))]
                [#:c c (or/c (vectorof real?) (listof real?))]
                [#:cone cone scs-cone?]
                [#:P P (or/c any/c #f) #f]
                [#:settings settings (or/c scs-settings? #f) #f]
                [#:indirect? indirect? boolean? #f]
                [#:warm-start warm exact-integer? 0])
         scs-result?]{
Solves the cone program described by @racket[A], @racket[b], @racket[c], the
optional quadratic objective @racket[P], and @racket[cone]. With
@racket[#:indirect? #t] the indirect (conjugate-gradient) linear-system solver is
used. The workspace is reclaimed by the garbage collector.}

@defstruct*[scs-result ([exit-flag exact-integer?]
                        [status string?]
                        [status-val exact-integer?]
                        [x (vectorof real?)]
                        [y (vectorof real?)]
                        [s (vectorof real?)]
                        [pobj real?]
                        [dobj real?]
                        [gap real?]
                        [iter exact-integer?]
                        [solve-time real?]
                        [setup-time real?])
            #:transparent]{
The result of a @racket[solve]. @racket[x], @racket[y], and @racket[s] are the
primal, dual, and slack vectors; @racket[status] is the status string and
@racket[status-val]/@racket[exit-flag] the integer exit code (see the
@hyperlink["https://www.cvxgrp.org/scs/api/exit_flags.html"]{exit-flag
reference}).}

@defproc[(solved? [r scs-result?]) boolean?]{
Returns @racket[#t] when @racket[r] solved to tolerance (exit flag @racket[1]).}

@defproc[(scs-version) string?]{
The version string of the underlying SCS C library.}

@; ============================================================================
@section{Contracted FFI layer}

@defmodule[scs/foreign]

@racketmodname[scs/foreign] exposes the SCS cstructs and a contracted view of the
C entry points, for callers building problems by hand or driving warm-started
re-solves. The cstructs (@racket[make-scs-matrix], @racket[make-scs-data],
@racket[make-scs-cone], @racket[make-scs-solution], @racket[new-scs-settings],
@racket[new-scs-info]) and their accessors are re-exported from the raw layer;
@racket[make-cone] and @racket[make-settings] from @racketmodname[scs] build the
cone and settings structs ergonomically.

@deftogether[(@defproc[(scs-init [d scs-data?] [k scs-cone?] [stgs scs-settings?]) cpointer?]
              @defproc[(scs-solve [work cpointer?] [sol scs-solution?] [info scs-info?] [warm exact-integer?]) exact-integer?]
              @defproc[(scs-update [work cpointer?] [b cpointer?] [c cpointer?]) exact-integer?])]{
Initialize a workspace, solve into @racket[sol]/@racket[info] (pass @racket[1]
for @racket[warm] to warm start), and update the workspace's @racket[b]/@racket[c]
for a re-solve. The @racket[/indirect] variants (@racket[scs-init/indirect],
@racket[scs-solve/indirect], @racket[scs-update/indirect]) use @tt{libscsindir}.
The workspace is GC-reclaimed via a finalizer.}

@defproc[(scs-set-default-settings [stgs scs-settings?]) void?]{
Populates @racket[stgs] with the SCS defaults in place.}

@defproc[(retain! [owner any/c] [thing any/c] ...) any/c]{
Records @racket[thing]s in a weak table keyed by @racket[owner] and returns
@racket[owner], keeping FFI backing buffers alive as long as the struct that
points at them. Use it whenever you store a freshly allocated buffer into a
cstruct pointer field.}

@subsection[#:tag "ref-unsafe"]{Deterministic release}

@racket[(require (submod scs/foreign unsafe))] additionally provides
@racket[scs-finish] and @racket[scs-finish/indirect] for callers that need to
release a workspace eagerly rather than waiting for the collector.

@; ============================================================================
@section{Raw FFI layer}

@defmodule[scs/foreign/raw]

@racketmodname[scs/foreign/raw] is the direct, uncontracted binding to the SCS C
API. It provides the @racket[define-scs] / @racket[define-scs-indirect] FFI
definers, the @racket[_scs-int] and @racket[_scs-float] C type aliases, the
cstructs, @racket[retain!], and the solver functions without contracts. Prefer
@racketmodname[scs] or @racketmodname[scs/foreign] unless you are extending the
bindings.
