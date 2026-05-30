#lang racket/base

;; 00 - Quadratic program.
;;
;;   minimize    (1/2) x'P x + c'x
;;   subject to  -x0 + x1 = -1          (equality / zero cone)
;;               x0 <= 0.3, x1 <= -0.5  (positive orthant)
;;
;; with P = [[3 -1] [-1 2]], c = (-1 -1).  Optimal x = (0.3, -0.7).

(require scs)

(provide run-example)

(define (run-example)
  (define A
    (scs:matrix 3 2
                ;; ---
                -1 1
                1 0
                0 1))
  (define P
    (scs:sparse-matrix 2 2
                       '(0 0 3)
                       '(0 1 -1)
                       '(1 1 2)))
  (solve #:A A
         #:b #(-1.0 0.3 -0.5)
         #:c #(-1.0 -1.0)
         #:P P
         #:cone (make-cone #:zero 1 #:positive 2)
         #:settings (make-settings #:eps-abs 1e-9 #:eps-rel 1e-9)))

(module+ main
  (define r (run-example))
  (printf "status: ~a\n" (scs-result-status r))
  (printf "x:      ~a\n" (scs-result-x r))
  (printf "pobj:   ~a\n" (scs-result-pobj r)))

(module+ test
  (require rackunit)
  (define r (run-example))
  (check-true (solved? r))
  (check-= (vector-ref (scs-result-x r) 0) 0.3 1e-6)
  (check-= (vector-ref (scs-result-x r) 1) -0.7 1e-6))
