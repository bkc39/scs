#lang racket/base

;; raco review does surface-level linting without macro expansion; it would
;; report every `all-from-out` re-export below as "provided but not defined".
;; This is a pure re-export facade with nothing else to lint.
#|review: ignore|#

;; Facade for the raw C FFI layer.  `(require scs/foreign/raw)` re-exports the
;; direct `define-ffi-definer` bindings, the cstructs, and the type aliases;
;; all implementation lives in raw/{library,kw-struct,structs,solver}.rkt.

(require "raw/library.rkt"
         "raw/kw-struct.rkt"
         "raw/structs.rkt"
         "raw/solver.rkt")

(provide (all-from-out "raw/library.rkt")
         (all-from-out "raw/kw-struct.rkt")
         (all-from-out "raw/structs.rkt")
         (all-from-out "raw/solver.rkt"))
