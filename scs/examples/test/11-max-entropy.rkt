#lang racket/base

;; Runner + tests for ../11-max-entropy.rkt (literate lp2 example).

(require scs
         "../11-max-entropy.rkt")

(module+ main
  (define r (run-example))
  (printf "status:  ~a\n" (scs-result-status r))
  (printf "x:       ~a\n" (scs-result-x r))
  (printf "entropy: ~a\n" (- (scs-result-pobj r))))

(module+ test
  (require rackunit)
  (define r (run-example))
  (check-true (solved? r))
  (define x (scs-result-x r))
  (for ([i (in-range 3)])
    (check-= (vector-ref x i) (/ 1.0 3.0) 1e-5))
  ;; max entropy of the uniform distribution on 3 atoms is log 3
  (check-= (- (scs-result-pobj r)) (log 3) 1e-5))
