#lang racket/base

;; 09 - Model predictive control with the box cone and receding-horizon warm
;; starting -- mirrors the SCS "mpc" example
;; (https://www.cvxgrp.org/scs/examples/python/mpc.html).
;;
;; Scalar system x_{t+1} = x_t + u_t over horizon T = 3, with x_0 given:
;;
;;   minimize  sum_{t=1}^{3} x_t^2 + 0.1 sum_{t=0}^{2} u_t^2
;;   subject to  x_{t+1} = x_t + u_t        (dynamics, zero cone)
;;               -1 <= u_t <= 1             (input bounds, box cone)
;;
;; The input bounds use SCS's box cone {(s0, r) : s0·bl <= r <= s0·bu}: the
;; first box row is the scale s0, which we pin to 1 with a constant row
;; (zero coefficients, right-hand side 1); the remaining rows carry u0..u2.
;;
;; Closed-loop MPC re-solves as the state evolves; only b changes, so we reuse
;; one workspace and scs-update it -- here we re-solve for x_0 = 2 then x_0 = 1.5.
;; Variables w = (u0, u1, u2, x1, x2, x3).

(require ffi/unsafe
         scs
         scs/foreign)

(provide run-example)

(define info-str-type (_array _byte 128))

(define (make-info)
  (new-scs-info
   #:status (ptr-ref (malloc 'atomic-interior info-str-type) info-str-type 0)
   #:lin_sys_solver (ptr-ref (malloc 'atomic-interior info-str-type) info-str-type 0)))

;; 0.1·u_t^2 -> P entry 0.2; x_t^2 -> P entry 2 (since objective is (1/2)wᵀPw).
(define P
  (scs:sparse-matrix 6 6
                     '(0 0 0.2) '(1 1 0.2) '(2 2 0.2)
                     '(3 3 2) '(4 4 2) '(5 5 2)))

(define G
  (scs:matrix 7 6
              ;; u0 u1 u2 x1 x2 x3
              -1 0 0 1 0 0     ; x1 - u0 = x0      (dynamics)
              0 -1 0 -1 1 0    ; x2 - x1 - u1 = 0
              0 0 -1 0 -1 1    ; x3 - x2 - u2 = 0
              0 0 0 0 0 0      ; box scale row -> s0 = 1
              -1 0 0 0 0 0     ; s = u0
              0 -1 0 0 0 0     ; s = u1
              0 0 -1 0 0 0))   ; s = u2

(define c (scs:vector->float-ptr #(0.0 0.0 0.0 0.0 0.0 0.0)))

;; right-hand side for a given initial state x0 (only the first entry changes)
(define (rhs x0)
  (scs:vector->float-ptr (vector x0 0.0 0.0 1.0 0.0 0.0 0.0)))

(define (run-example [x0s '(2.0 1.5)])
  (define b0 (rhs (car x0s)))
  (define data (retain! (make-scs-data 7 6 G P b0 c) G P b0 c))
  (define cone
    (make-cone #:zero 3 #:box-lower '(-1.0 -1.0 -1.0) #:box-upper '(1.0 1.0 1.0)))
  (define stgs (make-settings #:eps-abs 1e-9 #:eps-rel 1e-9))
  (define work (scs-init data cone stgs))
  (define sx (malloc 'atomic-interior _scs-float 6))
  (define sy (malloc 'atomic-interior _scs-float 7))
  (define ss (malloc 'atomic-interior _scs-float 7))
  (define sol (retain! (make-scs-solution sx sy ss) sx sy ss))
  (define info (make-info))
  (for/list ([x0 (in-list x0s)]
             [step (in-naturals)])
    (define flag
      (cond
        [(zero? step) (scs-solve work sol info 0)]
        [else
         (scs-update work (rhs x0) c)
         (scs-solve work sol info 1)]))
    ;; w = (u0 u1 u2 x1 x2 x3); report the first control input u0
    (define w (scs:float-ptr->vector (scs-solution-x sol) 6))
    (list x0 flag (vector-ref w 0))))

(module+ main
  (for ([row (in-list (run-example))])
    (printf "x0=~a flag=~a u0=~a\n" (car row) (cadr row) (caddr row))))

(module+ test
  (require rackunit)
  (define rows (run-example))
  ;; both solves saturate the first input at the lower bound
  (define r1 (car rows))
  (check-equal? (cadr r1) 1)
  (check-= (caddr r1) -1.0 1e-5)
  (define r2 (cadr rows))
  (check-equal? (cadr r2) 1)
  (check-= (caddr r2) -1.0 1e-5))
