#lang racket/base

;; Tests for the high-level `(require scs)` API: the canonical QP solved through
;; `solve`, on both the direct and indirect solvers.

(module+ test
  (require rackunit
           "../main.rkt")

  (define (sum-sq-diff x y)
    (for/sum ([xi (in-vector x)]
              [yi (in-vector y)])
      (define d (- xi yi))
      (* d d)))

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

  (define (solve-qp #:indirect? [indirect? #f])
    (solve #:A A
           #:b #(-1.0 0.3 -0.5)
           #:c #(-1.0 -1.0)
           #:P P
           #:cone (make-cone #:zero 1 #:positive 2)
           #:settings (make-settings #:eps-abs 1e-9 #:eps-rel 1e-9)
           #:indirect? indirect?))

  (let ([r (solve-qp)])
    (check-true (solved? r))
    (check-equal? (scs-result-status r) "solved")
    (check-true (< (sum-sq-diff (scs-result-x r) #(0.3 -0.7)) 1e-9))
    (check-equal? (vector-length (scs-result-y r)) 3)
    (check-equal? (vector-length (scs-result-s r)) 3))

  (let ([r (solve-qp #:indirect? #t)])
    (check-true (solved? r))
    (check-true (< (sum-sq-diff (scs-result-x r) #(0.3 -0.7)) 1e-9)))

  (check-pred string? (scs-version)))
