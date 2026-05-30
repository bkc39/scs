#lang info

;; raco review lints this as a normal module and flags every `info`
;; definition as unused; #lang info has no value-level uses to detect.
#|review: ignore|#

(define collection "scs")
(define version "0.1")
(define deps '("base"))
(define build-deps '("scribble-lib" "racket-doc" "rackunit-lib"))
(define scribblings '(("scribblings/scs.scrbl" ())))
(define pkg-desc "Racket bindings for SCS, the Splitting Conic Solver")
(define pkg-authors '(bkc))
(define license '(Apache-2.0 OR MIT))
(define pkg-tags '("optimization" "convex" "conic-solver" "scs" "math"))
(define pre-install-collection "private/install-scs-native.rkt")
