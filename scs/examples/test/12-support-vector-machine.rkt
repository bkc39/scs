#lang racket/base

;; Runner + tests for ../12-support-vector-machine.rkt (literate lp2 example).

(require "../12-support-vector-machine.rkt")

(module+ main
  (define r (run-example))
  (printf "w = ~a\n" (car r))
  (printf "b = ~a\n" (cadr r)))

(module+ test
  (require rackunit)
  (define r (run-example))
  (define w (car r))
  (define b (cadr r))
  ;; Max-margin solution for the symmetric separable set: w = (0.5, 0), b = 0.
  (check-= (vector-ref w 0) 0.5 1e-3)
  (check-= (vector-ref w 1) 0.0 1e-3)
  (check-= b 0.0 1e-3))
