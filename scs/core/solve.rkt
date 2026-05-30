#lang racket/base

;; High-level solve entry point.  Accepts ordinary Racket data (the CSC matrix
;; builders from core/matrix, vectors/lists for b and c, a cone from core/cone)
;; and returns an `scs-result` struct of Racket values.  The solver workspace is
;; GC-reclaimed, so callers never free anything.

(require ffi/unsafe
         "../foreign/raw/library.rkt"
         "../foreign/raw/structs.rkt"
         "../foreign/raw/solver.rkt"
         "matrix.rkt"
         "settings.rkt")

(provide (struct-out scs-result)
         solve
         solved?)

(struct scs-result
  (exit-flag status status-val x y s pobj dobj gap iter solve-time setup-time)
  #:transparent)

;; SCS returns 1 (SCS_SOLVED) on success.
(define (solved? r)
  (= (scs-result-exit-flag r) 1))

(define info-str-type (_array _byte 128))

;; Read a NUL-terminated C char[128] field into a Racket string.
(define (status-array->string arr)
  (define bs
    (let loop ([i 0] [acc '()])
      (cond
        [(>= i 128) (reverse acc)]
        [else
         (define b (array-ref arr i))
         (if (zero? b) (reverse acc) (loop (add1 i) (cons b acc)))])))
  (bytes->string/utf-8 (list->bytes bs)))

;; ScsInfo's status / lin_sys_solver are char[128]; new-scs-info cannot default
;; an array field, so seed them with zeroed buffers SCS will overwrite.
(define (make-info)
  (define status-ptr (malloc 'atomic info-str-type))
  (define lin-ptr (malloc 'atomic info-str-type))
  (new-scs-info #:status (ptr-ref status-ptr info-str-type 0)
                #:lin_sys_solver (ptr-ref lin-ptr info-str-type 0)))

;; x has length n (variables); y and s have length m (constraints).
(define (make-solution m n)
  (make-scs-solution
   (malloc 'atomic _scs-float n)
   (malloc 'atomic _scs-float m)
   (malloc 'atomic _scs-float m)))

;; Solve  minimize (1/2) x'Px + c'x  s.t.  Ax + s = b, s in cone.
;;   #:A         constraint matrix (scs-matrix, m x n, CSC)
;;   #:b         right-hand side (length-m vector/list)
;;   #:c         linear objective (length-n vector/list)
;;   #:cone      cone specification (from make-cone)
;;   #:P         optional quadratic objective (n x n, upper-triangular CSC) or #f
;;   #:settings  optional ScsSettings (from make-settings); #f uses defaults
;;   #:indirect? use the indirect (CG) linear-system solver
;;   #:warm-start pass 1 to warm-start from the solution arrays
(define (solve #:A A
               #:b b
               #:c c
               #:cone cone
               #:P [P #f]
               #:settings [settings #f]
               #:indirect? [indirect? #f]
               #:warm-start [warm 0])
  (define m (scs-matrix-m A))   ; rows of A: number of constraints
  (define n (scs-matrix-n A))   ; cols of A: number of variables
  (define data
    (make-scs-data m n A P
                   (vector->scs-float-ptr b)
                   (vector->scs-float-ptr c)))
  (define stgs (or settings (make-settings)))
  (define init (if indirect? scs-init/indirect scs-init))
  (define run (if indirect? scs-solve/indirect scs-solve))
  (define work (init data cone stgs))
  (define sol (make-solution m n))
  (define info (make-info))
  (define flag (run work sol info warm))
  (scs-result
   flag
   (status-array->string (scs-info-status info))
   (scs-info-status_val info)
   (scs-float-ptr->vector (scs-solution-x sol) n)
   (scs-float-ptr->vector (scs-solution-y sol) m)
   (scs-float-ptr->vector (scs-solution-s sol) m)
   (scs-info-pobj info)
   (scs-info-dobj info)
   (scs-info-gap info)
   (scs-info-iter info)
   (scs-info-solve_time info)
   (scs-info-setup_time info)))
