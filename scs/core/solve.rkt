#lang racket/base

;; High-level one-shot `solve`, documented in the scs Scribble reference.  It is
;; a thin wrapper over the solver object in solver.rkt: build a solver, solve
;; once, return the scs-result.  The solver workspace is GC-reclaimed.

(require "solver.rkt")

(provide solve)

;; Solve minimize (1/2) x'Px + c'x s.t. Ax + s = b, s in cone.  See the scs
;; Scribble reference for the keyword arguments and result fields.
(define (solve #:A A
               #:b b
               #:c c
               #:cone cone
               #:P [P #f]
               #:settings [settings #f]
               #:indirect? [indirect? #f]
               #:warm-start [warm 0])
  (solver-solve!
   (make-solver #:A A #:b b #:c c #:cone cone
                #:P P #:settings settings #:indirect? indirect?)
   #:warm-start warm))
