#lang racket/base

;; Runner + tests for the literate example ../01-linear-program.rkt.
;; The example itself is a #lang scribble/lp2 program (woven into the manual);
;; lp2 submodules can't see chunk-level bindings, so main/test live here and
;; require the example's provides.

(require scs
         "../01-linear-program.rkt")

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
