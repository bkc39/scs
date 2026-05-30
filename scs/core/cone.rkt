#lang racket/base

;; Ergonomic constructor for SCS cone specifications.  `make-cone` takes Racket
;; lists/values and assembles the ScsCone struct (allocating the pointer arrays
;; SCS expects).  Rows of A must be ordered to match the cone layout SCS
;; documents: zero, then positive orthant, then box, SOC, PSD, complex PSD,
;; exponential, power.

(require ffi/unsafe
         "../foreign/raw/library.rkt"
         "../foreign/raw/retain.rkt"
         "../foreign/raw/structs.rkt")

(provide make-cone)

(define (int-list->ptr xs)
  (cond
    [(null? xs) #f]
    [else
     (define ptr (malloc 'atomic-interior _scs-int (length xs)))
     (for ([v (in-list xs)]
           [i (in-naturals)])
       (ptr-set! ptr _scs-int i v))
     ptr]))

(define (float-list->ptr xs)
  (cond
    [(null? xs) #f]
    [else
     (define ptr (malloc 'atomic-interior _scs-float (length xs)))
     (for ([v (in-list xs)]
           [i (in-naturals)])
       (ptr-set! ptr _scs-float i (exact->inexact v)))
     ptr]))

;; Build an ScsCone.
;;   #:zero          number of primal-zero / dual-free rows
;;   #:positive      number of positive-orthant rows
;;   #:box-lower     list of box lower bounds (length = bsize-1), or '()
;;   #:box-upper     list of box upper bounds (length = bsize-1), or '()
;;   #:soc           list of second-order-cone block sizes
;;   #:psd           list of semidefinite-cone block sizes
;;   #:complex-psd   list of complex-semidefinite-cone block sizes
;;   #:exp-primal    number of primal exponential cone triples
;;   #:exp-dual      number of dual exponential cone triples
;;   #:power         list of power-cone parameters in [-1, 1]
(define (make-cone #:zero [z 0]
                   #:positive [l 0]
                   #:box-lower [box-lower '()]
                   #:box-upper [box-upper '()]
                   #:soc [soc '()]
                   #:psd [psd '()]
                   #:complex-psd [complex-psd '()]
                   #:exp-primal [exp-primal 0]
                   #:exp-dual [exp-dual 0]
                   #:power [power '()])
  (define box-len (length box-lower))
  (unless (= box-len (length box-upper))
    (error 'make-cone "box-lower and box-upper must have equal length"))
  (define bu (float-list->ptr box-upper))
  (define bl (float-list->ptr box-lower))
  (define q (int-list->ptr soc))
  (define s (int-list->ptr psd))
  (define cs (int-list->ptr complex-psd))
  (define p (float-list->ptr power))
  ;; retain the pointer arrays so they outlive the cone struct
  (retain!
   (make-scs-cone z l bu bl (if (> box-len 0) (+ box-len 1) 0)
                  q (length soc)
                  s (length psd)
                  cs (length complex-psd)
                  exp-primal exp-dual
                  p (length power))
   bu bl q s cs p))
