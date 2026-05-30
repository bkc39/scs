#lang racket/base

;; Construction and inspection of SCS sparse matrices (CSC) and dense float
;; vectors.  Defined with plain names; main.rkt re-exports them under the `scs:`
;; prefix via prefix-in.
;;
;; raco review does not expand define-cstruct, so it cannot see that the
;; scs-matrix-* accessors and _scs-int/_scs-float aliases come from the requires
;; below and misreports them as unused; this module is review-ignored.
#|review: ignore|#

(require ffi/unsafe
         racket/list
         racket/match
         "../foreign/raw/library.rkt"
         "../foreign/raw/retain.rkt"
         "../foreign/raw/structs.rkt")

(provide matrix
         sparse-matrix
         matrix-alloc
         matrix-ref
         matrix-nnz
         matrix-p->vector
         matrix-x->vector
         matrix-i->vector
         vector->float-ptr
         float-ptr->vector)

;; Allocate an m x n CSC matrix with room for nnz non-zeros.  The matrix struct
;; retains its x/i/p buffers so they outlive it.
(define (matrix-alloc nrow ncol nnz)
  (define x (malloc 'atomic-interior _scs-float nnz))
  (define i (malloc 'atomic-interior _scs-int nnz))
  (define p (malloc 'atomic-interior _scs-int (+ ncol 1)))
  (retain! (make-scs-matrix x i p nrow ncol) x i p))

;; Convert a dense row-major list of values into (row col value) triples,
;; dropping exact zeros.
(define (list->sparse-triple-list ncol xs)
  (for/list ([k (in-naturals)]
             [x (in-list xs)]
             #:unless (zero? x))
    (define-values (i j)
      (quotient/remainder k ncol))
    (list i j x)))

;; Column-major ordering of (row col value) triples for CSC assembly.
(define (triple<? a b)
  (match* (a b)
    [((list i j _) (list u v _))
     (or (< j v)
         (< i u))]
    [(_ _)
     (error "not a triple")]))

;; Build an n x m matrix from a dense row-major sequence of values.
(define (matrix n m . xs)
  (apply sparse-matrix
         (append (list n m)
                 (list->sparse-triple-list m xs))))

;; Build an n x m matrix from explicit (row col value) triples.
(define (sparse-matrix n m . value-triples)
  (define nnz
    (length value-triples))
  (define mat
    (matrix-alloc n m nnz))

  (for/fold ([_current-col 0])
            ([k (in-naturals)]
             [vt (in-list (sort value-triples triple<?))])
    (match-define (list row col val) vt)
    (ptr-set! (scs-matrix-x mat) _scs-float k (exact->inexact val))
    (ptr-set! (scs-matrix-i mat) _scs-int k row)
    (when (> col _current-col)
      (ptr-set! (scs-matrix-p mat) _scs-int col k))
    col)
  (ptr-set! (scs-matrix-p mat) _scs-int 0 0)
  (ptr-set! (scs-matrix-p mat) _scs-int m nnz)

  mat)

(define (matrix-p->vector mat)
  (define plen (+ 1 (scs-matrix-n mat)))
  (for/vector #:length plen ([idx (in-range plen)])
    (ptr-ref (scs-matrix-p mat) _scs-int idx)))

(define (matrix-nnz mat)
  (ptr-ref (scs-matrix-p mat) _scs-int (scs-matrix-n mat)))

(define (matrix-nnz-buffer->vector mat field-id type)
  (define nnz (matrix-nnz mat))
  (for/vector #:length nnz ([idx (in-range nnz)])
    (ptr-ref (field-id mat) type idx)))

(define (matrix-x->vector mat)
  (matrix-nnz-buffer->vector mat scs-matrix-x _scs-float))

(define (matrix-i->vector mat)
  (matrix-nnz-buffer->vector mat scs-matrix-i _scs-int))

;; Random-access element lookup; returns 0.0 for entries absent from the CSC
;; representation.
(define (matrix-ref mat i j)
  (unless (and (< i (scs-matrix-m mat))
               (< j (scs-matrix-n mat)))
    (error "matrix-ref: index out of bounds"))
  (or
   (for/first ([idx (in-range (ptr-ref (scs-matrix-p mat) _scs-int j)
                              (ptr-ref (scs-matrix-p mat) _scs-int (+ j 1)))]
               #:when (= i (ptr-ref (scs-matrix-i mat) _scs-int idx)))
     (ptr-ref (scs-matrix-x mat) _scs-float idx))
   0.0))

;; Copy a Racket sequence of reals into a freshly malloc'd scs_float array.
(define (vector->float-ptr v)
  (define vec (if (list? v) (list->vector v) v))
  (define ptr (malloc 'atomic-interior _scs-float (vector-length vec)))
  (for ([val (in-vector vec)]
        [idx (in-naturals)])
    (ptr-set! ptr _scs-float idx (exact->inexact val)))
  ptr)

;; Read `len` scs_float values out of a pointer into a Racket vector.
(define (float-ptr->vector ptr len)
  (for/vector #:length len ([idx (in-range len)])
    (ptr-ref ptr _scs-float idx)))
