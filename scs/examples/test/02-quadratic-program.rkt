#lang racket/base

;; Runner + tests for ../02-quadratic-program.rkt (literate lp2 example).

(require scs
         "../02-quadratic-program.rkt")

(module+ main
  (define r (run-example))
  (printf "status: ~a\n" (scs-result-status r))
  (printf "x:      ~a\n" (scs-result-x r))
  (printf "pobj:   ~a\n" (scs-result-pobj r)))

(module+ test
  (require rackunit)
  (define r (run-example))
  (check-true (solved? r))
  (check-= (vector-ref (scs-result-x r) 0) 0.3 1e-6)
  (check-= (vector-ref (scs-result-x r) 1) -0.7 1e-6))
