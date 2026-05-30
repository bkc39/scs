#lang racket/base

;; 08 - Maximum entropy over the probability simplex, via the exponential cone --
;; mirrors the SCS "entropy" example
;; (https://www.cvxgrp.org/scs/examples/python/entropy.html).
;;
;;   maximize  -sum_i x_i log x_i   subject to  1ᵀx = 1,  x >= 0
;;
;; equivalently  minimize sum_i t_i  with  t_i >= x_i log x_i.  The epigraph
;; t_i >= x_i log x_i is the exponential-cone membership
;;
;;   (-t_i, x_i, 1) in K_exp   <=>   x_i e^{-t_i / x_i} <= 1.
;;
;; Over the simplex with no other constraints the maximizer is the uniform
;; distribution x = (1/3, 1/3, 1/3).  Variables w = (x0, x1, x2, t0, t1, t2).

(require scs)

(provide run-example)

(define (run-example)
  ;; row 0: 1ᵀx = 1 (zero cone); then three exp-cone triples (3 rows each),
  ;; each encoding (-t_i, x_i, 1).
  (define A
    (scs:matrix 10 6
                ;; x0 x1 x2 t0 t1 t2
                1 1 1 0 0 0      ; sum x = 1
                0 0 0 1 0 0      ; s = -t0
                -1 0 0 0 0 0     ; s = x0
                0 0 0 0 0 0      ; s = 1
                0 0 0 0 1 0      ; s = -t1
                0 -1 0 0 0 0     ; s = x1
                0 0 0 0 0 0      ; s = 1
                0 0 0 0 0 1      ; s = -t2
                0 0 -1 0 0 0     ; s = x2
                0 0 0 0 0 0))    ; s = 1
  (solve #:A A
         #:b #(1.0 0.0 0.0 1.0 0.0 0.0 1.0 0.0 0.0 1.0)
         #:c #(0.0 0.0 0.0 1.0 1.0 1.0)
         #:cone (make-cone #:zero 1 #:exp-primal 3)
         #:settings (make-settings #:eps-abs 1e-9 #:eps-rel 1e-9)))

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
