#lang racket/base

;; raco review does surface-level linting without macro expansion; it would
;; report every re-export below as "provided but not defined".  This is a pure
;; re-export facade.
#|review: ignore|#

;; High-level, racket-style API for SCS, the Splitting Conic Solver.
;;
;;   (require scs)
;;
;; Build a problem with the CSC matrix helpers and `make-cone`, then `solve`:
;;
;;   (define A (scs-matrix 3 2  -1 1   1 0   0 1))
;;   (define result
;;     (solve #:A A
;;            #:b #(-1.0 0.3 -0.5)
;;            #:c #(-1.0 -1.0)
;;            #:cone (make-cone #:zero 1 #:positive 2)))
;;   (scs-result-x result)   ; => #(0.3 -0.7)
;;
;; Lower layers: (require scs/foreign) for the contracted FFI wrappers,
;; (require scs/foreign/raw) for the direct C bindings.

(require "core/matrix.rkt"
         "core/cone.rkt"
         "core/settings.rkt"
         "core/solve.rkt"
         (only-in "foreign/raw/solver.rkt" scs-version))

(provide (all-from-out "core/matrix.rkt")
         (all-from-out "core/cone.rkt")
         (all-from-out "core/settings.rkt")
         (all-from-out "core/solve.rkt")
         scs-version)
