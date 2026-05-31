#lang scribble/manual

@(require (for-label racket/base
                     scs))

@title{SCS: the Splitting Conic Solver}
@author{bkc}

This package provides Racket bindings for
@hyperlink["https://www.cvxgrp.org/scs/"]{SCS}, the Splitting Conic Solver. SCS
solves large-scale convex cone programs --- linear, quadratic, second-order,
semidefinite, exponential, and power cone problems --- using a first-order
operator-splitting method.

The default API is high level and accepts ordinary Racket data:

@racketblock[
(require scs)

(define result
  (solve #:A (scs:matrix 3 2  -1 1   1 0   0 1)
         #:b #(-1.0 0.3 -0.5)
         #:c #(-1.0 -1.0)
         #:cone (make-cone #:zero 1 #:positive 2)))

(scs-result-status result)   (code:comment "\"solved\"")
(scs-result-x result)        (code:comment "#(0.3 -0.7)")
]

The library is layered. Use @racketmodname[scs] (this module) for everyday work.
@racketmodname[scs/foreign] is the contracted low-level wrapper layer, and
@racketmodname[scs/foreign/raw] is the direct C FFI binding to the SCS C API.
Solver workspaces are reclaimed by Racket's garbage collector, so user code
never frees anything.

The native library is the upstream @tt{scs} build (3.2.11), compiled with LAPACK
so semidefinite cones are available, and shipping both the direct
(@tt{libscsdir}) and indirect/CG (@tt{libscsindir}) linear-system solvers.

@include-section["start.scrbl"]
@include-section["guide.scrbl"]
@include-section["examples.scrbl"]
@include-section["reference.scrbl"]
