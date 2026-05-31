#lang racket/base

;; Runner + tests for ../03-second-order-cone.rkt (literate lp2 example).

(require scs
         "../03-second-order-cone.rkt")

(module+ main
  (define r (run-example))
  (printf "status: ~a\n" (scs-result-status r))
  (printf "x (t u v): ~a\n" (scs-result-x r)))

(module+ test
  (require rackunit)
  (define r (run-example))
  (check-true (solved? r))
  (define x (scs-result-x r))
  (check-= (vector-ref x 0) 5.0 1e-5)
  (check-= (vector-ref x 1) 3.0 1e-5)
  (check-= (vector-ref x 2) 4.0 1e-5))
