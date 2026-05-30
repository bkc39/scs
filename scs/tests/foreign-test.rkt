#lang racket/base

;; Integration tests for the raw/safe FFI layer: CSC matrix assembly plus a full
;; scs-init / scs-solve round-trip on the canonical QP, against both the direct
;; and indirect solvers.

(module+ test
  (require ffi/unsafe
           rackunit
           (prefix-in scs: "../core/matrix.rkt")
           "../foreign/raw.rkt")

  (define info-str-type (_array _byte 128))

  (define (make-info)
    (new-scs-info
     #:status (ptr-ref (malloc 'atomic-interior info-str-type) info-str-type 0)
     #:lin_sys_solver (ptr-ref (malloc 'atomic-interior info-str-type) info-str-type 0)))

  (define (sum-sq-diff x y)
    (for/sum ([xi (in-vector x)]
              [yi (in-vector y)])
      (define d (- xi yi))
      (* d d)))

  (define-check (check-near/vector x y tol)
    (unless (and (= (vector-length x) (vector-length y))
                 (< (sum-sq-diff x y) tol))
      (fail-check)))

  ;; 2 variables, 3 constraints.
  (define A
    (scs:matrix 3 2
                ;; ---
                -1 1
                1 0
                0 1))

  (check-equal? (scs-matrix-m A) 3)
  (check-equal? (scs-matrix-n A) 2)
  (check-equal? (scs:matrix-p->vector A) #(0 2 4))
  (check-equal? (scs:matrix-x->vector A) #(-1.0 1.0 1.0 1.0))
  (check-equal? (scs:matrix-i->vector A) #(0 1 0 2))
  (check-equal? (scs:matrix-ref A 1 0) 1.0)
  (check-equal? (scs:matrix-ref A 1 1) 0.0)
  (check-equal? (scs:matrix-ref A 2 0) 0.0)

  ;; Quadratic objective term -- upper triangle only.
  (define P
    (scs:sparse-matrix 2 2
                       '(0 0 3)
                       '(0 1 -1)
                       '(1 1 2)))

  (check-equal? (scs:matrix-ref P 0 0) 3.0)
  (check-equal? (scs:matrix-ref P 1 0) 0.0)

  (define (run-solve init solve)
    (define b-ptr (scs:vector->float-ptr #(-1.0 0.3 -0.5)))
    (define c-ptr (scs:vector->float-ptr #(-1.0 -1.0)))
    (define data (retain! (make-scs-data 3 2 A P b-ptr c-ptr) A P b-ptr c-ptr))
    (define cone (make-scs-cone 1 2 #f #f 0 #f 0 #f 0 #f 0 0 0 #f 0))
    (define stgs (new-scs-settings))
    (scs-set-default-settings stgs)
    (set-scs-settings-verbose! stgs 0)
    (set-scs-settings-eps_abs! stgs 1e-9)
    (set-scs-settings-eps_rel! stgs 1e-9)
    (define work (init data cone stgs))
    (define sx (malloc 'atomic-interior _scs-float 2))
    (define sy (malloc 'atomic-interior _scs-float 3))
    (define ss (malloc 'atomic-interior _scs-float 3))
    (define sol (retain! (make-scs-solution sx sy ss) sx sy ss))
    (define info (make-info))
    (define flag (solve work sol info 0))
    (check-equal? flag 1)
    (check-near/vector (scs:float-ptr->vector (scs-solution-x sol) 2)
                       #(0.3 -0.7)
                       1e-9))

  (run-solve scs-init scs-solve)
  (run-solve scs-init/indirect scs-solve/indirect)

  (check-pred string? (scs-version)))
