#lang info

;; raco review lints this as a normal module and flags every `info`
;; definition as unused; #lang info has no value-level uses to detect.
#|review: ignore|#

(define collection "scs")
(define version "0.1")
(define deps '("base" "scribble-lib"))
(define build-deps '("racket-doc" "rackunit-lib"))
(define scribblings '(("scribblings/scs.scrbl" (multi-page))))
(define pkg-desc "Racket bindings for SCS, the Splitting Conic Solver")
(define pkg-authors '(bkc))
(define license 'MIT)
(define pkg-tags '("optimization" "convex" "conic-solver" "scs" "math"))
(define pre-install-collection "private/install-scs-native.rkt")
