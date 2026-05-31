#lang racket/base

;; Runner + tests for ../09-lasso.rkt (literate lp2 example).

(require "../09-lasso.rkt")

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
