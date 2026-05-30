#lang racket/base

;; 07 - Lasso (L1-regularized least squares), with warm starting across the
;; regularization path -- mirrors the SCS "lasso" example
;; (https://www.cvxgrp.org/scs/examples/python/lasso.html).
;;
;;   minimize  (1/2) ||A x - b||_2^2 + lambda ||x||_1
;;
;; With the substitution |x_i| <= t_i (two linear inequalities per coordinate)
;; this is the quadratic cone program over w = (x, t):
;;
;;   minimize  (1/2) wᵀ P w + c(lambda)ᵀ w
;;   subject to  x_i - t_i <= 0,  -x_i - t_i <= 0      (positive orthant)
;;
;; where P has the AᵀA block on x (upper triangle), and c = (-Aᵀb, lambda·1).
;; Only c changes with lambda, so we reuse one workspace and scs-update it as we
;; sweep lambda -- exactly the warm-start pattern the SCS example highlights.
;;
;; Data: A = [[1 0] [0 1] [1 1]], b = (1, 2, 0.5)  =>  AᵀA = [[2 1] [1 2]],
;; Aᵀb = (1.5, 2.5).  Variables w = (x0, x1, t0, t1).

(require ffi/unsafe
         scs
         scs/foreign)

(provide run-example)

(define info-str-type (_array _byte 128))

(define (make-info)
  (new-scs-info
   #:status (ptr-ref (malloc 'atomic-interior info-str-type) info-str-type 0)
   #:lin_sys_solver (ptr-ref (malloc 'atomic-interior info-str-type) info-str-type 0)))

;; AᵀA in the x-block (upper triangle), zeros on the t-block.
(define P (scs:sparse-matrix 4 4 '(0 0 2) '(0 1 1) '(1 1 2)))

;; |x_i| <= t_i, written as x_i - t_i <= 0 and -x_i - t_i <= 0.
(define G
  (scs:matrix 4 4
              ;; x0 x1 t0 t1
              1 0 -1 0
              -1 0 -1 0
              0 1 0 -1
              0 -1 0 -1))

(define h (scs:vector->float-ptr #(0.0 0.0 0.0 0.0)))

;; c(lambda) = (-Aᵀb, lambda, lambda)
(define (cost lambda)
  (scs:vector->float-ptr (vector -1.5 -2.5 lambda lambda)))

(define (run-example [lambdas '(0.1 0.3)])
  (define c0 (cost (car lambdas)))
  (define data (retain! (make-scs-data 4 4 G P h c0) G P h c0))
  (define cone (make-cone #:positive 4))
  (define stgs (make-settings #:eps-abs 1e-9 #:eps-rel 1e-9))
  (define work (scs-init data cone stgs))
  (define sx (malloc 'atomic-interior _scs-float 4))
  (define sy (malloc 'atomic-interior _scs-float 4))
  (define ss (malloc 'atomic-interior _scs-float 4))
  (define sol (retain! (make-scs-solution sx sy ss) sx sy ss))
  (define info (make-info))
  (for/list ([lambda (in-list lambdas)]
             [step (in-naturals)])
    ;; first solve uses c0; later lambdas update c and warm start
    (define warm
      (cond
        [(zero? step) (scs-solve work sol info 0)]
        [else
         (define c (cost lambda))
         (scs-update work h c)
         (scs-solve work sol info 1)]))
    (define x (scs:float-ptr->vector (scs-solution-x sol) 2))
    (list lambda warm x)))

(module+ main
  (for ([row (in-list (run-example))])
    (printf "lambda=~a flag=~a x=~a\n" (car row) (cadr row) (caddr row))))

(module+ test
  (require rackunit)
  (define rows (run-example))
  ;; lambda = 0.1  ->  x ~ (0.1333, 1.1333)
  (define r1 (car rows))
  (check-equal? (cadr r1) 1)
  (check-= (vector-ref (caddr r1) 0) 0.133333 1e-5)
  (check-= (vector-ref (caddr r1) 1) 1.133333 1e-5)
  ;; lambda = 0.3 shrinks x toward 0  ->  x ~ (0.0667, 1.0667)
  (define r2 (cadr rows))
  (check-equal? (cadr r2) 1)
  (check-= (vector-ref (caddr r2) 0) 0.066667 1e-5)
  (check-= (vector-ref (caddr r2) 1) 1.066667 1e-5))
