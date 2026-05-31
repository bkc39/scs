#lang racket/base

;; Runner + tests for ../04-exponential-cone.rkt (literate lp2 example).

(require scs
         "../04-exponential-cone.rkt")

(module+ main
  (define r (run-example))
  (printf "status: ~a\n" (scs-result-status r))
  (printf "x (x y z): ~a\n" (scs-result-x r))
  (printf "z vs e:    ~a vs ~a\n" (vector-ref (scs-result-x r) 2) (exp 1)))

(module+ test
  (require rackunit)
  (define r (run-example))
  (check-true (solved? r))
  (check-= (vector-ref (scs-result-x r) 2) (exp 1) 1e-4))
