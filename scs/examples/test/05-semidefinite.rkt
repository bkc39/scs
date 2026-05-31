#lang racket/base

;; Runner + tests for ../05-semidefinite.rkt (literate lp2 example).

(require scs
         "../05-semidefinite.rkt")

(module+ main
  (define r (run-example))
  (printf "status: ~a\n" (scs-result-status r))
  (printf "x (a b c): ~a\n" (scs-result-x r)))

(module+ test
  (require rackunit)
  (define r (run-example))
  (check-true (solved? r))
  (define x (scs-result-x r))
  (check-= (vector-ref x 0) 1.0 1e-4)
  (check-= (vector-ref x 1) 1.0 1e-4)
  (check-= (vector-ref x 2) 1.0 1e-4))
