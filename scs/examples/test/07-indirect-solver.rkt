#lang racket/base

;; Runner + tests for ../07-indirect-solver.rkt (literate lp2 example).

(require scs
         "../07-indirect-solver.rkt")

(module+ main
  (define r (run-example))
  (printf "status: ~a\n" (scs-result-status r))
  (printf "x:      ~a\n" (scs-result-x r)))

(module+ test
  (require rackunit)
  (define r (run-example))
  (check-true (solved? r))
  (check-= (vector-ref (scs-result-x r) 0) 0.3 1e-6)
  (check-= (vector-ref (scs-result-x r) 1) -0.7 1e-6))
