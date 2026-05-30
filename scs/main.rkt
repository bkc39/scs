#lang racket/base

;; Pure re-export facade for the high-level, racket-style SCS API.
;;   (require scs)
;; The matrix builders are re-exported under the `scs:` prefix (scs:matrix,
;; scs:sparse-matrix, ...).  See the "scs" Scribble guide for usage.
;;
;; raco review does surface-level linting without macro expansion; it would
;; report every re-export below as "provided but not defined".
#|review: ignore|#

(require (prefix-in scs: "core/matrix.rkt")
         "core/cone.rkt"
         "core/settings.rkt"
         "core/solve.rkt"
         (only-in "foreign/raw/solver.rkt" scs-version))

(provide (all-from-out "core/matrix.rkt")
         (all-from-out "core/cone.rkt")
         (all-from-out "core/settings.rkt")
         (all-from-out "core/solve.rkt")
         scs-version)
