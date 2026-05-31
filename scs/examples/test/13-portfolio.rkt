#lang racket/base

;; Runner + tests for ../13-portfolio.rkt (literate lp2 example).

(require "../13-portfolio.rkt")

(module+ main
  (printf "w = ~a\n" (run-example)))

(module+ test
  (require rackunit)
  (define w (run-example))
  ;; Return floor binds; budget + return pin w = (0.5, 0.5).
  (check-= (vector-ref w 0) 0.5 1e-4)
  (check-= (vector-ref w 1) 0.5 1e-4))
