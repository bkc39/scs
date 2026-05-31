#lang racket/base

;; Runner + tests for ../14-mpc.rkt (literate lp2 example).

(require "../14-mpc.rkt")

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
