#lang scribble/manual

@(require (for-label racket/base
                     scs))

@title[#:tag "start"]{Getting started}

@; ----------------------------------------------------------------------------
@section{Installing}

The package ships a pre-built native SCS library (version 3.2.11, with LAPACK
and both linear-system solvers), so installing the Racket package is all that is
needed:

@verbatim[#:indent 2]{
raco pkg install scs
}

To work from a checkout of the source repository instead:

@verbatim[#:indent 2]{
raco pkg install --copy ./scs
}

The repository also provides a Nix flake that builds the package, runs the test
suite, and drops you into a development shell with Racket, the bindings, and the
upstream Python @tt{scs} (handy for cross-checking results):

@verbatim[#:indent 2]{
nix build      # build + run tests and examples
nix develop    # dev shell
}

Solver workspaces are reclaimed by Racket's garbage collector, so user code
never allocates or frees native memory directly when using the high-level
@racketmodname[scs] API.

@; ----------------------------------------------------------------------------
@section{Your first solve}

A complete program that minimizes a linear objective over a box, then prints
the solution:

@racketblock[
(require scs)

(define result
  (solve #:A (scs:matrix 4 2
                          1 0      (code:comment "x0 <= 1")
                          0 1      (code:comment "x1 <= 1")
                         -1 0      (code:comment "x0 >= 0")
                          0 -1)    (code:comment "x1 >= 0")
         #:b #(1.0 1.0 0.0 0.0)
         #:c #(-1.0 -1.0)          (code:comment "maximize x0 + x1")
         #:cone (make-cone #:positive 4)))

(scs-result-status result)        (code:comment "\"solved\"")
(scs-result-x result)             (code:comment "#(1.0 1.0)")
]

The four ingredients of every problem are the constraint matrix @racket[#:A],
the right-hand side @racket[#:b], the objective @racket[#:c] (plus an optional
quadratic @racket[#:P]), and the cone @racket[#:cone]. @secref["guide"] explains
each in turn; @secref["examples"] walks through complete, runnable programs.

@; ----------------------------------------------------------------------------
@section{Running the examples}

Every worked example in @secref["examples"] lives in the package's
@filepath{scs/examples/} directory as a literate program that
@racket[provide]s a @racket[run-example] thunk, with a companion harness in
@filepath{scs/examples/test/}. From a checkout you can run an example's tests or
its @racketidfont{main}:

@verbatim[#:indent 2]{
raco test scs/examples/test/01-linear-program.rkt
racket scs/examples/test/01-linear-program.rkt
}
