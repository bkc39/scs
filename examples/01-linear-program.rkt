#lang racket/base

;; 01 - Linear program (positive orthant only).
;;
;;   maximize  x0 + x1   (i.e. minimize -x0 - x1)
;;   subject to  x0 <= 1, x1 <= 1, x0 >= 0, x1 >= 0
;;
;; The lower bounds are written as -x0 <= 0, -x1 <= 0.  Optimal x = (1, 1).

(require scs)

(provide run-example)

(define (run-example)
  (define A
    (scs:matrix 4 2
                ;; ---
                1 0
                0 1
                -1 0
                0 -1))
  (solve #:A A
         #:b #(1.0 1.0 0.0 0.0)
         #:c #(-1.0 -1.0)
         #:cone (make-cone #:positive 4)
         #:settings (make-settings #:eps-abs 1e-9 #:eps-rel 1e-9)))

(module+ main
  (define r (run-example))
  (printf "status: ~a\n" (scs-result-status r))
  (printf "x:      ~a\n" (scs-result-x r)))

(module+ test
  (require rackunit)
  (define r (run-example))
  (check-true (solved? r))
  (check-= (vector-ref (scs-result-x r) 0) 1.0 1e-6)
  (check-= (vector-ref (scs-result-x r) 1) 1.0 1e-6))
