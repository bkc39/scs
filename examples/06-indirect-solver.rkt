#lang racket/base

;; 06 - Indirect (conjugate-gradient) linear-system solver.
;;
;; The same QP as example 00, but solved with #:indirect? #t, which binds the
;; libscsindir build instead of libscsdir.  The indirect solver scales better to
;; very large sparse problems.  Optimal x = (0.3, -0.7).

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
         #:settings (make-settings #:eps-abs 1e-9 #:eps-rel 1e-9)
         #:indirect? #t))

(module+ main
  (define r (run-example))
  (printf "status: ~a\n" (scs-result-status r))
  (printf "x:      ~a\n" (scs-result-x r)))

(module+ test
  (require rackunit)
  (define r (run-example))
  (check-true (solved? r))
  (check-= (vector-ref (scs-result-x r) 0) 0.3 1e-6)
  (check-= (vector-ref (scs-result-x r) 1) -0.7 1e-6))
