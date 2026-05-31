#lang racket/base

;; Runner + tests for ../10-elastic-net.rkt (literate lp2 example).

(require "../10-elastic-net.rkt")

(module+ main
  (for ([w (in-list (run-example))]
        [label (in-list '("ridge (alpha=1)" "elastic (alpha=0.5)"))])
    (printf "~a: w=~a\n" label w)))

(module+ test
  (require rackunit)
  (define results (run-example))
  ;; Ridge (alpha=1): closed form w = (XᵀX + lam I)^-1 Xᵀy with lam=0.1,
  ;; XᵀX = [[2 1] [1 2]], Xᵀy = (1.5 2.5)  =>  w = (0.19062, 1.09971).
  (define ridge (car results))
  (check-= (vector-ref ridge 0) 0.190616 1e-4)
  (check-= (vector-ref ridge 1) 1.099707 1e-4)
  ;; Elastic (alpha=0.5): solved, weights stay in a sensible range and the
  ;; L1 term shrinks w0 relative to ridge.
  (define elastic (cadr results))
  (check-true (< 0.0 (vector-ref elastic 0) (vector-ref ridge 0)))
  (check-true (< 0.8 (vector-ref elastic 1) 1.2)))
