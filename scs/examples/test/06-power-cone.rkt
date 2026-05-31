#lang racket/base

;; Runner + tests for ../06-power-cone.rkt (literate lp2 example).

(require scs
         "../06-power-cone.rkt")

(module+ main
  (define r (run-example))
  (printf "status: ~a\n" (scs-result-status r))
  (printf "x (x y z): ~a\n" (scs-result-x r)))

(module+ test
  (require rackunit)
  (define r (run-example))
  (check-true (solved? r))
  (define x (scs-result-x r))
  (check-= (vector-ref x 0) 2.0 1e-5)
  (check-= (vector-ref x 1) 8.0 1e-5)
  ;; z = sqrt(x*y) = sqrt(16) = 4
  (check-= (vector-ref x 2) 4.0 1e-4))
