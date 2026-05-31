#lang racket/base

;; Runner + tests for ../08-warm-start-update.rkt (literate lp2 example).

(require "../08-warm-start-update.rkt")

(module+ main
  (for ([step (in-list (run-example))]
        [label (in-list '("initial" "after update"))])
    (printf "~a: flag=~a x=~a\n" label (car step) (cadr step))))

(module+ test
  (require rackunit)
  (define steps (run-example))
  (define first-step (car steps))
  (define second-step (cadr steps))
  (check-equal? (car first-step) 1)
  (check-= (vector-ref (cadr first-step) 0) 1.0 1e-6)
  (check-= (vector-ref (cadr first-step) 1) 1.0 1e-6)
  (check-equal? (car second-step) 1)
  (check-= (vector-ref (cadr second-step) 0) 2.0 1e-6)
  (check-= (vector-ref (cadr second-step) 1) 3.0 1e-6))
