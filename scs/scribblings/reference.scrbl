#lang scribble/manual

@(require (for-label (only-in ffi/unsafe cpointer? ctype?)
                     racket/base
                     racket/contract
                     scs
                     (except-in scs/foreign scs-version
                                define-scs define-scs-indirect
                                _scs-int _scs-float)
                     (submod scs/foreign unsafe)
                     (only-in scs/foreign/raw
                              define-scs define-scs-indirect
                              _scs-int _scs-float)))

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

@subsection[#:tag "ref-cstructs"]{Cstructs}

The cstructs mirror the SCS C API (@tt{scs.h}, SCS 3.2.11) one-to-one. Each
provides a positional constructor (@racket[make-_]), a predicate, and field
accessors/mutators; the two configuration structs additionally provide a
keyword constructor (@racket[new-_]) that defaults every field to a
type-appropriate zero. Most callers should prefer @racket[make-cone],
@racket[make-settings], and @racket[solve] from @racketmodname[scs] and reach
for these only when driving the C API directly. Pointer fields store raw
addresses, so a value placed in one must be kept alive with @racket[retain!] for
as long as the owning struct is live.

@deftogether[(@defproc[(make-scs-matrix [x (or/c cpointer? #f)]
                                        [i (or/c cpointer? #f)]
                                        [p (or/c cpointer? #f)]
                                        [m exact-integer?]
                                        [n exact-integer?])
                       scs-matrix?]
              @defproc[(scs-matrix? [v any/c]) boolean?])]{
An @tt{ScsMatrix}: an @racket[m]×@racket[n] sparse matrix in CSC form with value
array @racket[x], row-index array @racket[i], and column-pointer array
@racket[p].}

@deftogether[(@defproc[(make-scs-data [m exact-integer?]
                                      [n exact-integer?]
                                      [A scs-matrix?]
                                      [P (or/c scs-matrix? cpointer? #f)]
                                      [b (or/c cpointer? #f)]
                                      [c (or/c cpointer? #f)])
                       scs-data?]
              @defproc[(scs-data? [v any/c]) boolean?])]{
An @tt{ScsData}: the constraint matrix @racket[A] (@racket[m]×@racket[n]), the
optional quadratic-objective matrix @racket[P] (@racket[n]×@racket[n], upper
triangle, or @racket[#f]), and the dense right-hand sides @racket[b] and
@racket[c].}

@deftogether[(@defproc[(make-scs-cone [z exact-integer?]
                                      [l exact-integer?]
                                      [bu (or/c cpointer? #f)]
                                      [bl (or/c cpointer? #f)]
                                      [bsize exact-integer?]
                                      [q (or/c cpointer? #f)]
                                      [qsize exact-integer?]
                                      [s (or/c cpointer? #f)]
                                      [ssize exact-integer?]
                                      [cs (or/c cpointer? #f)]
                                      [cssize exact-integer?]
                                      [ep exact-integer?]
                                      [ed exact-integer?]
                                      [p (or/c cpointer? #f)]
                                      [psize exact-integer?])
                       scs-cone?]
              @defproc[(scs-cone? [v any/c]) boolean?])]{
An @tt{ScsCone}, the low-level form of @racket[make-cone]: the zero cone
@racket[z], positive cone @racket[l], box cone (@racket[bu]/@racket[bl], length
@racket[bsize]), second-order cones @racket[q] (count @racket[qsize]), PSD cones
@racket[s] (count @racket[ssize]), complex-PSD cones @racket[cs] (count
@racket[cssize]), exponential cones @racket[ep]/@racket[ed], and power cones
@racket[p] (count @racket[psize]). See @secref["cones"] for the required row
ordering.}

@deftogether[(@defproc[(make-scs-solution [x (or/c cpointer? #f)]
                                          [y (or/c cpointer? #f)]
                                          [s (or/c cpointer? #f)])
                       scs-solution?]
              @defproc[(scs-solution? [v any/c]) boolean?])]{
An @tt{ScsSolution}: the dense primal (@racket[x]), dual (@racket[y]), and slack
(@racket[s]) arrays that @racket[scs-solve] fills in.}

@deftogether[(@defproc[(new-scs-settings
                        [#:normalize normalize exact-integer? 0]
                        [#:scale scale real? 0.0]
                        [#:adaptive_scale adaptive_scale exact-integer? 0]
                        [#:rho_x rho_x real? 0.0]
                        [#:max_iters max_iters exact-integer? 0]
                        [#:eps_abs eps_abs real? 0.0]
                        [#:eps_rel eps_rel real? 0.0]
                        [#:eps_infeas eps_infeas real? 0.0]
                        [#:alpha alpha real? 0.0]
                        [#:time_limit_secs time_limit_secs real? 0.0]
                        [#:verbose verbose exact-integer? 0]
                        [#:warm_start warm_start exact-integer? 0]
                        [#:acceleration_lookback acceleration_lookback exact-integer? 0]
                        [#:acceleration_interval acceleration_interval exact-integer? 0]
                        [#:write_data_filename write_data_filename (or/c string? #f) #f]
                        [#:log_csv_filename log_csv_filename (or/c string? #f) #f])
                       scs-settings?]
              @defproc[(scs-settings? [v any/c]) boolean?])]{
An @tt{ScsSettings}, the low-level form of @racket[make-settings]. Each keyword
mirrors the correspondingly named @tt{scs.h} field and defaults to a
type-appropriate zero; pass the result through @racket[scs-set-default-settings]
to install SCS's real defaults before overriding individual fields. See the
@hyperlink["https://www.cvxgrp.org/scs/api/settings.html"]{settings reference}.}

@deftogether[(@defproc[(new-scs-info) scs-info?]
              @defproc[(scs-info? [v any/c]) boolean?])]{
An @tt{ScsInfo} result record, normally constructed with no arguments to receive
the outcome of @racket[scs-solve]. Every @tt{scs.h} field (e.g. @tt{iter},
@tt{status}, @tt{status_val}, @tt{pobj}, @tt{dobj}, @tt{gap}, @tt{solve_time},
@tt{setup_time}) is also available as an optional keyword defaulting to a
type-appropriate zero, and as a field accessor.}

@subsection[#:tag "ref-entry-points"]{C entry points}

@deftogether[(@defproc[(scs-init [d scs-data?] [k scs-cone?] [stgs scs-settings?]) cpointer?]
              @defproc[(scs-solve [work cpointer?] [sol scs-solution?] [info scs-info?] [warm exact-integer?]) exact-integer?]
              @defproc[(scs-update [work cpointer?] [b cpointer?] [c cpointer?]) exact-integer?])]{
Initialize a workspace, solve into @racket[sol]/@racket[info] (pass @racket[1]
for @racket[warm] to warm start), and update the workspace's @racket[b]/@racket[c]
for a re-solve. The @racket[/indirect] variants (@racket[scs-init/indirect],
@racket[scs-solve/indirect], @racket[scs-update/indirect]) use @tt{libscsindir}.
The workspace is GC-reclaimed via a finalizer.}

@deftogether[(@defproc[(scs-init/indirect [d scs-data?] [k scs-cone?] [stgs scs-settings?]) cpointer?]
              @defproc[(scs-solve/indirect [work cpointer?] [sol scs-solution?] [info scs-info?] [warm exact-integer?]) exact-integer?]
              @defproc[(scs-update/indirect [work cpointer?] [b cpointer?] [c cpointer?]) exact-integer?])]{
The indirect/conjugate-gradient counterparts of @racket[scs-init],
@racket[scs-solve], and @racket[scs-update], bound against @tt{libscsindir}.}

@defproc[(scs-set-default-settings [stgs scs-settings?]) void?]{
Populates @racket[stgs] with the SCS defaults in place.}

@defproc[(retain! [owner any/c] [thing any/c] ...) any/c]{
Records @racket[thing]s in a weak table keyed by @racket[owner] and returns
@racket[owner], keeping FFI backing buffers alive as long as the struct that
points at them. Use it whenever you store a freshly allocated buffer into a
cstruct pointer field.}

@subsection[#:tag "ref-unsafe"]{Deterministic release}

@defmodule[(submod scs/foreign unsafe)]

@racket[(require (submod scs/foreign unsafe))] additionally provides
@racket[scs-finish] and @racket[scs-finish/indirect] for callers that need to
release a workspace eagerly rather than waiting for the collector.

@deftogether[(@defproc[(scs-finish [work cpointer?]) void?]
              @defproc[(scs-finish/indirect [work cpointer?]) void?])]{
Free the SCS workspace @racket[work] returned by @racket[scs-init] (resp.
@racket[scs-init/indirect]). A workspace is also finalized automatically when it
becomes unreachable, so calling these is only necessary to release the native
memory at a deterministic point.}

@; ============================================================================
@section{Raw FFI layer}

@defmodule[scs/foreign/raw]

@racketmodname[scs/foreign/raw] is the direct, uncontracted binding to the SCS C
API. It provides the @racket[define-scs] / @racket[define-scs-indirect] FFI
definers, the @racket[_scs-int] and @racket[_scs-float] C type aliases, the
cstructs, @racket[retain!], and the solver functions without contracts. Prefer
@racketmodname[scs] or @racketmodname[scs/foreign] unless you are extending the
bindings.

@deftogether[(@defform[(define-scs id type-expr option ...)]
              @defform[(define-scs-indirect id type-expr option ...)])]{
Bind @racket[id] to the SCS C function of the same name (hyphens mapped to
underscores) with the @tt{_fun} type @racket[type-expr], against @tt{libscsdir}
and @tt{libscsindir} respectively. These are @tt{define-ffi-definer} instances,
so each @racket[option] is a definer keyword clause such as @tt{#:wrap} or
@tt{#:c-id}.}

@deftogether[(@defthing[_scs-int ctype?]
              @defthing[_scs-float ctype?])]{
The C type aliases for SCS's @tt{scs_int} and @tt{scs_float}. In the nixpkgs
build these are @tt{_int} (32-bit) and @tt{_double}; aliasing them keeps a
future @tt{DLONG}/@tt{SFLOAT} build a one-line change.}
